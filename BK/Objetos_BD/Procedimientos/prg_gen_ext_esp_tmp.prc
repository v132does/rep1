CREATE OR REPLACE PROCEDURE IT.PRG_GEN_EXT_ESP_TMP (p_cod_persona varchar2,
                                                  p_nro_cuenta in varchar2 default null,
                                                  p_fec_hasta in date default null,
                                                  p_sal_anterior in number )
                          is

   -- Definicion de Variables Globales
   v_lugar             varchar2(100) := 'Iniciando';
   v_cod_persona       ba_personas.cod_persona%type;
   v_nro_cuenta        ge_cta_clientes.nro_cuenta%type;
   v_nro_cta_parametro varchar2(300);
   v_cod_extracto      ge_ext_clientes.cod_extracto%type;
   v_cod_modalidad     ge_modalidades.cod_modalidad%type;
   v_fre_extracto      varchar2(1) := 'D'; -- A todos se le pone frecuencia diaria...
   ---
   v_fec_actual        ge_calendarios.fec_actual%type;
   v_pri_dia_mes_habil ge_calendarios.pri_dia_mes_habil%type;
   v_inserta           varchar2(1);

   --- Variables de Datos de Direccion
   v_dir_cliente       ge_ext_clientes.direccion%type;
   v_pri_obs_dir       ge_ext_clientes.det_direccion%type;
   v_seg_obs_dir       ge_ext_clientes.observacion%type;
   v_cod_pais          ge_ext_clientes.cod_pais%type;
   v_cod_ciudad        ge_ext_clientes.cod_ciudad%type;
   v_des_barrio        ge_ext_clientes.barrio%type;
   v_tel_cliente       ge_ext_clientes.telefono%type;
   v_tip_envio         ge_dir_envios.tip_envio%type;

   --- Variables de Datos del Oficial
   v_es_empleado       varchar2(1);
   v_cli_confidencial  varchar2(1);
   v_cat_riesgo        ge_clientes.cat_riesgo%type;
   v_fec_ult_clasif    ge_clientes.fec_ult_clasif%type;
   v_cod_ofi_cliente   number(4);
   v_cod_usu_oficial   ge_clientes.cod_usu_oficial%type;
   v_tel_oficial       ba_oficinas.telefono%type;
   v_int_oficial       ba_usuarios.nro_interno%type;
   v_tip_extracto      ge_clientes.tip_extracto%type;
   v_est_modulo        ba_modulos.estado%type := pae_cnf.FU_OBT_EST_MODULO(3);
   v_nom_cliente       ba_personas.nom_completo%type;
   v_mto_bloqueo       number;
   v_sal_blo_anterior  number;
   v_fec_recibida      date;
   --Generar movimientos retenidos por cuenta
   procedure lp_generar_mov_retenciones(p_nro_cuenta in varchar2) IS
     V_EXISTE VARCHAR2(1);
      CURSOR RETENCIONES IS
      SELECT AH_RETENCIONES.COD_RETENCION,AH_RETENCIONES.NRO_DOCUMENTO,AH_RETENCIONES.NRO_CUENTA,
             AH_RETENCIONES.COD_MODULO,AH_RETENCIONES.COD_MODALIDAD,/*AH_RETENCIONES.MONTO*/AH_RETENCIONES.SAL_RETENIDO, --Se modico el campo MONTO x SAL_RETENIDO <<EF,09/09/2009>>
             AH_RETENCIONES.FEC_FINAL,AH_RETENCIONES.FEC_INICIO,
             AH_RETENCIONES.ROWID REGISTRO
        FROM AH_RETENCIONES
       WHERE AH_RETENCIONES.NRO_CUENTA = P_nro_cuenta
         AND AH_RETENCIONES.COD_MODALIDAD IN (31,41,334)
         AND AH_RETENCIONES.LIBERADO  = 'N'
         AND AH_RETENCIONES.LIB_ANTICIPADA = 'N'; -- Que no muestre las retenciones liberadas en forma anticipada
   BEGIN
     v_lugar := 'lp_generar_mov_retenciones';
     V_EXISTE := 'N';
     --- verifico si ya existe una cabecera del extracto unico
     FOR RET IN RETENCIONES LOOP
         INSERT INTO GE_EXT_CLI_MOV_RETENIDOS_TMP(FEC_EXTRACTO,COD_RETENCION,NRO_DOCUMENTO,COD_PERSONA,
                                        MONTO,FEC_MOVIMIENTO,FEC_LIBERACION,NRO_CUENTA,COD_MODULO,
                                        COD_MODALIDAD,FRE_EXTRACTO, COD_EXTRACTO)
                     values(v_fec_actual,ret.cod_retencion,ret.nro_documento,v_cod_persona,
                            ret.sal_retenido,ret.fec_inicio,ret.fec_final,ret.nro_cuenta,ret.cod_modulo,
                            ret.cod_modalidad,v_fre_extracto, v_cod_extracto);
     END LOOP;
   end lp_generar_mov_retenciones;
   --
   function lf_obt_mto_bloqueado(p_nro_cuenta in varchar2)
     return number is
       vmto_bloqueo number default 0;
     begin
       select nvl(sum(monto),0)
         into vmto_bloqueo
         from ge_bloqueos
        where cod_causa in (select cod_causa
                              from ge_par_causales
                             where parametro = 'COD_CAU_BLO_EXT'
                               and val_parametro = 'S' )
          and nro_cuenta = p_nro_cuenta;
       return vmto_bloqueo;
     exception
       when no_data_found then
         return 0;
       when others then
         return 0;
     end;

   function lf_obt_sal_blo_anterior(p_nro_cuenta in varchar2, p_fec_extracto in date)
     return number is
       vmto_bloqueo number default 0;
     begin
       select sal_bloqueado
         into vmto_bloqueo
         from ge_ext_cli_cuentas
        where nro_cuenta = p_nro_cuenta
          and fec_extracto = p_fec_extracto;
       return vmto_bloqueo;
     exception
       when no_data_found then
         return 0;
       when others then
         return 0;
     end;
   --Generar movimientos pendientes de pago por cuenta
   procedure lp_generar_mov_pendientes(p_nro_cuenta in varchar2) IS
     V_EXISTE VARCHAR2(1);
      CURSOR pendientes IS
      select m.nro_cuenta, m.fecha, m.cod_modulo, m.cod_modalidad, m.cod_transaccion, m.cod_mod_padre, m.cod_mad_padre, m.cod_tra_padre,
             m.monto, m.usu_insercion, m.hora, m.cod_movimiento, m.cod_usuario, m.cod_moneda, m.cod_oficina, m.cod_error, m.estado,
             m.cod_ofi_origen, m.concepto, m.cod_tasa, m.val_tasa, m.nro_documento, m.saldo, m.mto_exonerado, m.cod_usu_exonerador,
             m.motivo, m.observacion, t.descripcion, m.rowid registro
        from ge_mov_pendientes m, ge_transacciones t
       where m.cod_mod_padre = t.cod_modulo
         and m.cod_mad_padre = t.cod_modalidad
         and m.cod_tra_padre = t.cod_transaccion
         and m.nro_cuenta = p_nro_cuenta
         and m.cod_modalidad in (31,41)
         and m.estado  = 'I'
         and m.fecha <=  v_fec_actual;
   BEGIN
     v_lugar := 'lp_generar_mov_pendientes. Cta '||p_nro_cuenta;
     V_EXISTE := 'N';
     --- verifico si ya existe una cabecera del extracto unico
     FOR pen IN pendientes LOOP
         INSERT INTO ge_ext_cli_mov_pendientes(FEC_EXTRACTO,Tip_Comision,COD_PERSONA,
                                        MONTO,FEC_MOVIMIENTO,NRO_CUENTA,COD_MODULO,
                                        COD_MODALIDAD,FRE_EXTRACTO, COD_EXTRACTO,descripcion)
                     values(v_fec_actual,pen.cod_transaccion,v_cod_persona,
                            pen.monto,pen.fecha,pen.nro_cuenta,pen.cod_modulo,
                            pen.cod_modalidad,v_fre_extracto, v_cod_extracto,pen.descripcion);
     END LOOP;
   end lp_generar_mov_pendientes;
   ---
   procedure lp_borra_ext_generado is
   begin
    v_lugar := 'lp_borra_ext_generado';
    -- Borra los extractos generados x el usuario,para no dejar basura
      DELETE FROM GE_EXT_CLI_MOVIMIENTOS_TMP
       WHERE USU_INSERCION = USER;
      DELETE FROM GE_EXT_RESUMENES_TMP
       WHERE USU_INSERCION = USER;
      DELETE FROM GE_EXT_CLI_CUENTAS_TMP
       WHERE USU_INSERCION = USER;
      DELETE FROM GE_EXT_CLIENTES_TMP
       WHERE USU_INSERCION = USER;
      DELETE ge_ext_cli_mov_retenidos_tmp
       WHERE USU_INSERCION = USER;
      DELETE ge_ext_cli_mov_pendientes
       WHERE USU_INSERCION = USER;
    -- Borra los extractos generados x cliente
      DELETE FROM GE_EXT_CLI_MOVIMIENTOS_TMP
       WHERE COD_PERSONA = P_COD_PERSONA;
      DELETE FROM GE_EXT_RESUMENES_TMP
       WHERE COD_PERSONA = P_COD_PERSONA;
      DELETE FROM GE_EXT_CLI_CUENTAS_TMP
       WHERE COD_PERSONA = P_COD_PERSONA;
      DELETE FROM GE_EXT_CLIENTES_TMP
       WHERE COD_PERSONA = P_COD_PERSONA;
      DELETE ge_ext_cli_mov_retenidos_tmp
       where COD_PERSONA = P_COD_PERSONA;
      DELETE ge_ext_cli_mov_pendientes
       where COD_PERSONA = P_COD_PERSONA;
   end lp_borra_ext_generado;
   procedure lp_obtener_datos_del_cliente is
   Begin
      v_lugar := 'lp_obtener_datos_del_cliente';

      SELECT ge_clientes.cod_usu_oficial, ba_USUARIOS.TELEFONO,
             BA_USUARIOS.NRO_INTERNO, ge_clientes.tip_extracto,
             ge_clientes.cod_oficina, ge_clientes.cli_confidencial, nom_completo,
             pap_cat.fu_obt_cat_crc(v_cod_persona, v_fec_actual, 'N'), ge_clientes.fec_ult_clasif
        into v_cod_usu_oficial, v_tel_oficial, v_int_oficial, v_tip_extracto,
             v_cod_ofi_cliente, v_cli_confidencial, v_nom_cliente,
             v_cat_riesgo, v_fec_ult_clasif
        FROM BA_PERSONAS, BA_OFICINAS, BA_USUARIOS, GE_CLIENTES
       WHERE GE_CLIENTES.COD_PERSONA = V_COD_PERSONA
         AND BA_USUARIOS.COD_USUARIO = GE_CLIENTES.COD_USU_OFICIAL
         AND BA_OFICINAS.COD_OFICINA = BA_USUARIOS.COD_OFICINA
         AND GE_CLIENTES.COD_PERSONA = BA_PERSONAS.COD_PERSONA;
       v_es_empleado := FUG_ES_EMPLEADO(v_cod_persona);
    EXCEPTION
       WHEN OTHERS THEN
           v_es_empleado := 'N';
           v_tel_oficial := NULL;
           v_int_oficial := NULL;
           v_cod_usu_oficial := NULL;
           v_nom_cliente := null;
           v_tip_extracto := null;
           v_cod_ofi_cliente  := null;
           v_cli_confidencial := null;
           v_cat_riesgo := null;
           v_fec_ult_clasif := null;
   end lp_obtener_datos_del_cliente;
   procedure lp_dir_envio is
   BEGIN
       v_lugar := 'lp_dir_envio';
       ---0. limpio los valores a leer ------------------------------------
       v_dir_cliente := null;
       v_pri_obs_dir := null;
       v_seg_obs_dir := null;
       v_cod_pais    := null;
       v_cod_ciudad  := null;
       v_des_barrio  := null;
       v_tel_cliente := null;
       v_tip_envio   := null;
       ---1. Leo la vista de acuerdo a los datos que me pasa --------------
       SELECT dir_envio,     prim_observacion,   seg_observacion,
              cod_pais,      cod_ciudad,         des_barrio,
              ltrim(substr(lpad(tel_principal,20),-16)), tip_envio -- SPI 2286. CB. 18/09/2013.
         INTO v_dir_cliente, v_pri_obs_dir, v_seg_obs_dir,
              v_cod_pais,    v_cod_ciudad,  v_des_barrio,
              v_tel_cliente, v_tip_envio
         FROM gv_dir_envios gv
        WHERE gv.COD_PERSONA = v_cod_persona
          and (gv.nro_cuenta is null and not exists
                                    ( Select '1'
                                        from ge_dir_envios de
                                       where de.cod_persona = v_cod_persona
                                         and de.nro_cuenta is not null
                                         and de.nro_cuenta = v_nro_cuenta
                                     ) Or
               gv.nro_cuenta is not null and gv.nro_cuenta = v_nro_cuenta);
       ---------------------------------------------------------------------
   EXCEPTION
       WHEN NO_DATA_FOUND Then null;
       WHEN TOO_MANY_ROWS Then null;
       WHEN OTHERS THEN null;
   end lp_dir_envio;

   procedure lp_generar_ctacte is
      v_sal_ult_extracto NUMBER(16,2) default 0;
      v_mto_debito NUMBER(16,2);
      v_mto_credito NUMBER(16,2);
      v_CANTIDAD  NUMBER(06) := 0;

      v_mto_debito1 NUMBER(16,2);
      v_mto_credito1 NUMBER(16,2);
      v_CANTIDAD1  NUMBER(06) := 0;

      v_EXISTE  VARCHAR2(01) := 'N';
      v_TIENE_MOV VARCHAR2(01) := 'N';
      v_imprime_extracto varchar2(1);
      ----------------------------------
      -- CURSOR DEL ARCHIVO PRINCIPAL --
      ----------------------------------
      CURSOR MAE_CUE IS
      SELECT GE_CTA_CLIENTES.COD_MODULO, GE_CTA_CLIENTES.COD_MODALIDAD, GE_CTA_CLIENTES.COD_OFICINA, GE_CTA_CLIENTES.NRO_CUENTA,
             CC_CTA_CORRIENTES.COD_MONEDA, CC_CTA_CORRIENTES.SAL_ULT_EXTRACTO, nvl(CC_CTA_CORRIENTES.NRO_FOLIO, 0) NRO_FOLIO, CC_CTA_CORRIENTES.DENOMINACION,
             CC_CTA_CORRIENTES.SAL_RETENIDO, NVL(CC_CTA_CORRIENTES.FEC_ULT_EXTRACTO,CC_CTA_CORRIENTES.FEC_APERTURA-1) FEC_ULT_EXTRACTO,
             DECODE(GE_DIR_ENVIOS.NRO_CUENTA, NULL, 'N', 'S') SEPARADO,
             CC_CTA_CORRIENTES.ROWID REGISTRO, cc_cta_corrientes.cta_combinada,
             cc_cta_corrientes.sal_total - cc_cta_corrientes.sal_retenido saldo, cc_cta_corrientes.tas_personalizada,
             cc_cta_corrientes.sal_bloqueado, NVL(GE_PAQ_CUENTAS.COD_PAQUETE,0) COD_PAQUETE
        FROM GE_DIR_ENVIOS, CC_CTA_CORRIENTES, GE_CTA_CLIENTES, GE_PAQ_CUENTAS
       WHERE GE_DIR_ENVIOS.COD_PERSONA (+) = GE_CTA_CLIENTES.COD_PERSONA
         AND GE_DIR_ENVIOS.NRO_CUENTA (+)  = GE_CTA_CLIENTES.NRO_CUENTA
         AND GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
         and ge_cta_clientes.nro_cuenta = nvl(v_nro_cta_parametro, ge_cta_clientes.nro_cuenta) --si es x cuenta
         AND GE_CTA_CLIENTES.RELACION = 'P'
         AND CC_CTA_CORRIENTES.COD_MODULO = GE_CTA_CLIENTES.COD_MODULO
         AND CC_CTA_CORRIENTES.COD_MODALIDAD = GE_CTA_CLIENTES.COD_MODALIDAD
         AND CC_CTA_CORRIENTES.COD_OFICINA = GE_CTA_CLIENTES.COD_OFICINA
         AND CC_CTA_CORRIENTES.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
         AND ((CC_CTA_CORRIENTES.ESTADO NOT IN ('C','P')) OR
              (CC_CTA_CORRIENTES.ESTADO IN ('C','P') AND
               CC_CTA_CORRIENTES.FEC_ULT_MOVIMIENTO >=  v_pri_dia_mes_habil
               AND CC_CTA_CORRIENTES.FEC_ULT_MOVIMIENTO > NVL(CC_CTA_CORRIENTES.FEC_ULT_EXTRACTO,CC_CTA_CORRIENTES.FEC_APERTURA-1)))
         AND GE_PAQ_CUENTAS.NRO_CUENTA(+) = GE_CTA_CLIENTES.NRO_CUENTA
         AND GE_PAQ_CUENTAS.COD_PERSONA(+) = GE_CTA_CLIENTES.COD_PERSONA
       ORDER BY GE_PAQ_CUENTAS.COD_MODULO, GE_PAQ_CUENTAS.COD_MODALIDAD, GE_PAQ_CUENTAS.COD_SUB_MODALIDAD, GE_PAQ_CUENTAS.NRO_CUENTA;
        --
        v_SAL_ACUMULADO cc_sal_mensuales.sal_acu_deudor%type;
        v_SAL_PROMEDIO  cc_sal_mensuales.sal_acu_deudor%type;
        v_CAN_DIA_ACUMULADO cc_sal_mensuales.can_dia_acumulado%type;
        v_nro_cta_combinada cc_cta_combinadas.nro_cta_ahorro%type;
        v_val_tasa ge_tas_fechas.val_tasa%type;
        v_val_tae  ge_tas_fechas.val_tasa%type;
        v_mto_linea cc_lin_sobregiros.monto%type;
        v_fec_vto_linea cc_lin_sobregiros.fec_vencimiento%type;
        v_tipo ge_ext_cli_cuentas.tip_cuenta%type;
      BEGIN
        v_lugar := 'lp_generar_ctacte';
        FOR CC IN MAE_CUE LOOP
          --limpio variables
          v_SAL_PROMEDIO := null;
          v_nro_cta_combinada := null;
          v_val_tasa := null;
          v_val_tae  := null;
          --- asigno el codigo de extracto unico -----------------
          v_nro_cuenta   := cc.nro_cuenta;
          v_sal_ult_extracto := nvl(cc.SAL_ULT_EXTRACTO,0);
          v_TIENE_MOV := 'N';
          v_CANTIDAD  := 0;
          v_mto_bloqueo := lf_obt_mto_bloqueado(cc.nro_cuenta);
          --- la suma de todos los movimientos del historico -----
          SELECT 0,0,
                 COUNT('X')
            INTO v_mto_debito, v_mto_credito, v_cantidad
            FROM GE_TRANSACCIONES, CC_MOVIMIENTOS_HIS
            WHERE CC_MOVIMIENTOS_HIS.COD_MODULO = cc.COD_MODULO
              AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = cc.COD_MODALIDAD
              AND CC_MOVIMIENTOS_HIS.COD_OFICINA = cc.COD_OFICINA
              AND CC_MOVIMIENTOS_HIS.NRO_CUENTA = cc.NRO_CUENTA
              AND CC_MOVIMIENTOS_HIS.FECHA > cc.FEC_ULT_EXTRACTO
              AND CC_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
              AND(CC_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
                 (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
                  FEC_VALOR <= CC.FEC_ULT_EXTRACTO   AND
                  EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                           WHERE CC_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
                             AND CC_MOVIMIENTOS_HIS.HOR_REVERSION  = REV.HORA
                             AND CC_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
                             AND CC_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                             -- DYDMR-5672 NAF 01/2017
                             AND CC_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
                             AND abs(CC_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO)
                           )) OR
                  (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' AND CC_MOVIMIENTOS_HIS.COD_TRA_PADRE in (303,302)
                   AND CC_MOVIMIENTOS_HIS.Cod_Mad_Padre = 455))
              AND CC_MOVIMIENTOS_HIS.ESTADO = 'N'
              AND CC_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
              AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
              AND CC_MOVIMIENTOS_HIS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
              AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
              and NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
              AND CC_MOVIMIENTOS_HIS.NRO_FOLIO IS NULL
              AND GE_TRANSACCIONES.TIPO IN ('C','D');

          if v_est_modulo = 2 then
              SELECT 0,0,
                     COUNT('X')
                 INTO v_mto_debito1, v_mto_credito1, v_cantidad1
                 FROM GE_TRANSACCIONES, GE_MOVIMIENTOS
                WHERE GE_MOVIMIENTOS.COD_MODULO = cc.COD_MODULO
                  AND GE_MOVIMIENTOS.COD_MODALIDAD = cc.COD_MODALIDAD
                  AND GE_MOVIMIENTOS.COD_OFICINA = cc.COD_OFICINA
                  AND GE_MOVIMIENTOS.NRO_CUENTA = cc.NRO_CUENTA
                  AND GE_MOVIMIENTOS.FECHA > cc.FEC_ULT_EXTRACTO
                  AND GE_MOVIMIENTOS.FECHA <= v_fec_actual
                  AND(GE_MOVIMIENTOS.REVERSADO = 'N' OR
                     (GE_MOVIMIENTOS.REVERSADO = 'S' AND
                      FEC_VALOR <= CC.FEC_ULT_EXTRACTO AND
                      EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                               WHERE GE_MOVIMIENTOS.FEC_VALOR = REV.FECHA
                                 AND GE_MOVIMIENTOS.HOR_REVERSION  = REV.HORA
                                 AND GE_MOVIMIENTOS.COD_USU_REVERSION = REV.COD_USUARIO
                                 AND GE_MOVIMIENTOS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                 -- DYDMR-5672 NAF 01/2017
                                 AND GE_MOVIMIENTOS.NRO_CUENTA = REV.NRO_CUENTA
                                 AND abs(GE_MOVIMIENTOS.MONTO) = abs(REV.MONTO)
                                 )) OR
                      (GE_MOVIMIENTOS.REVERSADO = 'S' AND GE_MOVIMIENTOS.COD_TRA_PADRE in (303,302)
                       AND GE_MOVIMIENTOS.Cod_Mad_Padre = 455))
                  AND GE_MOVIMIENTOS.ESTADO = 'N'
                  AND GE_MOVIMIENTOS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                  AND GE_MOVIMIENTOS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                  AND GE_MOVIMIENTOS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                  AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                  AND GE_TRANSACCIONES.TIPO IN ('C','D')--;
                  and NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
                  --q no est? pendiente
                  and not exists (SELECT 0
                                    FROM AH_RETENCIONES
                                   WHERE AH_RETENCIONES.NRO_CUENTA = cc.nro_cuenta
                                     AND AH_RETENCIONES.COD_retencion = ge_movimientos.cod_retencion
                                     and ah_retenciones.nro_documento = ge_movimientos.nro_documento
                                     and ah_retenciones.fec_final = ge_movimientos.fec_fin_retencion
                                     AND AH_RETENCIONES.LIBERADO  = 'N')
                    and not exists (select 1 from GE_EXT_CLI_MOVIMIENTOS_TMP w
                                   where w.nro_cuenta= cc.nro_cuenta
                                   and  w.nro_documento= GE_MOVIMIENTOS.nro_documento
                                   and  w.fec_valor= GE_MOVIMIENTOS.fec_valor
                                   and  w.fec_movimiento= GE_MOVIMIENTOS.fecha
                                   );
          end if;
          V_CANTIDAD := NVL(V_CANTIDAD, 0) + NVL(v_CANTIDAD1, 0);
          v_mto_credito := NVL(V_MTO_CREDITO, 0) + NVL(V_MTO_CREDITO1,0);
          V_MTO_DEBITO := NVL(V_MTO_DEBITO, 0) + NVL(V_MTO_DEBITO1,0);
          IF V_CANTIDAD > 0 THEN
             V_TIENE_MOV := 'S';
          END IF;
            V_EXISTE := 'N';
            IF cc.SEPARADO = 'S' OR cc.COD_PAQUETE > 0 THEN
               -- es una direccion especifica, no enviar en ext.unico --
               v_cod_extracto := v_cod_extracto + 1;
               ---------------------------------------------------------
            ELSE
               --- verifico si ya existe una cabecera del extracto unico
               BEGIN
                 SELECT 'S' INTO V_EXISTE
                   FROM GE_EXT_CLIENTES_TMP
                  WHERE GE_EXT_CLIENTES_TMP.COD_PERSONA = v_cod_persona
                    AND GE_EXT_CLIENTES_TMP.COD_EXTRACTO = v_cod_extracto
                    AND GE_EXT_CLIENTES_TMP.FEC_EXTRACTO = v_fec_actual;
                 V_EXISTE := 'S';
               EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                   V_EXISTE := 'N';
                 WHEN TOO_MANY_ROWS THEN
                   V_EXISTE := 'S';
                 WHEN OTHERS THEN
                   dbms_output.put_line('ERROR al Buscar el Extr.del Cliente.CONTINUO.'||sqlerrm);
                   V_EXISTE := 'N';
               END;
            END IF;
            IF V_EXISTE = 'N' THEN
               -- busco los datos del cliente ---------------------------
               LP_OBTENER_DATOS_DEL_CLIENTE;
               lp_dir_envio;
               INSERT INTO GE_EXT_CLIENTES_TMP (COD_PERSONA, FEC_EXTRACTO, FRE_EXTRACTO,
                                    FUNCIONARIO, NOM_CLIENTE, DIRECCION,
                                    TELEFONO, COD_USU_OFICIAL, COD_PAIS,
                                    COD_CIUDAD, TEL_OFICIAL, NRO_INTERNO,
                                    COD_EXTRACTO, DET_DIRECCION, OBSERVACION,
                                    BARRIO, COD_MENSAJE, tip_impresion,
                                    CLI_CONFIDENCIAL, COD_OFICINA,
                                    Cat_Riesgo,Fec_Ult_Clasif )
                            VALUES (v_cod_persona, v_fec_actual,
                                    v_fre_extracto,v_es_empleado,
                                    v_nom_cliente, v_dir_cliente,
                                    v_tel_cliente, v_cod_usu_oficial,
                                    v_cod_pais, v_cod_ciudad,
                                    v_tel_oficial, v_int_oficial,v_cod_extracto,
                                    v_pri_obs_dir, v_seg_obs_dir,
                                    v_des_barrio, '1', v_imprime_extracto,
                                    v_cli_confidencial, decode(cc.SEPARADO,'S',cc.cod_oficina,v_cod_ofi_cliente),
                                    v_cat_riesgo, v_fec_ult_clasif);
               v_INSERTA := 'S';
            END IF;
            ----------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
            ----------------------------------------------------
            --busca la cuenta combinada si corresponde
            if cc.cta_combinada ='S' then
               begin
                  select nro_cta_ahorro
                    into v_nro_cta_combinada
                    from cc_cta_combinadas
                   where nro_cta_cte = cc.nro_cuenta;
               exception
                  when no_data_found then
                     null;
                  when others then
                     null;
               end;
            end if;
            --obtiene saldo promedio
            pag_cta.PR_OBT_SAL_PROMEDIO(cc.COD_MODULO,cc.COD_MODALIDAD,cc.COD_OFICINA,
                    cc.NRO_CUENTA,v_fec_actual,v_fec_actual, v_SAL_ACUMULADO, v_SAL_PROMEDIO,v_CAN_DIA_ACUMULADO);
            --- cargo los valores para el calculo de la tasa --
            v_val_tasa := fug_obt_val_tasa(cc.cod_modulo, cc.cod_modalidad, cc.cod_oficina, cc.nro_cuenta, cc.cod_moneda, v_SAL_PROMEDIO, cc.tas_personalizada,
                          null, 550, v_fec_actual);--busca x la transacci?n de sobregiro
            --obtiene tae
            v_val_tae := pas_bcp.FU_OBT_TAE(v_val_tasa,30);
            --si saldo negativo -> tipo Pr?stamo
            if NVL(v_sal_ult_extracto,0) + NVL(v_mto_credito,0) - NVL(v_mto_debito,0) < 0 then
               v_tipo := 'P';
            else --si saldo positivo -> tipo Ahorro
               v_tipo := 'A';
            end if;
            v_sal_blo_anterior := lf_obt_sal_blo_anterior(cc.NRO_CUENTA,cc.fec_ult_extracto);
            INSERT INTO GE_EXT_CLI_CUENTAS_TMP (GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA, GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO, GE_EXT_CLI_CUENTAS_TMP.TIP_CUENTA,
                                 GE_EXT_CLI_CUENTAS_TMP.COD_OFICINA, GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD, GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA,
                                 GE_EXT_CLI_CUENTAS_TMP.COD_MONEDA, GE_EXT_CLI_CUENTAS_TMP.SAL_ANTERIOR, GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL,
                                 GE_EXT_CLI_CUENTAS_TMP.NRO_FOLIO, GE_EXT_CLI_CUENTAS_TMP.SAL_A_CONFIRMAR, GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO,
                                 GE_EXT_CLI_CUENTAS_TMP.FRE_EXTRACTO, sal_promedio, nro_cta_combinada, Tas_Nominal, Tas_Efectiva, cod_modulo,
                                 GE_EXT_CLI_CUENTAS_TMP.SAL_BLOQUEADO, SAL_BLO_ANTERIOR)
                         VALUES (v_cod_persona,  v_fec_actual, v_tipo, --'A',
                                 cc.COD_OFICINA,cc.COD_MODALIDAD,cc.NRO_CUENTA,
                                 cc.COD_MONEDA, v_sal_ult_extracto,
                                 NVL(v_sal_ult_extracto,0) + NVL(v_mto_credito,0) -
                                                     NVL(v_mto_debito,0),
                                 cc.NRO_FOLIO, cc.SAL_RETENIDO, v_cod_extracto,
                                 v_fre_extracto, v_sal_promedio, v_nro_cta_combinada, v_val_tasa, v_val_tae,
                                 cc.COD_MODULO, v_mto_bloqueo, v_sal_blo_anterior);
           
               --------------------------------------------
               -- INSERTA REGISTRO EN EL ARCHIVO DETALLE --
               --------------------------------------------
       IF v_tiene_mov = 'S' THEN
               INSERT INTO GE_EXT_CLI_MOVIMIENTOS_TMP (COD_PERSONA, FEC_EXTRACTO, FEC_MOVIMIENTO,
                                    FEC_VALOR, HOR_MOVIMIENTO, NRO_CUENTA,
                                    NRO_DOCUMENTO, COD_MODULO, COD_MODALIDAD,
                                    COD_TRA_PADRE, MTO_DEBITO, MTO_CREDITO,
                                    COD_EXTRACTO, FRE_EXTRACTO, NRO_SECUENCIA, cod_ofi_origen, Fec_Insercion)
               SELECT  v_cod_persona, v_fec_actual,
                       CC_MOVIMIENTOS_HIS.FECHA, CC_MOVIMIENTOS_HIS.FEC_VALOR, CC_MOVIMIENTOS_HIS.HORA, CC_MOVIMIENTOS_HIS.NRO_CUENTA,
                       CC_MOVIMIENTOS_HIS.NRO_DOCUMENTO, CC_MOVIMIENTOS_HIS.COD_MOD_PADRE, CC_MOVIMIENTOS_HIS.COD_MAD_PADRE, CC_MOVIMIENTOS_HIS.COD_TRA_PADRE,
                       DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'D',
                          NVL(CC_MOVIMIENTOS_HIS.MONTO,0),
                          0),
                       DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'C',
                           NVL(CC_MOVIMIENTOS_HIS.MONTO,0),
                           0),
                       v_cod_extracto, v_fre_extracto, CC_MOVIMIENTOS_HIS.NRO_SECUENCIA, cc_movimientos_his.cod_ofi_origen, cc_movimientos_his.fec_insercion
                FROM GE_TRANSACCIONES, CC_MOVIMIENTOS_HIS
               WHERE CC_MOVIMIENTOS_HIS.COD_MODULO = cc.COD_MODULO
                 AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = cc.COD_MODALIDAD
                 AND CC_MOVIMIENTOS_HIS.COD_OFICINA = cc.COD_OFICINA
                 AND CC_MOVIMIENTOS_HIS.NRO_CUENTA = cc.NRO_CUENTA
                 AND CC_MOVIMIENTOS_HIS.FECHA > cc.FEC_ULT_EXTRACTO
                 AND CC_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
                 AND(CC_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
                    (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
                     FEC_VALOR <= CC.FEC_ULT_EXTRACTO   AND
                     EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                              WHERE CC_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
                                AND CC_MOVIMIENTOS_HIS.HOR_REVERSION  = REV.HORA
                                AND CC_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
                                AND CC_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                -- DYDMR-5672 NAF 01/2017
                                AND CC_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
                                AND abs(CC_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO)
                             )) OR
                     (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' AND CC_MOVIMIENTOS_HIS.COD_TRA_PADRE in (303,302)
                      AND CC_MOVIMIENTOS_HIS.Cod_Mad_Padre = 455))
                 AND CC_MOVIMIENTOS_HIS.ESTADO = 'N'
                 AND CC_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                 AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                 AND CC_MOVIMIENTOS_HIS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                 AND CC_MOVIMIENTOS_HIS.NRO_FOLIO IS NULL
                 AND NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
                 AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                 AND GE_TRANSACCIONES.TIPO IN ('C','D');
               if v_est_modulo = 2 then
                   -- Inserta los movimientos del d?a
                   INSERT INTO GE_EXT_CLI_MOVIMIENTOS_TMP (COD_PERSONA, FEC_EXTRACTO, FEC_MOVIMIENTO,
                                        FEC_VALOR, HOR_MOVIMIENTO, NRO_CUENTA,
                                        NRO_DOCUMENTO, COD_MODULO, COD_MODALIDAD,
                                        COD_TRA_PADRE, MTO_DEBITO, MTO_CREDITO,
                                        COD_EXTRACTO, FRE_EXTRACTO, NRO_SECUENCIA, cod_ofi_origen, Fec_Insercion)
                   SELECT  v_cod_persona, v_fec_actual,
                           GE_MOVIMIENTOS.FECHA, GE_MOVIMIENTOS.FEC_VALOR, GE_MOVIMIENTOS.HORA, GE_MOVIMIENTOS.NRO_CUENTA,
                           GE_MOVIMIENTOS.NRO_DOCUMENTO, GE_MOVIMIENTOS.COD_MOD_PADRE, GE_MOVIMIENTOS.COD_MAD_PADRE, GE_MOVIMIENTOS.COD_TRA_PADRE,
                           DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'D',
                           NVL(GE_MOVIMIENTOS.MONTO,0),
                           0),
                           DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'C',
                           NVL(GE_MOVIMIENTOS.MONTO,0),
                           0),
                           v_cod_extracto, v_fre_extracto, GE_MOVIMIENTOS.NRO_SECUENCIA, ge_movimientos.cod_ofi_origen, ge_movimientos.fec_insercion
                    FROM GE_TRANSACCIONES, GE_MOVIMIENTOS
                   WHERE GE_MOVIMIENTOS.COD_MODULO = cc.COD_MODULO
                     AND GE_MOVIMIENTOS.COD_MODALIDAD = cc.COD_MODALIDAD
                     AND GE_MOVIMIENTOS.COD_OFICINA = cc.COD_OFICINA
                     AND GE_MOVIMIENTOS.NRO_CUENTA = cc.NRO_CUENTA
--                   Ya no tiene en cuenta las fechas porque se supone son movimientos que no han pasado al historico
                     AND GE_MOVIMIENTOS.FECHA <= v_fec_actual
                     AND(GE_MOVIMIENTOS.REVERSADO = 'N' OR
                        (GE_MOVIMIENTOS.REVERSADO = 'S' AND
                         FEC_VALOR <= CC.FEC_ULT_EXTRACTO   AND
                         EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013. SPI XXXX
                                  WHERE GE_MOVIMIENTOS.FEC_VALOR = REV.FECHA
                                    AND GE_MOVIMIENTOS.HOR_REVERSION  = REV.HORA
                                    AND GE_MOVIMIENTOS.COD_USU_REVERSION = REV.COD_USUARIO
                                    AND GE_MOVIMIENTOS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                    -- DYDMR-5672 NAF 01/2017
                                    AND GE_MOVIMIENTOS.NRO_CUENTA = REV.NRO_CUENTA
                                    AND abs(GE_MOVIMIENTOS.MONTO) = abs(REV.MONTO)
                                    )) OR
                        (GE_MOVIMIENTOS.REVERSADO = 'S' AND GE_MOVIMIENTOS.COD_TRA_PADRE in (303,302)
                         AND GE_MOVIMIENTOS.Cod_Mad_Padre = 455))
                     AND GE_MOVIMIENTOS.ESTADO = 'N'
                     AND GE_MOVIMIENTOS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                     AND GE_MOVIMIENTOS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                     AND GE_MOVIMIENTOS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                     AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                     AND GE_TRANSACCIONES.TIPO IN ('C','D')--
                     AND NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
                     --q no est? pendiente
                     and not exists (SELECT 0
                                        FROM AH_RETENCIONES
                                       WHERE AH_RETENCIONES.NRO_CUENTA = cc.nro_cuenta
                                         AND AH_RETENCIONES.COD_retencion = ge_movimientos.cod_retencion
                                         and ah_retenciones.nro_documento = ge_movimientos.nro_documento
                                         and ah_retenciones.fec_final = ge_movimientos.fec_fin_retencion
                                         AND AH_RETENCIONES.LIBERADO  = 'N')
                   and not exists (select 1 from GE_EXT_CLI_MOVIMIENTOS_TMP w
                                   where w.nro_cuenta= GE_MOVIMIENTOS.nro_cuenta
                                   and  w.nro_documento= GE_MOVIMIENTOS.nro_documento
                                   and  w.fec_valor= GE_MOVIMIENTOS.fec_valor
                                   and  w.fec_movimiento= GE_MOVIMIENTOS.fecha
                                   );
              end if;
            END IF;
           --Ajuste para insertar movimientos_noc
                   INSERT INTO GE_EXT_CLI_MOVIMIENTOS_TMP (COD_PERSONA, FEC_EXTRACTO, FEC_MOVIMIENTO,
                                        FEC_VALOR, HOR_MOVIMIENTO, NRO_CUENTA,
                                        NRO_DOCUMENTO, COD_MODULO, COD_MODALIDAD,
                                        COD_TRA_PADRE, MTO_DEBITO, MTO_CREDITO,
                                        COD_EXTRACTO, FRE_EXTRACTO, NRO_SECUENCIA, cod_ofi_origen, Fec_Insercion)
                   SELECT  v_cod_persona, v_fec_actual,
                           GE_MOVIMIENTOS_NOC.FECHA, GE_MOVIMIENTOS_NOC.FEC_VALOR, GE_MOVIMIENTOS_NOC.HORA, GE_MOVIMIENTOS_NOC.NRO_CUENTA,
                           GE_MOVIMIENTOS_NOC.NRO_DOCUMENTO, GE_MOVIMIENTOS_NOC.COD_MOD_PADRE, GE_MOVIMIENTOS_NOC.COD_MAD_PADRE, GE_MOVIMIENTOS_NOC.COD_TRA_PADRE,
                           DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'D',
                           NVL(GE_MOVIMIENTOS_NOC.MONTO,0),
                           0),
                           DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'C',
                           NVL(GE_MOVIMIENTOS_NOC.MONTO,0),
                           0),
                           v_cod_extracto, v_fre_extracto, GE_MOVIMIENTOS_NOC.NRO_SECUENCIA, GE_MOVIMIENTOS_NOC.cod_ofi_origen, GE_MOVIMIENTOS_NOC.fec_insercion
                    FROM GE_TRANSACCIONES, GE_MOVIMIENTOS_NOC
                   WHERE GE_MOVIMIENTOS_NOC.COD_MODULO = cc.COD_MODULO
                     AND GE_MOVIMIENTOS_NOC.COD_MODALIDAD = cc.COD_MODALIDAD
                     AND GE_MOVIMIENTOS_NOC.COD_OFICINA = cc.COD_OFICINA
                     AND GE_MOVIMIENTOS_NOC.NRO_CUENTA = cc.NRO_CUENTA
                     --Tomamos la fecha de inserción para que cuadre
                     AND TRUNC(GE_MOVIMIENTOS_NOC.FEC_INSERCION) <= v_fec_actual
                     AND(GE_MOVIMIENTOS_NOC.REVERSADO = 'N' OR
                        (GE_MOVIMIENTOS_NOC.REVERSADO = 'S' AND
                         FEC_VALOR <= CC.FEC_ULT_EXTRACTO   AND
                         EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013. SPI XXXX
                                  WHERE GE_MOVIMIENTOS_NOC.FEC_VALOR = REV.FECHA
                                    AND GE_MOVIMIENTOS_NOC.HOR_REVERSION  = REV.HORA
                                    AND GE_MOVIMIENTOS_NOC.COD_USU_REVERSION = REV.COD_USUARIO
                                    AND GE_MOVIMIENTOS_NOC.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                    -- DYDMR-5672 NAF 01/2017
                                    AND GE_MOVIMIENTOS_NOC.NRO_CUENTA = REV.NRO_CUENTA
                                    AND abs(GE_MOVIMIENTOS_NOC.MONTO) = abs(REV.MONTO)
                                    )) OR
                        (GE_MOVIMIENTOS_NOC.REVERSADO = 'S' AND GE_MOVIMIENTOS_NOC.COD_TRA_PADRE in (303,302)
                         AND GE_MOVIMIENTOS_NOC.Cod_Mad_Padre = 455))
                     AND GE_MOVIMIENTOS_NOC.ESTADO = 'N'
                     AND GE_MOVIMIENTOS_NOC.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                     AND GE_MOVIMIENTOS_NOC.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                     AND GE_MOVIMIENTOS_NOC.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                     AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                     AND GE_TRANSACCIONES.TIPO IN ('C','D')--
                     AND NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
                     --q no est? pendiente
                     and not exists (SELECT 0
                                        FROM AH_RETENCIONES
                                       WHERE AH_RETENCIONES.NRO_CUENTA = cc.nro_cuenta
                                         AND AH_RETENCIONES.COD_retencion = GE_MOVIMIENTOS_NOC.cod_retencion
                                         and ah_retenciones.nro_documento = GE_MOVIMIENTOS_NOC.nro_documento
                                         and ah_retenciones.fec_final = GE_MOVIMIENTOS_NOC.fec_fin_retencion
                                         AND AH_RETENCIONES.LIBERADO  = 'N')
                   and not exists (select 1 from GE_EXT_CLI_MOVIMIENTOS_TMP w
                                   where w.nro_cuenta= GE_MOVIMIENTOS_NOC.nro_cuenta
                                   and  w.nro_documento= GE_MOVIMIENTOS_NOC.nro_documento
                                   and  w.fec_valor= GE_MOVIMIENTOS_NOC.fec_valor
                                   and  w.fec_movimiento= GE_MOVIMIENTOS_NOC.fecha
                                   );

         END LOOP;
   end lp_generar_ctacte;

  PROCEDURE lp_generar_ctaban IS
    v_sal_ult_extracto NUMBER(18,2) default 0;
    v_mto_debito       NUMBER(18,2);
    v_mto_credito      NUMBER(18,2);
    v_cantidad         NUMBER(6) := 0;
    v_mto_debito1      NUMBER(18,2);
    v_mto_credito1     NUMBER(18,2);
    v_cantidad1        NUMBER(6) := 0;
    v_existe           VARCHAR2(1) := 'N';
    v_tiene_mov        VARCHAR2(1) := 'N';
    v_imprime_extracto VARCHAR2(1);
    ----------------------------------
    -- CURSOR DEL ARCHIVO PRINCIPAL --
    ----------------------------------
    CURSOR cuentas
        IS SELECT t.cod_modulo, t.cod_modalidad, t.cod_oficina, t.nro_cuenta,
                  c.cod_moneda, c.sal_ult_extracto, nvl( c.nro_folio, 0 ) nro_folio,
                  c.denominacion, c.sal_retenido, nvl( c.fec_ult_extracto, c.fec_apertura -1 ) fec_ult_extracto,
                  decode( d.nro_cuenta, NULL, 'N', 'S' ) separado, c.rowid registro,
                  c.sal_bloqueado
             from ge_dir_envios d, cc_cta_bancarias c, ge_cta_clientes t
            where d.cod_persona (+) = t.cod_persona
              and d.nro_cuenta (+) = t.nro_cuenta
              and t.cod_persona = v_cod_persona
              and t.nro_cuenta = nvl(v_nro_cta_parametro, t.nro_cuenta) --si es x cuenta
              and t.relacion = 'P'
              and c.cod_modulo = t.cod_modulo
              and c.cod_modalidad = t.cod_modalidad
              and c.cod_oficina = t.cod_oficina
              and c.nro_cuenta = t.nro_cuenta
              and ( ( c.estado NOT IN( 'C', 'P' ) ) or
                    ( c.estado IN( 'C', 'P' ) and
                      c.fec_ult_movimiento >=  v_pri_dia_mes_habil and
                      c.fec_ult_movimiento > nvl( c.fec_ult_extracto, c.fec_apertura -1 ) ) );
  BEGIN
    v_lugar := 'lp_generar_ctaban';
    FOR x IN cuentas LOOP
      --- asigno el codigo de extracto unico -----------------
      v_nro_cuenta := x.nro_cuenta;
      --WA:06/08/2014 Se modifica para modalidad 49 Financieras del Pais
      IF x.cod_modalidad IN (42, 48,455,49) THEN -- BANCOS DEL PA?S
        v_sal_ult_extracto := nvl( x.sal_ult_extracto, 0 ) * -1;
      ELSE
        v_sal_ult_extracto := nvl( x.sal_ult_extracto, 0 );
      END IF;
      v_tiene_mov := 'N';
      v_cantidad  := 0;
      v_mto_bloqueo := lf_obt_mto_bloqueado(x.nro_cuenta);
      --- la suma de todos los movimientos del historico -----
      BEGIN
        select SUM(DECODE(fug_obt_tra_tipo(t.cod_transaccion,
                                           t.tipo,
                                           t.afecta), 'D',
                          NVL(h.MONTO,0),
                          0)
                          ),
                 SUM(DECODE(fug_obt_tra_tipo(t.cod_transaccion,
                                             t.tipo,
                                             t.afecta), 'C',
                           NVL(h.MONTO,0),
                           0)
                           ),
               count( 'X' )
          into v_mto_debito, v_mto_credito, v_cantidad
          from ge_transacciones t, cc_movimientos_his h
         where h.cod_modulo = x.cod_modulo
           and h.cod_modalidad = x.cod_modalidad
           and h.cod_oficina = x.cod_oficina
           and h.nro_cuenta = x.nro_cuenta
           and h.fecha > x.fec_ult_extracto
           and h.fecha <= v_fec_actual
           AND (h.REVERSADO = 'N' OR
     --DYDMR-6072 - Incidencia SAU - ITGF - Incidencia Generaci?n de Datos de Cuentas Bancarias
                 (h.REVERSADO = 'S' AND
                  FEC_VALOR <= x.fec_ult_extracto      AND
                  EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                           WHERE h.FEC_VALOR = REV.FECHA
                             AND h.HOR_REVERSION  = REV.HORA
                             AND h.COD_USU_REVERSION = REV.COD_USUARIO
                             AND h.NRO_SECUENCIA = REV.NRO_SECUENCIA
                             -- DYDMR-5672 NAF 01/2017
                             AND h.NRO_CUENTA = REV.NRO_CUENTA
                             AND abs(h.MONTO) = abs(REV.MONTO)
                         )) OR
                 (h.REVERSADO = 'S' AND h.COD_TRA_PADRE in (303,302)
                   AND h.COD_MAD_PADRE = 455))
           and h.estado = 'N'
           and h.cod_modulo = t.cod_modulo
           and h.cod_modalidad = t.cod_modalidad
           and h.cod_transaccion = t.cod_transaccion
           and t.ve_cliente = 'S'
           and h.nro_folio IS NULL
           and t.tipo IN( 'C', 'D' )
           and nvl(t.afecta, 'XX') != 'B';
      EXCEPTION
        when others then
          v_mto_debito := 0;
          v_mto_credito := 0;
          v_cantidad := 0;
      END;
      if v_est_modulo = 2 then
          BEGIN
            select SUM(DECODE(fug_obt_tra_tipo(t.cod_transaccion,
                                           t.tipo,
                                           t.afecta), 'D',
                          NVL(m.MONTO,0),
                          0)
                          ),
                 SUM(DECODE(fug_obt_tra_tipo(t.cod_transaccion,
                                             t.tipo,
                                             t.afecta), 'C',
                           NVL(m.MONTO,0),
                           0)
                           ),
               count( 'X' )
              into v_mto_debito1, v_mto_credito1, v_cantidad1
              from ge_transacciones t, ge_movimientos m
             where m.cod_modulo = x.cod_modulo
               and m.cod_modalidad = x.cod_modalidad
               and m.cod_oficina = x.cod_oficina
               and m.nro_cuenta = x.nro_cuenta
               and m.fecha <= v_fec_actual
               AND (m.REVERSADO = 'N' OR
         --DYDMR-6072 - Incidencia SAU - ITGF - Incidencia Generaci?n de Datos de Cuentas Bancarias
                 (m.REVERSADO = 'S' AND
                  FEC_VALOR <= x.fec_ult_extracto      AND
                  EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                           WHERE m.FEC_VALOR = REV.FECHA
                             AND m.HOR_REVERSION  = REV.HORA
                             AND m.COD_USU_REVERSION = REV.COD_USUARIO
                             AND m.NRO_SECUENCIA = REV.NRO_SECUENCIA
                             -- DYDMR-5672 NAF 01/2017
                             AND m.NRO_CUENTA = REV.NRO_CUENTA
                             AND abs(m.MONTO) = abs(REV.MONTO)
                         )) OR
                 (m.REVERSADO = 'S' AND m.COD_TRA_PADRE in (303,302)
                   AND m.COD_MAD_PADRE = 455))
               and m.estado = 'N'
               and m.cod_modulo = t.cod_modulo
               and m.cod_modalidad = t.cod_modalidad
               and m.cod_transaccion = t.cod_transaccion
               and t.ve_cliente = 'S'
               and t.tipo IN( 'C', 'D' )
               and nvl(t.afecta,'XX') != 'B'
               --q no est? pendiente
               and not exists (SELECT 0
                                 FROM AH_RETENCIONES
                                WHERE AH_RETENCIONES.NRO_CUENTA = m.nro_cuenta
                                  AND AH_RETENCIONES.COD_retencion = m.cod_retencion
                                  and ah_retenciones.nro_documento = m.nro_documento
                                  and ah_retenciones.fec_final = m.fec_fin_retencion
                                  AND AH_RETENCIONES.LIBERADO  = 'N')
              and not exists (select 1 from GE_EXT_CLI_MOVIMIENTOS_TMP w
                                   where w.nro_cuenta= m.nro_cuenta
                                   and  w.nro_documento= m.nro_documento
                                   and  w.fec_valor= m.fec_valor
                                   and  w.fec_movimiento= m.fecha
                                   );
          EXCEPTION
            when others then
              v_mto_debito1 := 0;
              v_mto_credito1 := 0;
              v_cantidad1 := 0;
          END;
      end if;
      v_cantidad := nvl( v_cantidad, 0 ) + nvl( v_cantidad1, 0 );
      v_mto_credito := nvl( v_mto_credito, 0 ) + nvl( v_mto_credito1, 0 );
      v_mto_debito := nvl( v_mto_debito, 0 ) + nvl( v_mto_debito1, 0 );
      IF v_cantidad > 0 THEN
        v_tiene_mov := 'S';
      END IF;
      v_existe := 'N';
      IF x.separado = 'S' THEN
        -- es una direccion especifica, no enviar en ext.unico --
        v_cod_extracto := v_cod_extracto + 1;
        ---------------------------------------------------------
      ELSE
        --- verifico si ya existe una cabecera del extracto unico
        BEGIN
          select 'S'
            into v_existe
            from ge_ext_clientes_tmp
           where cod_persona = v_cod_persona
             and cod_extracto = v_cod_extracto
             and fec_extracto = v_fec_actual;
          v_existe := 'S';
        EXCEPTION
          when no_data_found then
            v_existe := 'N';
          when too_many_rows then
            v_existe := 'S';
          when others then
            dbms_output.put_line('ERROR al Buscar el Extr.del Cliente.CONTINUO.'||sqlerrm);
            v_existe := 'N';
        END;
      END IF;
      IF v_existe = 'N' THEN
        -- busco los datos del cliente ---------------------------
        lp_obtener_datos_del_cliente;
        lp_dir_envio;
        BEGIN
          insert into ge_ext_clientes_tmp( cod_persona,
                                           fec_extracto,
                                           fre_extracto,
                                           funcionario,
                                           nom_cliente,
                                           direccion,
                                           telefono,
                                           cod_usu_oficial,
                                           cod_pais,
                                           cod_ciudad,
                                           tel_oficial,
                                           nro_interno,
                                           cod_extracto,
                                           det_direccion,
                                           observacion,
                                           barrio,
                                           cod_mensaje,
                                           tip_impresion,
                                           cli_confidencial,
                                           cod_oficina,
                                           cat_riesgo,
                                           fec_ult_clasif )
                                   values( v_cod_persona,
                                           v_fec_actual,
                                           v_fre_extracto,
                                           v_es_empleado,
                                           v_nom_cliente,
                                           v_dir_cliente,
                                           v_tel_cliente,
                                           v_cod_usu_oficial,
                                           v_cod_pais,
                                           v_cod_ciudad,
                                           v_tel_oficial,
                                           v_int_oficial,
                                           v_cod_extracto,
                                           v_pri_obs_dir,
                                           v_seg_obs_dir,
                                           v_des_barrio,
                                           '1',
                                           v_imprime_extracto,
                                           v_cli_confidencial,
                                           decode(x.SEPARADO,'S',x.cod_oficina,v_cod_ofi_cliente),
                                           v_cat_riesgo,
                                           v_fec_ult_clasif );
          v_inserta := 'S';
        EXCEPTION
          when others then
            NULL;
        END;
      END IF;
      ----------------------------------------------------
      -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
      ----------------------------------------------------
        BEGIN
          insert into ge_ext_cli_cuentas_tmp( cod_persona,
                                              fec_extracto,
                                              tip_cuenta,
                                              cod_oficina,
                                              cod_modalidad,
                                              nro_cuenta,
                                              cod_moneda,
                                              sal_anterior,
                                              sal_actual,
                                              nro_folio,
                                              sal_a_confirmar,
                                              cod_extracto,
                                              fre_extracto,
                                              cod_modulo,
                                              sal_bloqueado )
                                      values( v_cod_persona,
                                              v_fec_actual,
                                              'A',
                                              x.cod_oficina,
                                              x.cod_modalidad,
                                              x.nro_cuenta,
                                              x.cod_moneda,
                                              v_sal_ult_extracto,
                                              nvl( v_sal_ult_extracto, 0 ) - nvl( v_mto_credito, 0 ) + nvl( v_mto_debito, 0 ),
                                              x.nro_folio,
                                              x.sal_retenido,
                                              v_cod_extracto,
                                              v_fre_extracto,
                                              x.cod_modulo,
                                              v_mto_bloqueo );
        EXCEPTION
          when others then
            NULL;
        END;
       IF v_tiene_mov = 'S' THEN
        BEGIN
          --------------------------------------------
          -- INSERTA REGISTRO EN EL ARCHIVO DETALLE --
          --------------------------------------------

          insert into ge_ext_cli_movimientos_tmp( cod_persona,
                                                  fec_extracto,
                                                  fec_movimiento,
                                                  fec_valor,
                                                  hor_movimiento,
                                                  nro_cuenta,
                                                  nro_documento,
                                                  cod_modulo,
                                                  cod_modalidad,
                                                  cod_tra_padre,
                                                  mto_debito,
                                                  mto_credito,
                                                  cod_extracto,
                                                  fre_extracto,
                                                  nro_secuencia,
                                                  cod_ofi_origen,
                                                  fec_insercion )
                                           select v_cod_persona,
                                                  v_fec_actual,
                                                  h.fecha,
                                                  h.fec_valor,
                                                  h.hora,
                                                  h.nro_cuenta,
                                                  h.nro_documento,
                                                  h.cod_mod_padre,
                                                  h.cod_mad_padre,
                                                  h.cod_tra_padre,
                                                  DECODE(fug_obt_tra_tipo(t.cod_transaccion,
                                                                          t.tipo,
                                                                          t.afecta), 'D',
                                                                          NVL(h.MONTO,0),
                                                                          0),
                                                  DECODE(fug_obt_tra_tipo(t.cod_transaccion,
                                                                          t.tipo,
                                                                          t.afecta), 'C',
                                                                          NVL(h.MONTO,0),
                                                                          0),
                                                  v_cod_extracto,
                                                  v_fre_extracto,
                                                  h.nro_secuencia,
                                                  h.cod_ofi_origen,
                                                  h.fec_insercion
                                             from ge_transacciones t, cc_movimientos_his h
                                            where h.cod_modulo = x.cod_modulo
                                              and h.cod_modalidad = x.cod_modalidad
                                              and h.cod_oficina = x.cod_oficina
                                              and h.nro_cuenta = x.nro_cuenta
                                              and h.fecha > x.fec_ult_extracto
                                              and h.fecha <= v_fec_actual
                                              AND (h.REVERSADO = 'N' OR
                   --DYDMR-6072 - Incidencia SAU - ITGF - Incidencia Generaci?n de Datos de Cuentas Bancarias
                                                 (h.REVERSADO = 'S' AND
                                                  FEC_VALOR <= x.fec_ult_extracto      AND
                                                  EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                                                           WHERE h.FEC_VALOR = REV.FECHA
                                                             AND h.HOR_REVERSION  = REV.HORA
                                                             AND h.COD_USU_REVERSION = REV.COD_USUARIO
                                                             AND h.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                                             -- DYDMR-5672 NAF 01/2017
                                                             AND h.NRO_CUENTA = REV.NRO_CUENTA
                                                             AND abs(h.MONTO) = abs(REV.MONTO)
                                                         )) OR
                                                 (h.REVERSADO = 'S' AND h.COD_TRA_PADRE in (303,302)
                                                   AND h.COD_MAD_PADRE = 455))
                                              and h.estado = 'N'
                                              and h.cod_modulo = t.cod_modulo
                                              and h.cod_modalidad = t.cod_modalidad
                                              and h.cod_transaccion = t.cod_transaccion
                                              and h.nro_folio IS NULL
                                              AND (nvl(t.afecta,'XX') = 'B'
                                                   AND H.COD_CAUSA IN
                                                   (select cod_causa
                                                      from ge_par_causales
                                                     where parametro = 'COD_CAU_BLO_EXT'
                                                       and val_parametro = 'S' )
                                                  OR nvl(t.afecta,'XX') != 'B')
                                              and t.ve_cliente = 'S'
                                              and t.tipo IN( 'C', 'D' );
        EXCEPTION
          when others then
            NULL;
        END;
        BEGIN
          if v_est_modulo = 2 then
            -- Inserta los movimientos del d?a
            insert into ge_ext_cli_movimientos_tmp( cod_persona,
                                                    fec_extracto,
                                                    fec_movimiento,
                                                    fec_valor,
                                                    hor_movimiento,
                                                    nro_cuenta,
                                                    nro_documento,
                                                    cod_modulo,
                                                    cod_modalidad,
                                                    cod_tra_padre,
                                                    mto_debito,
                                                    mto_credito,
                                                    cod_extracto,
                                                    fre_extracto,
                                                    nro_secuencia,
                                                    cod_ofi_origen,
                                                    fec_insercion )
                                             select v_cod_persona,
                                                    v_fec_actual,
                                                    m.fecha,
                                                    m.fec_valor,
                                                    m.hora,
                                                    m.nro_cuenta,
                                                    m.nro_documento,
                                                    m.cod_mod_padre,
                                                    m.cod_mad_padre,
                                                    m.cod_tra_padre,
                                                    DECODE(fug_obt_tra_tipo(t.cod_transaccion,
                                                                          t.tipo,
                                                                          t.afecta), 'D',
                                                                          NVL(m.MONTO,0),
                                                                          0),
                                                     DECODE(fug_obt_tra_tipo(t.cod_transaccion,
                                                                          t.tipo,
                                                                          t.afecta), 'C',
                                                                          NVL(m.MONTO,0),
                                                                          0),
                                                    v_cod_extracto,
                                                    v_fre_extracto,
                                                    m.nro_secuencia,
                                                    m.cod_ofi_origen,
                                                    m.fec_insercion
                                               from ge_transacciones t, ge_movimientos m
                                              where m.cod_modulo = x.cod_modulo
                                                and m.cod_modalidad = x.cod_modalidad
                                                and m.cod_oficina = x.cod_oficina
                                                and m.nro_cuenta = x.nro_cuenTA
                                                and m.fecha <= v_fec_actual
                                                AND (M.REVERSADO = 'N' or
                                                    (M.REVERSADO = 'S' and FEC_VALOR <= x.fec_ult_extracto))
                                                and m.estado = 'N'
                                                and m.cod_modulo = t.cod_modulo
                                                and m.cod_modalidad = t.cod_modalidad
                                                and m.cod_transaccion = t.cod_transaccion
                                                and t.ve_cliente = 'S'
                                                and t.tipo IN( 'C', 'D' )
                                                AND (nvl(t.afecta,'XX') = 'B'
                                                     AND M.COD_CAUSA IN
                                                     (select cod_causa
                                                        from ge_par_causales
                                                       where parametro = 'COD_CAU_BLO_EXT'
                                                         and val_parametro = 'S' )
                                                    OR nvl(t.afecta,'XX') != 'B')
                                                --q no est? pendiente
                                                and not exists (SELECT 0
                                                          FROM AH_RETENCIONES
                                                         WHERE AH_RETENCIONES.NRO_CUENTA = m.nro_cuenta
                                                           AND AH_RETENCIONES.COD_retencion = m.cod_retencion
                                                           and ah_retenciones.nro_documento = m.nro_documento
                                                           and ah_retenciones.fec_final = m.fec_fin_retencion
                                                           AND AH_RETENCIONES.LIBERADO  = 'N')
                                               and not exists (select 1 from GE_EXT_CLI_MOVIMIENTOS_TMP w
                                                   where w.nro_cuenta= m.nro_cuenta
                                                   and  w.nro_documento= m.nro_documento
                                                   and  w.fec_valor= m.fec_valor
                                                   and  w.fec_movimiento= m.fecha
                                                   );
          END IF;
        EXCEPTION
          when others then
            NULL;
        END;
      END IF; -- end if de V_TIENE_MOV
    END LOOP;
  END lp_generar_ctaban;

   procedure lp_generar_vistas is
      v_sal_ult_extracto NUMBER(18,2) default 0;
      v_mto_debito NUMBER(18,2);
      v_mto_credito NUMBER(18,2);
      v_CANTIDAD  NUMBER(06) := 0;

      v_mto_debito1 NUMBER(18,2);
      v_mto_credito1 NUMBER(18,2);
      v_CANTIDAD1  NUMBER(06) := 0;

      v_EXISTE  VARCHAR2(01) := 'N';
      v_TIENE_MOV VARCHAR2(01) := 'N';
      v_imprime_extracto varchar2(1);
      ----------------------------------
      -- CURSOR DEL ARCHIVO PRINCIPAL --
      ----------------------------------
      CURSOR MAE_CUE IS
      SELECT GE_CTA_CLIENTES.COD_MODULO, GE_CTA_CLIENTES.COD_MODALIDAD, GE_CTA_CLIENTES.COD_OFICINA, GE_CTA_CLIENTES.NRO_CUENTA,
             AH_CTA_VISTAS.COD_MONEDA, AH_CTA_VISTAS.SAL_ULT_EXTRACTO, nvl(AH_CTA_VISTAS.NRO_FOLIO, 0) NRO_FOLIO, AH_CTA_VISTAS.DENOMINACION,
             AH_CTA_VISTAS.SAL_RETENIDO, NVL(AH_CTA_VISTAS.FEC_ULT_EXTRACTO,AH_CTA_VISTAS.FEC_APERTURA-1) FEC_ULT_EXTRACTO,
             DECODE(GE_DIR_ENVIOS.NRO_CUENTA, NULL, 'N', 'S') SEPARADO,
             AH_CTA_VISTAS.ROWID REGISTRO, ah_cta_vistas.cta_combinada, ah_cta_vistas.tas_personalizada, ah_cta_vistas.cod_tasa,
             AH_CTA_VISTAS.SAL_BLOQUEADO, NVL(GE_PAQ_CUENTAS.COD_PAQUETE,0) COD_PAQUETE
        FROM GE_DIR_ENVIOS, AH_CTA_VISTAS, GE_CTA_CLIENTES, GE_PAQ_CUENTAS
       WHERE GE_DIR_ENVIOS.COD_PERSONA (+) = GE_CTA_CLIENTES.COD_PERSONA
         AND GE_DIR_ENVIOS.NRO_CUENTA (+)  = GE_CTA_CLIENTES.NRO_CUENTA
         AND GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
         and ge_cta_clientes.nro_cuenta = nvl(v_nro_cta_parametro, ge_cta_clientes.nro_cuenta) --si es x cuenta
         AND GE_CTA_CLIENTES.RELACION = 'P'
         AND AH_CTA_VISTAS.COD_MODULO = GE_CTA_CLIENTES.COD_MODULO
         AND AH_CTA_VISTAS.COD_MODALIDAD = GE_CTA_CLIENTES.COD_MODALIDAD
         AND AH_CTA_VISTAS.COD_OFICINA = GE_CTA_CLIENTES.COD_OFICINA
         AND AH_CTA_VISTAS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
         AND ((AH_CTA_VISTAS.ESTADO NOT IN ('C','P')) OR
              (AH_CTA_VISTAS.ESTADO IN ('C','P') AND
               AH_CTA_VISTAS.FEC_ULT_MOVIMIENTO >=  v_pri_dia_mes_habil AND
               AH_CTA_VISTAS.FEC_ULT_MOVIMIENTO > NVL(AH_CTA_VISTAS.FEC_ULT_EXTRACTO,AH_CTA_VISTAS.FEC_APERTURA-1)))
         AND GE_PAQ_CUENTAS.NRO_CUENTA(+) = GE_CTA_CLIENTES.NRO_CUENTA
         AND GE_PAQ_CUENTAS.COD_PERSONA(+) = GE_CTA_CLIENTES.COD_PERSONA
       ORDER BY GE_PAQ_CUENTAS.COD_MODULO, GE_PAQ_CUENTAS.COD_MODALIDAD, GE_PAQ_CUENTAS.COD_SUB_MODALIDAD, GE_PAQ_CUENTAS.NRO_CUENTA;

v_SAL_ACUMULADO cc_sal_mensuales.sal_acu_deudor%type;
v_SAL_PROMEDIO  cc_sal_mensuales.sal_acu_deudor%type;
v_CAN_DIA_ACUMULADO cc_sal_mensuales.can_dia_acumulado%type;
v_nro_cta_combinada cc_cta_combinadas.nro_cta_ahorro%type;
v_val_tasa ge_tas_fechas.val_tasa%type;
v_val_tae  ge_tas_fechas.val_tasa%type;
      BEGIN
        v_lugar := 'lp_generar_vistas';
        FOR AV IN MAE_CUE LOOP
          --limpio variables
          v_SAL_PROMEDIO := null;
          v_nro_cta_combinada := null;
          v_val_tasa := null;
          v_val_tae  := null;
          --- asigno el codigo de extracto unico -----------------
          v_nro_cuenta   := av.nro_cuenta;
          v_sal_ult_extracto := nvl(AV.SAL_ULT_EXTRACTO,0);
          v_TIENE_MOV := 'N';
          v_CANTIDAD  := 0;
          v_mto_bloqueo := lf_obt_mto_bloqueado(av.nro_cuenta);
          --- la suma de todos los movimientos del historico -----
          SELECT 0,0,
                 COUNT('X')
            INTO v_mto_debito, v_mto_credito, v_cantidad
            FROM GE_TRANSACCIONES, AH_MOVIMIENTOS_HIS
            WHERE AH_MOVIMIENTOS_HIS.COD_MODULO = AV.COD_MODULO
              AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = AV.COD_MODALIDAD
              AND AH_MOVIMIENTOS_HIS.COD_OFICINA = AV.COD_OFICINA
              AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = AV.NRO_CUENTA
              AND AH_MOVIMIENTOS_HIS.FECHA > AV.FEC_ULT_EXTRACTO
              AND AH_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
              AND(AH_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
                 (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
                  FEC_VALOR <= AV.FEC_ULT_EXTRACTO   AND
                  EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                           WHERE AH_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
                             AND AH_MOVIMIENTOS_HIS.HOR_REVERSION  = REV.HORA
                             AND AH_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
                             AND AH_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                             -- DYDMR-5672 NAF 01/2017
                             AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
                             AND abs(AH_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO)
                          )) OR
                  (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND AH_MOVIMIENTOS_HIS.COD_TRA_PADRE in (303,302)
                   AND AH_MOVIMIENTOS_HIS.Cod_Mad_Padre = 455))
              AND AH_MOVIMIENTOS_HIS.ESTADO = 'N'
              AND AH_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
              AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
              AND AH_MOVIMIENTOS_HIS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
              AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
              and NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
              AND AH_MOVIMIENTOS_HIS.NRO_FOLIO IS NULL
              AND GE_TRANSACCIONES.TIPO IN ('C','D');
          if v_est_modulo = 2 then
            SELECT 0,0,
                 COUNT('X')
              INTO v_mto_debito1, v_mto_credito1, v_cantidad1
              FROM GE_TRANSACCIONES, GE_MOVIMIENTOS
              WHERE GE_MOVIMIENTOS.COD_MODULO = AV.COD_MODULO
                AND GE_MOVIMIENTOS.COD_MODALIDAD = AV.COD_MODALIDAD
                AND GE_MOVIMIENTOS.COD_OFICINA = AV.COD_OFICINA
                AND GE_MOVIMIENTOS.NRO_CUENTA = AV.NRO_CUENTA
                AND GE_MOVIMIENTOS.FECHA > AV.FEC_ULT_EXTRACTO
                AND GE_MOVIMIENTOS.FECHA <= v_fec_actual
                AND(GE_MOVIMIENTOS.REVERSADO = 'N' OR
                     (GE_MOVIMIENTOS.REVERSADO = 'S' AND
                      FEC_VALOR <= AV.FEC_ULT_EXTRACTO AND
                      EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                               WHERE GE_MOVIMIENTOS.FEC_VALOR = REV.FECHA
                                 AND GE_MOVIMIENTOS.HOR_REVERSION  = REV.HORA
                                 AND GE_MOVIMIENTOS.COD_USU_REVERSION = REV.COD_USUARIO
                                 AND GE_MOVIMIENTOS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                 -- DYDMR-5672 NAF 01/2017
                                 AND GE_MOVIMIENTOS.NRO_CUENTA = REV.NRO_CUENTA
                                 AND abs(GE_MOVIMIENTOS.MONTO) = abs(REV.MONTO)
                              )) OR
                     (GE_MOVIMIENTOS.REVERSADO = 'S' AND GE_MOVIMIENTOS.COD_TRA_PADRE in (303,302)
                      AND GE_MOVIMIENTOS.Cod_Mad_Padre = 455))
                AND GE_MOVIMIENTOS.ESTADO = 'N'
                AND GE_MOVIMIENTOS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                AND GE_MOVIMIENTOS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                AND GE_MOVIMIENTOS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                AND GE_TRANSACCIONES.TIPO IN ('C','D')--;
                and NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
                --q no est? pendiente
                and not exists (SELECT 0
                                  FROM AH_RETENCIONES
                                 WHERE AH_RETENCIONES.NRO_CUENTA = av.nro_cuenta
                                   AND AH_RETENCIONES.COD_retencion = ge_movimientos.cod_retencion
                                   and ah_retenciones.nro_documento = ge_movimientos.nro_documento
                                   and ah_retenciones.fec_final = ge_movimientos.fec_fin_retencion
                                   AND AH_RETENCIONES.LIBERADO  = 'N')
                and not exists (select 1 from GE_EXT_CLI_MOVIMIENTOS_TMP w
                                   where w.nro_cuenta= GE_MOVIMIENTOS.nro_cuenta
                                   and  w.nro_documento= GE_MOVIMIENTOS.nro_documento
                                   and  w.fec_valor= GE_MOVIMIENTOS.fec_valor
                                   and  w.fec_movimiento= GE_MOVIMIENTOS.fecha
                                   );
          END IF;
          V_CANTIDAD := NVL(V_CANTIDAD, 0) + NVL(v_CANTIDAD1, 0);
          v_mto_credito := NVL(V_MTO_CREDITO, 0) + NVL(V_MTO_CREDITO1,0);
          V_MTO_DEBITO := NVL(V_MTO_DEBITO, 0) + NVL(V_MTO_DEBITO1,0);
          IF V_CANTIDAD > 0 THEN
             V_TIENE_MOV := 'S';
          END IF;
            V_EXISTE := 'N';
            IF AV.SEPARADO = 'S'  OR AV.COD_PAQUETE > 0 THEN
               -- es una direccion especifica, no enviar en ext.unico --
               v_cod_extracto := v_cod_extracto + 1;
               ---------------------------------------------------------
            ELSE
               --- verifico si ya existe una cabecera del extracto unico
               BEGIN
                 SELECT 'S' INTO V_EXISTE
                   FROM GE_EXT_CLIENTES_TMP
                  WHERE GE_EXT_CLIENTES_TMP.COD_PERSONA = v_cod_persona
                    AND GE_EXT_CLIENTES_TMP.COD_EXTRACTO = v_cod_extracto
                    AND GE_EXT_CLIENTES_TMP.FEC_EXTRACTO = v_fec_actual;
                 V_EXISTE := 'S';
               EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                   V_EXISTE := 'N';
                 WHEN TOO_MANY_ROWS THEN
                   V_EXISTE := 'S';
                 WHEN OTHERS THEN
                   dbms_output.put_line('ERROR al Buscar el Extr.del Cliente.CONTINUO.'||sqlerrm);
                   V_EXISTE := 'N';
               END;
            END IF;
            IF V_EXISTE = 'N' THEN
               -- busco los datos del cliente ---------------------------
               LP_OBTENER_DATOS_DEL_CLIENTE;
               lp_dir_envio;

               INSERT INTO GE_EXT_CLIENTES_TMP (COD_PERSONA, FEC_EXTRACTO, FRE_EXTRACTO,
                                    FUNCIONARIO, NOM_CLIENTE, DIRECCION,
                                    TELEFONO, COD_USU_OFICIAL, COD_PAIS,
                                    COD_CIUDAD, TEL_OFICIAL, NRO_INTERNO,
                                    COD_EXTRACTO, DET_DIRECCION, OBSERVACION,
                                    BARRIO, COD_MENSAJE, tip_impresion,
                                    CLI_CONFIDENCIAL, COD_OFICINA,
                                    cat_riesgo,Fec_Ult_Clasif )
                            VALUES (v_cod_persona, v_fec_actual,
                                    v_fre_extracto,v_es_empleado,
                                    v_nom_cliente, v_dir_cliente,
                                    v_tel_cliente, v_cod_usu_oficial,
                                    v_cod_pais, v_cod_ciudad,
                                    v_tel_oficial, v_int_oficial,v_cod_extracto,
                                    v_pri_obs_dir, v_seg_obs_dir,
                                    v_des_barrio, '1', v_imprime_extracto,
                                    v_cli_confidencial, decode(AV.SEPARADO,'S',av.cod_oficina,v_cod_ofi_cliente),
                                    v_cat_riesgo, v_fec_ult_clasif);
               v_INSERTA := 'S';
            END IF;
            ----------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
            ----------------------------------------------------
            --busca la cuenta combinada si corresponde
            if av.cta_combinada ='S' then
               begin
                  select nro_cta_cte
                    into v_nro_cta_combinada
                    from cc_cta_combinadas
                   where nro_cta_ahorro = av.nro_cuenta;
               exception
                  when no_data_found then
                     null;
                  when others then
                     null;
               end;
            end if;
             --obtiene saldo promedio
             pag_cta.PR_OBT_SAL_PROMEDIO(av.COD_MODULO,av.COD_MODALIDAD,av.COD_OFICINA,
                      av.NRO_CUENTA,v_fec_actual,v_fec_actual, v_SAL_ACUMULADO, v_SAL_PROMEDIO,v_CAN_DIA_ACUMULADO);
            --- cargo los valores para el calculo de la tasa --
            v_val_tasa := fug_obt_val_tasa(av.cod_modulo, av.cod_modalidad, av.cod_oficina, av.nro_cuenta, av.cod_moneda, v_SAL_PROMEDIO, av.tas_personalizada,
                          av.cod_tasa, null, v_fec_actual);
            --obtiene tae
            v_val_tae := pas_bcp.FU_OBT_TAE(v_val_tasa,30);
            v_sal_blo_anterior := lf_obt_sal_blo_anterior(av.NRO_CUENTA,av.fec_ult_extracto);

            INSERT INTO GE_EXT_CLI_CUENTAS_TMP (GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA, GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO, GE_EXT_CLI_CUENTAS_TMP.TIP_CUENTA,
                                 GE_EXT_CLI_CUENTAS_TMP.COD_OFICINA, GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD, GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA,
                                 GE_EXT_CLI_CUENTAS_TMP.COD_MONEDA, GE_EXT_CLI_CUENTAS_TMP.SAL_ANTERIOR, GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL,
                                 GE_EXT_CLI_CUENTAS_TMP.NRO_FOLIO, GE_EXT_CLI_CUENTAS_TMP.SAL_A_CONFIRMAR, GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO,
                                 GE_EXT_CLI_CUENTAS_TMP.FRE_EXTRACTO, Sal_Promedio, Nro_Cta_Combinada, Tas_Nominal, Tas_Efectiva,
                                 cod_modulo, SAL_BLOQUEADO, SAL_BLO_ANTERIOR)
                         VALUES (v_cod_persona,  v_fec_actual, 'A',
                                 AV.COD_OFICINA,AV.COD_MODALIDAD,AV.NRO_CUENTA,
                                 AV.COD_MONEDA, v_sal_ult_extracto,
                                 NVL(v_sal_ult_extracto,0)  + NVL(v_mto_credito,0) -
                                                     NVL(v_mto_debito,0),
                                 AV.NRO_FOLIO, AV.SAL_RETENIDO, v_cod_extracto,
                                 v_fre_extracto, v_sal_promedio, v_nro_cta_combinada, v_val_tasa, v_val_tae,
                                 av.cod_modulo, v_mto_bloqueo, v_sal_blo_anterior);
            
               --------------------------------------------
               -- INSERTA REGISTRO EN EL ARCHIVO DETALLE --
               --------------------------------------------
            IF V_TIENE_MOV = 'S' THEN
               INSERT INTO GE_EXT_CLI_MOVIMIENTOS_TMP (COD_PERSONA, FEC_EXTRACTO, FEC_MOVIMIENTO,
                                    FEC_VALOR, HOR_MOVIMIENTO, NRO_CUENTA,
                                    NRO_DOCUMENTO, COD_MODULO, COD_MODALIDAD,
                                    COD_TRA_PADRE, MTO_DEBITO, MTO_CREDITO,
                                    COD_EXTRACTO, FRE_EXTRACTO, NRO_SECUENCIA, cod_ofi_origen, fec_insercion)
               SELECT  v_cod_persona, v_fec_actual,
                       AH_MOVIMIENTOS_HIS.FECHA, AH_MOVIMIENTOS_HIS.FEC_VALOR, AH_MOVIMIENTOS_HIS.HORA, AH_MOVIMIENTOS_HIS.NRO_CUENTA,
                       AH_MOVIMIENTOS_HIS.NRO_DOCUMENTO, AH_MOVIMIENTOS_HIS.COD_MOD_PADRE, AH_MOVIMIENTOS_HIS.COD_MAD_PADRE, AH_MOVIMIENTOS_HIS.COD_TRA_PADRE,
                       DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'D',
                           NVL(AH_MOVIMIENTOS_HIS.MONTO,0),
                           0),
                           DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'C',
                           NVL(AH_MOVIMIENTOS_HIS.MONTO,0),
                           0),
                       v_cod_extracto, v_fre_extracto, AH_MOVIMIENTOS_HIS.NRO_SECUENCIA, ah_movimientos_his.cod_ofi_origen, ah_movimientos_his.fec_insercion
                 FROM GE_TRANSACCIONES, AH_MOVIMIENTOS_HIS
               WHERE AH_MOVIMIENTOS_HIS.COD_MODULO = AV.COD_MODULO
                 AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = AV.COD_MODALIDAD
                 AND AH_MOVIMIENTOS_HIS.COD_OFICINA = AV.COD_OFICINA
                 AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = AV.NRO_CUENTA
                 AND AH_MOVIMIENTOS_HIS.FECHA > AV.FEC_ULT_EXTRACTO
                 AND AH_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
                 AND(AH_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
                    (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
                     FEC_VALOR <= AV.FEC_ULT_EXTRACTO   AND
                     EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                              WHERE AH_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
                                AND AH_MOVIMIENTOS_HIS.HOR_REVERSION  = REV.HORA
                                AND AH_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
                                AND AH_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                -- DYDMR-5672 NAF 01/2017
                                AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
                                AND abs(AH_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO)
                             )) OR
                   (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND AH_MOVIMIENTOS_HIS.COD_TRA_PADRE in (303,302)
                    AND AH_MOVIMIENTOS_HIS.Cod_Mad_Padre = 455))
                 AND AH_MOVIMIENTOS_HIS.ESTADO = 'N'
                 AND AH_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                 AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                 AND AH_MOVIMIENTOS_HIS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                 AND AH_MOVIMIENTOS_HIS.NRO_FOLIO IS NULL
                 AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                 AND NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
                 AND GE_TRANSACCIONES.TIPO IN ('C','D');
               -- Inserta los movimientos del d?a
               if v_est_modulo = 2 then
                 INSERT INTO GE_EXT_CLI_MOVIMIENTOS_TMP (COD_PERSONA, FEC_EXTRACTO, FEC_MOVIMIENTO,
                                      FEC_VALOR, HOR_MOVIMIENTO, NRO_CUENTA,
                                      NRO_DOCUMENTO, COD_MODULO, COD_MODALIDAD,
                                      COD_TRA_PADRE, MTO_DEBITO, MTO_CREDITO,
                                      COD_EXTRACTO, FRE_EXTRACTO, NRO_SECUENCIA, cod_ofi_origen, Fec_Insercion)
                 SELECT  v_cod_persona, v_fec_actual,
                         GE_MOVIMIENTOS.FECHA, GE_MOVIMIENTOS.FEC_VALOR, GE_MOVIMIENTOS.HORA, GE_MOVIMIENTOS.NRO_CUENTA,
                         GE_MOVIMIENTOS.NRO_DOCUMENTO, GE_MOVIMIENTOS.COD_MOD_PADRE, GE_MOVIMIENTOS.COD_MAD_PADRE, GE_MOVIMIENTOS.COD_TRA_PADRE,
                         DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'D',
                           NVL(GE_MOVIMIENTOS.MONTO,0),
                           0),
                           DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'C',
                           NVL(GE_MOVIMIENTOS.MONTO,0),
                           0),
                         v_cod_extracto, v_fre_extracto, GE_MOVIMIENTOS.NRO_SECUENCIA, ge_movimientos.cod_ofi_origen, ge_movimientos.fec_insercion
                   FROM GE_TRANSACCIONES, GE_MOVIMIENTOS
                 WHERE GE_MOVIMIENTOS.COD_MODULO = AV.COD_MODULO
                   AND GE_MOVIMIENTOS.COD_MODALIDAD = AV.COD_MODALIDAD
                   AND GE_MOVIMIENTOS.COD_OFICINA = AV.COD_OFICINA
                   AND GE_MOVIMIENTOS.NRO_CUENTA = AV.NRO_CUENTA
--    Ya no tiene en cuenta las fechas porque se supone son movimientos que no han pasado al historico
                   AND GE_MOVIMIENTOS.FECHA <= v_fec_actual
                   AND(GE_MOVIMIENTOS.REVERSADO = 'N' OR
                      (GE_MOVIMIENTOS.REVERSADO = 'S' AND
                       FEC_VALOR <= AV.FEC_ULT_EXTRACTO AND
                       EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                                WHERE GE_MOVIMIENTOS.FEC_VALOR = REV.FECHA
                                  AND GE_MOVIMIENTOS.HOR_REVERSION  = REV.HORA
                                  AND GE_MOVIMIENTOS.COD_USU_REVERSION = REV.COD_USUARIO
                                  AND GE_MOVIMIENTOS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                  -- DYDMR-5672 NAF 01/2017
                                  AND GE_MOVIMIENTOS.NRO_CUENTA = REV.NRO_CUENTA
                                  AND abs(GE_MOVIMIENTOS.MONTO) = abs(REV.MONTO)
                               )) OR
                     (GE_MOVIMIENTOS.REVERSADO = 'S' AND GE_MOVIMIENTOS.COD_TRA_PADRE in (303,302)
                      AND GE_MOVIMIENTOS.Cod_Mad_Padre = 455))
                   AND GE_MOVIMIENTOS.ESTADO = 'N'
                   AND GE_MOVIMIENTOS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                   AND GE_MOVIMIENTOS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                   AND GE_MOVIMIENTOS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                   AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                   AND GE_TRANSACCIONES.TIPO IN ('C','D')
                   AND NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
                   --q no est? pendiente
                   and not exists (SELECT 0
                                     FROM AH_RETENCIONES
                                    WHERE AH_RETENCIONES.NRO_CUENTA = av.nro_cuenta
                                      AND AH_RETENCIONES.COD_retencion = ge_movimientos.cod_retencion
                                      and ah_retenciones.nro_documento = ge_movimientos.nro_documento
                                      and ah_retenciones.fec_final = ge_movimientos.fec_fin_retencion
                                      AND AH_RETENCIONES.LIBERADO  = 'N')
                   and not exists (select 1 from GE_EXT_CLI_MOVIMIENTOS_TMP w
                                   where w.nro_cuenta= GE_MOVIMIENTOS.nro_cuenta
                                   and  w.nro_documento= GE_MOVIMIENTOS.nro_documento
                                   and  w.fec_valor= GE_MOVIMIENTOS.fec_valor
                                   and  w.fec_movimiento= GE_MOVIMIENTOS.fecha
                                   );
               END IF;
            END IF;
            --para movimientos_noc
            INSERT INTO GE_EXT_CLI_MOVIMIENTOS_TMP (COD_PERSONA, FEC_EXTRACTO, FEC_MOVIMIENTO,
                                      FEC_VALOR, HOR_MOVIMIENTO, NRO_CUENTA,
                                      NRO_DOCUMENTO, COD_MODULO, COD_MODALIDAD,
                                      COD_TRA_PADRE, MTO_DEBITO, MTO_CREDITO,
                                      COD_EXTRACTO, FRE_EXTRACTO, NRO_SECUENCIA, cod_ofi_origen, Fec_Insercion)
                 SELECT  v_cod_persona, v_fec_actual,
                         GE_MOVIMIENTOS_NOC.FECHA, GE_MOVIMIENTOS_NOC.FEC_VALOR, GE_MOVIMIENTOS_NOC.HORA, GE_MOVIMIENTOS_NOC.NRO_CUENTA,
                         GE_MOVIMIENTOS_NOC.NRO_DOCUMENTO, GE_MOVIMIENTOS_NOC.COD_MOD_PADRE, GE_MOVIMIENTOS_NOC.COD_MAD_PADRE, GE_MOVIMIENTOS_NOC.COD_TRA_PADRE,
                         DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'D',
                           NVL(GE_MOVIMIENTOS_NOC.MONTO,0),
                           0),
                           DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'C',
                           NVL(GE_MOVIMIENTOS_NOC.MONTO,0),
                           0),
                         v_cod_extracto, v_fre_extracto, GE_MOVIMIENTOS_NOC.NRO_SECUENCIA, GE_MOVIMIENTOS_NOC.cod_ofi_origen, GE_MOVIMIENTOS_NOC.fec_insercion
                   FROM GE_TRANSACCIONES, GE_MOVIMIENTOS_NOC
                 WHERE GE_MOVIMIENTOS_NOC.COD_MODULO = AV.COD_MODULO
                   AND GE_MOVIMIENTOS_NOC.COD_MODALIDAD = AV.COD_MODALIDAD
                   AND GE_MOVIMIENTOS_NOC.COD_OFICINA = AV.COD_OFICINA
                   AND GE_MOVIMIENTOS_NOC.NRO_CUENTA = AV.NRO_CUENTA
                   --Tomamos la fecha de inserción para que cuadre
                   AND TRUNC(GE_MOVIMIENTOS_NOC.FEC_INSERCION) <= v_fec_actual
                   AND(GE_MOVIMIENTOS_NOC.REVERSADO = 'N' OR
                      (GE_MOVIMIENTOS_NOC.REVERSADO = 'S' AND
                       FEC_VALOR <= AV.FEC_ULT_EXTRACTO AND
                       EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                                WHERE GE_MOVIMIENTOS_NOC.FEC_VALOR = REV.FECHA
                                  AND GE_MOVIMIENTOS_NOC.HOR_REVERSION  = REV.HORA
                                  AND GE_MOVIMIENTOS_NOC.COD_USU_REVERSION = REV.COD_USUARIO
                                  AND GE_MOVIMIENTOS_NOC.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                  -- DYDMR-5672 NAF 01/2017
                                  AND GE_MOVIMIENTOS_NOC.NRO_CUENTA = REV.NRO_CUENTA
                                  AND abs(GE_MOVIMIENTOS_NOC.MONTO) = abs(REV.MONTO)
                               )) OR
                     (GE_MOVIMIENTOS_NOC.REVERSADO = 'S' AND GE_MOVIMIENTOS_NOC.COD_TRA_PADRE in (303,302)
                      AND GE_MOVIMIENTOS_NOC.Cod_Mad_Padre = 455))
                   AND GE_MOVIMIENTOS_NOC.ESTADO = 'N'
                   AND GE_MOVIMIENTOS_NOC.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                   AND GE_MOVIMIENTOS_NOC.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                   AND GE_MOVIMIENTOS_NOC.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                   AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                   AND GE_TRANSACCIONES.TIPO IN ('C','D')
                   AND NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
                   --q no est? pendiente
                   and not exists (SELECT 0
                                     FROM AH_RETENCIONES
                                    WHERE AH_RETENCIONES.NRO_CUENTA = av.nro_cuenta
                                      AND AH_RETENCIONES.COD_retencion = GE_MOVIMIENTOS_NOC.cod_retencion
                                      and ah_retenciones.nro_documento = GE_MOVIMIENTOS_NOC.nro_documento
                                      and ah_retenciones.fec_final = GE_MOVIMIENTOS_NOC.fec_fin_retencion
                                      AND AH_RETENCIONES.LIBERADO  = 'N')
                   and not exists (select 1 from GE_EXT_CLI_MOVIMIENTOS_TMP w
                                   where w.nro_cuenta= GE_MOVIMIENTOS_NOC.nro_cuenta
                                   and  w.nro_documento= GE_MOVIMIENTOS_NOC.nro_documento
                                   and  w.fec_valor= GE_MOVIMIENTOS_NOC.fec_valor
                                   and  w.fec_movimiento= GE_MOVIMIENTOS_NOC.fecha
                                   );
         END LOOP;
   end lp_generar_vistas;
   --
    procedure lp_generar_programados is
     /** incluye ahorro programado en el extracto **/
      v_sal_ult_extracto NUMBER(18,2) default 0;
      v_mto_debito NUMBER(18,2);
      v_mto_credito NUMBER(18,2);
      v_CANTIDAD  NUMBER(06) := 0;

      v_mto_debito1 NUMBER(18,2);
      v_mto_credito1 NUMBER(18,2);
      v_CANTIDAD1  NUMBER(06) := 0;

      v_EXISTE  VARCHAR2(01) := 'N';
      v_TIENE_MOV VARCHAR2(01) := 'N';
      v_imprime_extracto varchar2(1);
      ----------------------------------
      -- CURSOR DEL ARCHIVO PRINCIPAL --
      ----------------------------------
      CURSOR MAE_CUE IS
        select ge_cta_clientes.cod_modulo, ge_cta_clientes.cod_modalidad, ge_cta_clientes.cod_oficina, ge_cta_clientes.nro_cuenta,
               ah_cta_plazos.cod_moneda, nvl(ah_cta_plazos.sal_ult_extracto,ah_cta_plazos.sal_tot_batch) sal_ult_extracto , nvl(ah_cta_plazos.nro_folio, 0) nro_folio, ah_cta_plazos.denominacion,
               ah_cta_plazos.sal_retenido, nvl(ah_cta_plazos.fec_ult_extracto,ah_cta_plazos.fec_apertura-1) fec_ult_extracto,
               decode(ge_dir_envios.nro_cuenta, null, 'N', 'S') separado,
               ah_cta_plazos.rowid registro, null, ah_cta_plazos.tas_personalizada, ah_cta_plazos.val_tasa,
               ah_cta_plazos.sal_bloqueado, nvl(ge_paq_cuentas.cod_paquete,0) cod_paquete
          from ge_dir_envios, ah_cta_plazos, ge_cta_clientes, ge_paq_cuentas
         where ge_dir_envios.cod_persona (+) = ge_cta_clientes.cod_persona
           and ge_dir_envios.nro_cuenta (+)  = ge_cta_clientes.nro_cuenta
           and ge_cta_clientes.cod_persona = v_cod_persona
           and ge_cta_clientes.nro_cuenta = nvl(v_nro_cta_parametro, ge_cta_clientes.nro_cuenta)
           and ge_cta_clientes.relacion = 'P'
           and ah_cta_plazos.cod_modulo = ge_cta_clientes.cod_modulo
           and ah_cta_plazos.cod_modalidad = ge_cta_clientes.cod_modalidad
           and ah_cta_plazos.cod_oficina = ge_cta_clientes.cod_oficina
           and ah_cta_plazos.nro_cuenta = ge_cta_clientes.nro_cuenta
           and ((ah_cta_plazos.estado not in ('C','P', 'T')) or
                (ah_cta_plazos.estado in ('C','P', 'T') and
                 ah_cta_plazos.fec_ult_movimiento >=  v_pri_dia_mes_habil and
                 ah_cta_plazos.fec_ult_movimiento > nvl(ah_cta_plazos.fec_ult_extracto,ah_cta_plazos.fec_apertura-1)))
           and ge_paq_cuentas.nro_cuenta(+) = ge_cta_clientes.nro_cuenta
           and ge_paq_cuentas.cod_persona(+) = ge_cta_clientes.cod_persona
         order by ge_paq_cuentas.cod_modulo, ge_paq_cuentas.cod_modalidad, ge_paq_cuentas.cod_sub_modalidad, ge_paq_cuentas.nro_cuenta;

      v_SAL_ACUMULADO cc_sal_mensuales.sal_acu_deudor%type;
      v_SAL_PROMEDIO  cc_sal_mensuales.sal_acu_deudor%type;
      v_CAN_DIA_ACUMULADO cc_sal_mensuales.can_dia_acumulado%type;
      v_val_tasa ge_tas_fechas.val_tasa%type;
      v_val_tae  ge_tas_fechas.val_tasa%type;
      BEGIN
        v_lugar := 'lp_generar_programados';
        FOR AP IN MAE_CUE LOOP
          --limpio variables
          v_SAL_PROMEDIO := null;
          v_val_tasa := null;
          v_val_tae  := null;
          --- asigno el codigo de extracto unico -----------------
          v_nro_cuenta   := ap.nro_cuenta;
          v_sal_ult_extracto := nvl(ap.SAL_ULT_EXTRACTO,0);
          v_TIENE_MOV := 'N';
          v_CANTIDAD  := 0;
          v_mto_bloqueo := lf_obt_mto_bloqueado(ap.nro_cuenta);

          --- la suma de todos los movimientos del historico -----
          SELECT SUM(DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'D',
                          NVL(AH_MOVIMIENTOS_HIS.MONTO,0),
                          0)
                          ),
                 SUM(DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'C',
                           NVL(AH_MOVIMIENTOS_HIS.MONTO,0),
                           0)
                           ),
                 COUNT('X')
            INTO v_mto_debito, v_mto_credito, v_cantidad
            FROM GE_TRANSACCIONES, AH_MOVIMIENTOS_HIS
            WHERE AH_MOVIMIENTOS_HIS.COD_MODULO = ap.COD_MODULO
              AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = ap.COD_MODALIDAD
              AND AH_MOVIMIENTOS_HIS.COD_OFICINA = ap.COD_OFICINA
              AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = ap.NRO_CUENTA
              AND AH_MOVIMIENTOS_HIS.FECHA > ap.FEC_ULT_EXTRACTO
              AND AH_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
              AND(AH_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
                 (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
                  FEC_VALOR <= ap.FEC_ULT_EXTRACTO   AND
                  EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV
                           WHERE AH_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
                             AND AH_MOVIMIENTOS_HIS.HOR_REVERSION  = REV.HORA
                             AND AH_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
                             AND AH_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                             AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
                             AND abs(AH_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO)
                          )) OR
                  (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND AH_MOVIMIENTOS_HIS.COD_TRA_PADRE in (301)
                   AND AH_MOVIMIENTOS_HIS.Cod_Mad_Padre = 38))
              AND AH_MOVIMIENTOS_HIS.ESTADO = 'N'
              AND AH_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
              AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
              AND AH_MOVIMIENTOS_HIS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
              AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
              and NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
              AND AH_MOVIMIENTOS_HIS.NRO_FOLIO IS NULL
              AND GE_TRANSACCIONES.TIPO IN ('C','D');
          if v_est_modulo = 2 then
            SELECT SUM(DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'D',
                          NVL(GE_MOVIMIENTOS.MONTO,0),
                          0)
                          ),
                 SUM(DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'C',
                           NVL(GE_MOVIMIENTOS.MONTO,0),
                           0)
                           ),
                 COUNT('X')
              INTO v_mto_debito1, v_mto_credito1, v_cantidad1
              FROM GE_TRANSACCIONES, GE_MOVIMIENTOS
              WHERE GE_MOVIMIENTOS.COD_MODULO = ap.COD_MODULO
                AND GE_MOVIMIENTOS.COD_MODALIDAD = ap.COD_MODALIDAD
                AND GE_MOVIMIENTOS.COD_OFICINA = ap.COD_OFICINA
                AND GE_MOVIMIENTOS.NRO_CUENTA = ap.NRO_CUENTA
                AND GE_MOVIMIENTOS.FECHA > ap.FEC_ULT_EXTRACTO
                AND GE_MOVIMIENTOS.FECHA <= v_fec_actual
                AND(GE_MOVIMIENTOS.REVERSADO = 'N' OR
                     (GE_MOVIMIENTOS.REVERSADO = 'S' AND
                      FEC_VALOR <= ap.FEC_ULT_EXTRACTO AND
                      EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV
                               WHERE GE_MOVIMIENTOS.FEC_VALOR = REV.FECHA
                                 AND GE_MOVIMIENTOS.HOR_REVERSION  = REV.HORA
                                 AND GE_MOVIMIENTOS.COD_USU_REVERSION = REV.COD_USUARIO
                                 AND GE_MOVIMIENTOS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                 AND GE_MOVIMIENTOS.NRO_CUENTA = REV.NRO_CUENTA
                                 AND abs(GE_MOVIMIENTOS.MONTO) = abs(REV.MONTO)
                              )) OR
                     (GE_MOVIMIENTOS.REVERSADO = 'S' AND GE_MOVIMIENTOS.COD_TRA_PADRE in (301)
                      AND GE_MOVIMIENTOS.Cod_Mad_Padre = 38))
                AND GE_MOVIMIENTOS.ESTADO = 'N'
                AND GE_MOVIMIENTOS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                AND GE_MOVIMIENTOS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                AND GE_MOVIMIENTOS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                AND GE_TRANSACCIONES.TIPO IN ('C','D')
                and NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
                --que no est? pendiente
                and not exists (SELECT 0
                                  FROM AH_RETENCIONES
                                 WHERE AH_RETENCIONES.NRO_CUENTA = ap.nro_cuenta
                                   AND AH_RETENCIONES.COD_retencion = ge_movimientos.cod_retencion
                                   and ah_retenciones.nro_documento = ge_movimientos.nro_documento
                                   and ah_retenciones.fec_final = ge_movimientos.fec_fin_retencion
                                   AND AH_RETENCIONES.LIBERADO  = 'N')
                and not exists (select 1 from GE_EXT_CLI_MOVIMIENTOS_TMP w
                                   where w.nro_cuenta= GE_MOVIMIENTOS.nro_cuenta
                                   and  w.nro_documento= GE_MOVIMIENTOS.nro_documento
                                   and  w.fec_valor= GE_MOVIMIENTOS.fec_valor
                                   and  w.fec_movimiento= GE_MOVIMIENTOS.fecha
                                   );
          END IF;
          V_CANTIDAD := NVL(V_CANTIDAD, 0) + NVL(v_CANTIDAD1, 0);
          v_mto_credito := NVL(V_MTO_CREDITO, 0) + NVL(V_MTO_CREDITO1,0);
          V_MTO_DEBITO := NVL(V_MTO_DEBITO, 0) + NVL(V_MTO_DEBITO1,0);
          IF V_CANTIDAD > 0 THEN
             V_TIENE_MOV := 'S';
          END IF;
            V_EXISTE := 'N';
            IF ap.SEPARADO = 'S'  OR ap.COD_PAQUETE > 0 THEN
               -- es una direccion especifica, no enviar en ext.unico --
               v_cod_extracto := v_cod_extracto + 1;
               ---------------------------------------------------------
            ELSE
               --- verifico si ya existe una cabecera del extracto unico
               BEGIN
                 SELECT 'S' INTO V_EXISTE
                   FROM GE_EXT_CLIENTES_TMP
                  WHERE GE_EXT_CLIENTES_TMP.COD_PERSONA = v_cod_persona
                    AND GE_EXT_CLIENTES_TMP.COD_EXTRACTO = v_cod_extracto
                    AND GE_EXT_CLIENTES_TMP.FEC_EXTRACTO = v_fec_actual;
                 V_EXISTE := 'S';
               EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                   V_EXISTE := 'N';
                 WHEN TOO_MANY_ROWS THEN
                   V_EXISTE := 'S';
                 WHEN OTHERS THEN
                   dbms_output.put_line('ERROR al Buscar el Extr.del Cliente.CONTINUO.'||sqlerrm);
                   V_EXISTE := 'N';
               END;
            END IF;
            IF V_EXISTE = 'N' THEN
               -- busco los datos del cliente ---------------------------
               LP_OBTENER_DATOS_DEL_CLIENTE;
               lp_dir_envio;

               INSERT INTO GE_EXT_CLIENTES_TMP (COD_PERSONA, FEC_EXTRACTO, FRE_EXTRACTO,
                                    FUNCIONARIO, NOM_CLIENTE, DIRECCION,
                                    TELEFONO, COD_USU_OFICIAL, COD_PAIS,
                                    COD_CIUDAD, TEL_OFICIAL, NRO_INTERNO,
                                    COD_EXTRACTO, DET_DIRECCION, OBSERVACION,
                                    BARRIO, COD_MENSAJE, tip_impresion,
                                    CLI_CONFIDENCIAL, COD_OFICINA,
                                    cat_riesgo,Fec_Ult_Clasif )
                            VALUES (v_cod_persona, v_fec_actual,
                                    v_fre_extracto,v_es_empleado,
                                    v_nom_cliente, v_dir_cliente,
                                    v_tel_cliente, v_cod_usu_oficial,
                                    v_cod_pais, v_cod_ciudad,
                                    v_tel_oficial, v_int_oficial,v_cod_extracto,
                                    v_pri_obs_dir, v_seg_obs_dir,
                                    v_des_barrio, '1', v_imprime_extracto,
                                    v_cli_confidencial, decode(ap.SEPARADO,'S',ap.cod_oficina,v_cod_ofi_cliente),
                                    v_cat_riesgo, v_fec_ult_clasif);
               v_INSERTA := 'S';
            END IF;
            ----------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
            ----------------------------------------------------
             --obtiene saldo promedio
             pag_cta.PR_OBT_SAL_PROMEDIO(ap.COD_MODULO,ap.COD_MODALIDAD,ap.COD_OFICINA,
                      ap.NRO_CUENTA,v_fec_actual,v_fec_actual, v_SAL_ACUMULADO, v_SAL_PROMEDIO,v_CAN_DIA_ACUMULADO);
            --- cargo los valores para el calculo de la tasa --
            v_val_tasa := ap.val_tasa;
            --obtiene tae
            v_val_tae := pas_bcp.FU_OBT_TAE(v_val_tasa,30);
            v_sal_blo_anterior := lf_obt_sal_blo_anterior(ap.NRO_CUENTA,ap.fec_ult_extracto);

            INSERT INTO GE_EXT_CLI_CUENTAS_TMP (GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA, GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO, GE_EXT_CLI_CUENTAS_TMP.TIP_CUENTA,
                                 GE_EXT_CLI_CUENTAS_TMP.COD_OFICINA, GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD, GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA,
                                 GE_EXT_CLI_CUENTAS_TMP.COD_MONEDA, GE_EXT_CLI_CUENTAS_TMP.SAL_ANTERIOR, GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL,
                                 GE_EXT_CLI_CUENTAS_TMP.NRO_FOLIO, GE_EXT_CLI_CUENTAS_TMP.SAL_A_CONFIRMAR, GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO,
                                 GE_EXT_CLI_CUENTAS_TMP.FRE_EXTRACTO, Sal_Promedio, Nro_Cta_Combinada, Tas_Nominal, Tas_Efectiva,
                                 cod_modulo, SAL_BLOQUEADO, SAL_BLO_ANTERIOR)
                         VALUES (v_cod_persona,  v_fec_actual, 'A',
                                 ap.COD_OFICINA,ap.COD_MODALIDAD,ap.NRO_CUENTA,
                                 ap.COD_MONEDA, v_sal_ult_extracto,
                                 NVL(v_sal_ult_extracto,0)  + NVL(v_mto_credito,0) -
                                                     NVL(v_mto_debito,0),
                                 ap.NRO_FOLIO, ap.SAL_RETENIDO, v_cod_extracto,
                                 v_fre_extracto, v_sal_promedio, null, v_val_tasa, v_val_tae,
                                 ap.cod_modulo, v_mto_bloqueo, v_sal_blo_anterior);
            
               --------------------------------------------
               -- INSERTA REGISTRO EN EL ARCHIVO DETALLE --
               --------------------------------------------
            IF V_TIENE_MOV = 'S' THEN
               INSERT INTO GE_EXT_CLI_MOVIMIENTOS_TMP (COD_PERSONA, FEC_EXTRACTO, FEC_MOVIMIENTO,
                                    FEC_VALOR, HOR_MOVIMIENTO, NRO_CUENTA,
                                    NRO_DOCUMENTO, COD_MODULO, COD_MODALIDAD,
                                    COD_TRA_PADRE, MTO_DEBITO, MTO_CREDITO,
                                    COD_EXTRACTO, FRE_EXTRACTO, NRO_SECUENCIA, cod_ofi_origen, fec_insercion)
               SELECT  v_cod_persona, v_fec_actual,
                       AH_MOVIMIENTOS_HIS.FECHA, AH_MOVIMIENTOS_HIS.FEC_VALOR, AH_MOVIMIENTOS_HIS.HORA, AH_MOVIMIENTOS_HIS.NRO_CUENTA,
                       AH_MOVIMIENTOS_HIS.NRO_DOCUMENTO, AH_MOVIMIENTOS_HIS.COD_MOD_PADRE, AH_MOVIMIENTOS_HIS.COD_MAD_PADRE, AH_MOVIMIENTOS_HIS.COD_TRA_PADRE,
                       DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'D',
                           NVL(AH_MOVIMIENTOS_HIS.MONTO,0),
                           0),
                           DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'C',
                           NVL(AH_MOVIMIENTOS_HIS.MONTO,0),
                           0),
                       v_cod_extracto, v_fre_extracto, AH_MOVIMIENTOS_HIS.NRO_SECUENCIA, ah_movimientos_his.cod_ofi_origen, ah_movimientos_his.fec_insercion
                 FROM GE_TRANSACCIONES, AH_MOVIMIENTOS_HIS
               WHERE AH_MOVIMIENTOS_HIS.COD_MODULO = ap.COD_MODULO
                 AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = ap.COD_MODALIDAD
                 AND AH_MOVIMIENTOS_HIS.COD_OFICINA = ap.COD_OFICINA
                 AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = ap.NRO_CUENTA
                 AND AH_MOVIMIENTOS_HIS.FECHA > ap.FEC_ULT_EXTRACTO
                 AND AH_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
                 AND(AH_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
                    (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
                     FEC_VALOR <= ap.FEC_ULT_EXTRACTO   AND
                     EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV
                              WHERE AH_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
                                AND AH_MOVIMIENTOS_HIS.HOR_REVERSION  = REV.HORA
                                AND AH_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
                                AND AH_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
                                AND abs(AH_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO)
                             )) OR
                   (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND AH_MOVIMIENTOS_HIS.COD_TRA_PADRE in (301)
                    AND AH_MOVIMIENTOS_HIS.Cod_Mad_Padre = 38))
                 AND AH_MOVIMIENTOS_HIS.ESTADO = 'N'
                 AND AH_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                 AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                 AND AH_MOVIMIENTOS_HIS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                 AND AH_MOVIMIENTOS_HIS.NRO_FOLIO IS NULL
                 AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                 AND NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
                 AND GE_TRANSACCIONES.TIPO IN ('C','D');
               -- Inserta los movimientos del d?a
               if v_est_modulo = 2 then
                 INSERT INTO GE_EXT_CLI_MOVIMIENTOS_TMP (COD_PERSONA, FEC_EXTRACTO, FEC_MOVIMIENTO,
                                      FEC_VALOR, HOR_MOVIMIENTO, NRO_CUENTA,
                                      NRO_DOCUMENTO, COD_MODULO, COD_MODALIDAD,
                                      COD_TRA_PADRE, MTO_DEBITO, MTO_CREDITO,
                                      COD_EXTRACTO, FRE_EXTRACTO, NRO_SECUENCIA, cod_ofi_origen, Fec_Insercion)
                 SELECT  v_cod_persona, v_fec_actual,
                         GE_MOVIMIENTOS.FECHA, GE_MOVIMIENTOS.FEC_VALOR, GE_MOVIMIENTOS.HORA, GE_MOVIMIENTOS.NRO_CUENTA,
                         GE_MOVIMIENTOS.NRO_DOCUMENTO, GE_MOVIMIENTOS.COD_MOD_PADRE, GE_MOVIMIENTOS.COD_MAD_PADRE, GE_MOVIMIENTOS.COD_TRA_PADRE,
                         DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'D',
                           NVL(GE_MOVIMIENTOS.MONTO,0),
                           0),
                           DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'C',
                           NVL(GE_MOVIMIENTOS.MONTO,0),
                           0),
                         v_cod_extracto, v_fre_extracto, GE_MOVIMIENTOS.NRO_SECUENCIA, ge_movimientos.cod_ofi_origen, ge_movimientos.fec_insercion
                   FROM GE_TRANSACCIONES, GE_MOVIMIENTOS
                 WHERE GE_MOVIMIENTOS.COD_MODULO = ap.COD_MODULO
                   AND GE_MOVIMIENTOS.COD_MODALIDAD = ap.COD_MODALIDAD
                   AND GE_MOVIMIENTOS.COD_OFICINA = ap.COD_OFICINA
                   AND GE_MOVIMIENTOS.NRO_CUENTA = ap.NRO_CUENTA
                   /** Ya no tiene en cuenta las fechas porque se supone son
                       movimientos que no han pasado al historico **/
                   AND GE_MOVIMIENTOS.FECHA <= v_fec_actual
                   AND(GE_MOVIMIENTOS.REVERSADO = 'N' OR
                      (GE_MOVIMIENTOS.REVERSADO = 'S' AND
                       FEC_VALOR <= ap.FEC_ULT_EXTRACTO AND
                       EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV
                                WHERE GE_MOVIMIENTOS.FEC_VALOR = REV.FECHA
                                  AND GE_MOVIMIENTOS.HOR_REVERSION  = REV.HORA
                                  AND GE_MOVIMIENTOS.COD_USU_REVERSION = REV.COD_USUARIO
                                  AND GE_MOVIMIENTOS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                  AND GE_MOVIMIENTOS.NRO_CUENTA = REV.NRO_CUENTA
                                  AND abs(GE_MOVIMIENTOS.MONTO) = abs(REV.MONTO)
                               )) OR
                     (GE_MOVIMIENTOS.REVERSADO = 'S' AND GE_MOVIMIENTOS.COD_TRA_PADRE in (301)
                      AND GE_MOVIMIENTOS.Cod_Mad_Padre = 38))
                   AND GE_MOVIMIENTOS.ESTADO = 'N'
                   AND GE_MOVIMIENTOS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                   AND GE_MOVIMIENTOS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                   AND GE_MOVIMIENTOS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                   AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                   AND GE_TRANSACCIONES.TIPO IN ('C','D')
                   AND NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B'
                   --q no est? pendiente
                   and not exists (SELECT 0
                                     FROM AH_RETENCIONES
                                    WHERE AH_RETENCIONES.NRO_CUENTA = ap.nro_cuenta
                                      AND AH_RETENCIONES.COD_retencion = ge_movimientos.cod_retencion
                                      and ah_retenciones.nro_documento = ge_movimientos.nro_documento
                                      and ah_retenciones.fec_final = ge_movimientos.fec_fin_retencion
                                      AND AH_RETENCIONES.LIBERADO  = 'N')
                   and not exists (select 1 from GE_EXT_CLI_MOVIMIENTOS_TMP w
                                   where w.nro_cuenta= GE_MOVIMIENTOS.nro_cuenta
                                   and  w.nro_documento= GE_MOVIMIENTOS.nro_documento
                                   and  w.fec_valor= GE_MOVIMIENTOS.fec_valor
                                   and  w.fec_movimiento= GE_MOVIMIENTOS.fecha
                                   );
               END IF;
            END IF;
         END LOOP;
   end lp_generar_programados;

   procedure lp_generar_certificados is
      ----------------------------------
      -- CURSOR DEL ARCHIVO PRINCIPAL --
      ----------------------------------
      CURSOR MAE_CUE IS
      SELECT GE_CTA_CLIENTES.COD_MODULO, GE_CTA_CLIENTES.COD_MODALIDAD, GE_CTA_CLIENTES.COD_OFICINA, GE_CTA_CLIENTES.NRO_CUENTA,
             AH_CTA_CERTIFICADOS.COD_MONEDA, AH_CTA_CERTIFICADOS.TAS_PERSONALIZADA, AH_CTA_CERTIFICADOS.COD_TASA, AH_CTA_CERTIFICADOS.CAPITAL,
             AH_CTA_CERTIFICADOS.FEC_VENCIMIENTO, AH_CTA_CERTIFICADOS.SAL_RETENIDO,
             AH_CTA_CERTIFICADOS.SAL_TOTAL, AH_CTA_CERTIFICADOS.FEC_APERTURA,
             fue_obt_titulo(AH_CTA_CERTIFICADOS.BENEFICIARIO) DENOMINACION,
             ah_cta_certificados.tip_capitalizacion,
             ah_cta_certificados.est_cer_batch, ah_cta_certificados.sal_bloqueado
        FROM AH_CTA_CERTIFICADOS, GE_CTA_CLIENTES
       WHERE GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
         AND GE_CTA_CLIENTES.COD_MODALIDAD = v_cod_modalidad
         and ge_cta_clientes.nro_cuenta = nvl(v_nro_cta_parametro, ge_cta_clientes.nro_cuenta) --si es x cuenta
         AND GE_CTA_CLIENTES.RELACION = 'P'
         AND AH_CTA_CERTIFICADOS.COD_MODULO = GE_CTA_CLIENTES.COD_MODULO
         AND AH_CTA_CERTIFICADOS.COD_MODALIDAD = GE_CTA_CLIENTES.COD_MODALIDAD
         AND AH_CTA_CERTIFICADOS.COD_OFICINA = GE_CTA_CLIENTES.COD_OFICINA
         AND AH_CTA_CERTIFICADOS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
         AND AH_CTA_CERTIFICADOS.ESTADO NOT IN ('C','T')
         AND NVL(AH_CTA_CERTIFICADOS.SAL_TOTAL,0) > 0;
     v_val_tasa ge_tas_fechas.val_tasa%type;
     v_val_tae  ge_tas_fechas.val_tasa%type;
     v_fec_vencimiento ah_cupones.fec_vencimiento%type;
     v_mto_interes     ah_cupones.mto_interes%Type;

      BEGIN
        FOR CD IN MAE_CUE LOOP
            --limpio variables
            v_mto_interes := null;
            v_fec_vencimiento := null;
            v_val_tasa := null;
            v_val_tae  := null;
            v_mto_bloqueo := lf_obt_mto_bloqueado(cd.nro_cuenta);
            --- cargo los valores para el calculo de la tasa --
            v_val_tasa := fug_obt_val_tasa(cd.cod_modulo, cd.cod_modalidad, cd.cod_oficina, cd.nro_cuenta, cd.cod_moneda, cd.capital, cd.tas_personalizada,
                          cd.cod_tasa, null, v_fec_actual);
            --obtiene tae
            v_val_tae := pas_bcp.FU_OBT_TAE_CDA(cd.tip_capitalizacion,v_val_tasa, cd.fec_vencimiento - cd.fec_apertura, cd.CAPITAL);
            ----------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
            ----------------------------------------------------
            INSERT INTO GE_EXT_CLI_CUENTAS_TMP (GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA, GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO, GE_EXT_CLI_CUENTAS_TMP.TIP_CUENTA,
                                 GE_EXT_CLI_CUENTAS_TMP.COD_OFICINA, GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD, GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA,
                                 GE_EXT_CLI_CUENTAS_TMP.COD_MONEDA, GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL, GE_EXT_CLI_CUENTAS_TMP.SAL_A_CONFIRMAR,
                                 GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO, GE_EXT_CLI_CUENTAS_TMP.FRE_EXTRACTO, Tas_Nominal, tas_efectiva,
                                 cod_modulo,Sal_Bloqueado)
                         VALUES (v_cod_persona, v_fec_actual, 'A',
                                 CD.COD_OFICINA, CD.COD_MODALIDAD,
                                 CD.NRO_CUENTA, CD.COD_MONEDA,
                                 CD.SAL_TOTAL, CD.SAL_RETENIDO, 1,
                                 v_fre_extracto, v_val_tasa, v_val_tae,
                                 cd.cod_modulo, v_mto_bloqueo);
            -------------------------------------------------------
            -- CALCULA interes del sgte cup?n --
            -------------------------------------------------------
            BEGIN
            SELECT A.FEC_VENCIMIENTO, NVL(A.MTO_INTERES,0)
              INTO v_fec_vencimiento, v_mto_interes
              FROM ah_cupones A
             WHERE A.NRO_CUENTA = cd.NRO_CUENTA
               AND A.NRO_CUpon = (SELECT MIN(NRO_CUpon)
                                   FROM ah_cupones B
                                  WHERE B.NRO_CUENTA = A.NRO_CUENTA
                                    AND B.NRO_CUPON > 0
                                    AND B.ESTADO NOT IN ('P'))
               AND A.ESTADO NOT IN ('P');
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  null;
            END;
            ------------------------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO RESUMEN DE AHORRO CERTIFICADO --
            ------------------------------------------------------------------
            INSERT INTO GE_EXT_RESUMENES_TMP (GE_EXT_RESUMENES_TMP.COD_PERSONA, GE_EXT_RESUMENES_TMP.FEC_EXTRACTO, GE_EXT_RESUMENES_TMP.TIPO,
                                 GE_EXT_RESUMENES_TMP.NRO_CUENTA, GE_EXT_RESUMENES_TMP.MTO_CAPITAL, GE_EXT_RESUMENES_TMP.MTO_INTERES,
                                 GE_EXT_RESUMENES_TMP.FEC_VENCIMIENTO, GE_EXT_RESUMENES_TMP.COD_EXTRACTO, GE_EXT_RESUMENES_TMP.FRE_EXTRACTO,
                                 GE_EXT_RESUMENES_TMP.FEC_INICIO, GE_EXT_RESUMENES_TMP.BENEFICIARIO, cod_modalidad, cod_moneda)
                         VALUES (v_cod_persona, v_fec_actual,
                                 DECODE(CD.COD_MODALIDAD,33,'2','6'),
                                 CD.NRO_CUENTA, decode(cd.est_cer_batch,'P',0,CD.CAPITAL),
                                 v_mto_interes, v_FEC_VENCIMIENTO, 1,
                                 v_fre_extracto, CD.FEC_APERTURA, CD.DENOMINACION, cd.cod_modalidad, cd.cod_moneda);
         END LOOP;
    end lp_generar_certificados;
   --
   procedure lp_generar_prestamos is
      v_fec_vencimiento DATE;
      v_sal_capital     NUMBER(16,2);
      ----------------------------------
      -- CURSOR DEL ARCHIVO PRINCIPAL --
      ----------------------------------
      CURSOR MAE_CUE IS
      SELECT GE_CTA_CLIENTES.COD_MODULO, GE_CTA_CLIENTES.COD_MODALIDAD, GE_CTA_CLIENTES.COD_OFICINA, GE_CTA_CLIENTES.NRO_CUENTA, PR_CTA_PRESTAMOS.MTO_CAPITAL TOT_PRESTAMO,
             PR_CTA_PRESTAMOS.COD_MONEDA, NVL(PR_CTA_PRESTAMOS.SAL_CAPITAL,0) + NVL(PR_CTA_PRESTAMOS.SAL_INT_ADELANTADO,0) + nvl(sal_interes,0) saldo_capital
        FROM PR_CTA_PRESTAMOS, GE_CTA_CLIENTES
       WHERE GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
         and ge_cta_clientes.nro_cuenta = nvl(v_nro_cta_parametro, ge_cta_clientes.nro_cuenta) --si es x cuenta
         AND GE_CTA_CLIENTES.RELACION = 'P'
         AND PR_CTA_PRESTAMOS.COD_MODULO = GE_CTA_CLIENTES.COD_MODULO
         AND PR_CTA_PRESTAMOS.COD_MODALIDAD = GE_CTA_CLIENTES.COD_MODALIDAD
         AND PR_CTA_PRESTAMOS.COD_OFICINA = GE_CTA_CLIENTES.COD_OFICINA
         AND PR_CTA_PRESTAMOS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
         AND PR_CTA_PRESTAMOS.ESTADO <> 'N';
        V_INSERTAR VARCHAR2(01);
v_val_tasa ge_tas_fechas.val_tasa%type;
v_val_tae  ge_tas_fechas.val_tasa%type;
      BEGIN
         FOR PR IN MAE_CUE LOOP
            --limpio variables
            v_val_tasa := null;
            v_val_tae  := null;
            -------------------------------------------------------
            -- CALCULA IMPORTE Y VENCIMIENTO DE LA CUOTA A PAGAR --
            -------------------------------------------------------
            v_insertar := 'S';
            BEGIN
            SELECT A.FEC_VENCIMIENTO,
                   NVL(A.SAL_CAPITAL,0) + NVL(A.SAL_INT_DOCUMENTADO,0) +
                               NVL(A.SAL_INTERES,0)
              INTO v_fec_vencimiento, v_sal_capital
              FROM PR_CUOTAS A
             WHERE A.NRO_CUENTA = PR.NRO_CUENTA
               AND A.NRO_CUOTA = (SELECT MIN(NRO_CUOTA)
                                   FROM PR_CUOTAS B
                                  WHERE B.NRO_CUENTA = A.NRO_CUENTA
                                    AND B.NRO_CUOTA > 0
                                    AND B.ESTADO NOT IN ('N'))
               AND A.ESTADO NOT IN ('N');
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  v_insertar := 'N';
            END;
            IF v_insertar = 'S' THEN
            --obtener tasas
            begin
               pas_bcp.PR_OBT_TAS_PRESTAMO(null, pr.nro_cuenta, v_val_tae, v_val_tasa);
            exception
               when others then null;
            end;
            ----------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO CABECERA PASIVO --
            ----------------------------------------------------
            INSERT INTO GE_EXT_CLI_CUENTAS_TMP (GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA, GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO, GE_EXT_CLI_CUENTAS_TMP.TIP_CUENTA,
                                 GE_EXT_CLI_CUENTAS_TMP.COD_OFICINA, GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD, GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA,
                                 GE_EXT_CLI_CUENTAS_TMP.COD_MONEDA, GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL, GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO,
                                 GE_EXT_CLI_CUENTAS_TMP.FRE_EXTRACTO, Tas_Nominal, Tas_Efectiva,
                                 cod_modulo)
                         VALUES (v_cod_persona,  v_fec_actual, 'P',
                                 PR.COD_OFICINA, PR.COD_MODALIDAD, PR.NRO_CUENTA,
                                 PR.COD_MONEDA, PR.saldo_capital, 1,
                                 v_fre_extracto, v_val_tasa, v_val_tae, pr.cod_modulo);
            ---------------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO RESUMEN DE PRESTAMOS --
            ---------------------------------------------------------
            INSERT INTO GE_EXT_RESUMENES_TMP (GE_EXT_RESUMENES_TMP.COD_PERSONA, GE_EXT_RESUMENES_TMP.FEC_EXTRACTO, GE_EXT_RESUMENES_TMP.TIPO,
                                 GE_EXT_RESUMENES_TMP.NRO_CUENTA, GE_EXT_RESUMENES_TMP.MTO_CAPITAL, GE_EXT_RESUMENES_TMP.MTO_INTERES,
                                 GE_EXT_RESUMENES_TMP.FEC_VENCIMIENTO, GE_EXT_RESUMENES_TMP.COD_EXTRACTO, GE_EXT_RESUMENES_TMP.FRE_EXTRACTO,
                                 sal_disponible, cod_modalidad, cod_moneda)
                         VALUES (v_cod_persona, v_fec_actual, '3',
                                 PR.NRO_CUENTA, PR.TOT_PRESTAMO, v_sal_capital,
                                 v_fec_vencimiento, 1, v_fre_extracto, pr.saldo_capital, pr.cod_modalidad, pr.cod_moneda);
            END IF;
         END LOOP;
    end lp_generar_prestamos;
   --
   procedure lp_generar_tarjetas is
      ----------------------------------
      CURSOR MAE_CUE IS
      SELECT GE_CTA_CLIENTES.COD_MODULO,GE_CTA_CLIENTES.COD_MODALIDAD,GE_CTA_CLIENTES.COD_OFICINA,COD_MONEDA,
             NVL(TA_TARJETAS.NRO_TARJETA,TA_TARJETAS.NRO_CUENTA) NRO_TARJETA,
             NVL(TA_CTA_TARJETAS.SAL_ULT_EXTRACTO,0) SAL_ULT_EXTRACTO,
             NVL(TA_CTA_TARJETAS.MTO_PAG_MINIMO,0) MTO_PAG_MINIMO,
             NVL(TA_CTA_TARJETAS.LIN_CREDITO,0) - ( NVL(TA_CTA_TARJETAS.SAL_FACTURAR,0) + NVL(TA_CTA_TARJETAS.SAL_FACTURADO,0)
             + NVL(TA_CTA_TARJETAS.SAL_FINANCIADO,0) + NVL(TA_CTA_TARJETAS.SAL_CUO_PENDIENTES,0)) SAL_DISPONIBLE,
             NVL(TA_CTA_TARJETAS.SAL_FACTURAR,0) + NVL(TA_CTA_TARJETAS.SAL_FACTURADO,0) +
             NVL(TA_CTA_TARJETAS.SAL_FINANCIADO,0) + NVL(TA_CTA_TARJETAS.SAL_CUO_PENDIENTES,0) SALDO,
             TA_CTA_TARJETAS.FEC_VCT_ULT_CIERRE, TA_CTA_TARJETAS.NRO_CUENTA
        FROM TA_CTA_TARJETAS, TA_TARJETAS, GE_CTA_CLIENTES
       WHERE GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
         and ge_cta_clientes.nro_cuenta = nvl(v_nro_cta_parametro, ge_cta_clientes.nro_cuenta) --si es x cuenta
         AND GE_CTA_CLIENTES.RELACION = 'P'
         AND TA_TARJETAS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
         AND TA_TARJETAS.COD_PERSONA = GE_CTA_CLIENTES.COD_PERSONA
         AND TA_TARJETAS.VIGENTE = 'S'
         AND TA_CTA_TARJETAS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
         AND TA_TARJETAS.COD_ESTADO NOT IN ('10')
         and ta_cta_tarjetas.estado <> 'C';
      v_val_tasa ge_tas_fechas.val_tasa%type;
      v_val_tae  ge_tas_fechas.val_tasa%type;
      BEGIN
        FOR TA IN MAE_CUE LOOP
            --limpio variables
            v_val_tasa := null;
            v_val_tae  := null;
            ----------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO CABECERA PASIVO --
            ----------------------------------------------------
            INSERT INTO GE_EXT_CLI_CUENTAS_TMP (GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA, GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO, GE_EXT_CLI_CUENTAS_TMP.TIP_CUENTA,
                                 GE_EXT_CLI_CUENTAS_TMP.COD_OFICINA, GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD, GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA,
                                 GE_EXT_CLI_CUENTAS_TMP.COD_MONEDA, GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL, GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO,
                                 GE_EXT_CLI_CUENTAS_TMP.FRE_EXTRACTO, Tas_Nominal, Tas_Efectiva,
                                 cod_modulo)
                         VALUES (v_cod_persona,  v_fec_actual, 'P',
                                 TA.COD_OFICINA,TA.COD_MODALIDAD,TA.NRO_TARJETA,
                                 TA.COD_MONEDA,TA.SAL_ULT_EXTRACTO, 1,
                                 v_fre_extracto, v_val_tasa, v_val_tae,
                                 ta.cod_modulo);
            ---------------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO RESUMEN DE TARJETAS --
            ---------------------------------------------------------
            INSERT INTO GE_EXT_RESUMENES_TMP (GE_EXT_RESUMENES_TMP.COD_PERSONA, GE_EXT_RESUMENES_TMP.FEC_EXTRACTO, GE_EXT_RESUMENES_TMP.TIPO,
                                 GE_EXT_RESUMENES_TMP.NRO_CUENTA, GE_EXT_RESUMENES_TMP.MTO_CAPITAL, GE_EXT_RESUMENES_TMP.MTO_INTERES,
                                 GE_EXT_RESUMENES_TMP.FEC_VENCIMIENTO, GE_EXT_RESUMENES_TMP.COD_EXTRACTO, GE_EXT_RESUMENES_TMP.FRE_EXTRACTO,
                                 sal_disponible, cod_modalidad, cod_moneda)
                         VALUES (v_cod_persona, v_fec_actual, '4',
                                 TA.nro_tarjeta, TA.mto_pag_minimo, TA.sal_disponible,
                                 TA.fec_vct_ult_cierre, 1, v_fre_extracto, ta.SALDO, ta.cod_modalidad, ta.cod_moneda);
         END LOOP;
   end lp_generar_tarjetas;

   procedure lp_act_tip_mensaje is
   begin
      -- Debe actualizar de acuerdo a los sqls
      null;
   end lp_act_tip_mensaje;

   PROCEDURE lp_act_nro_control IS
       Cursor c1 is Select GE_EXT_CLIENTES_TMP.COD_USU_OFICIAL OFICIAL, rowid registro
                      From GE_EXT_CLIENTES_TMP
                     Where GE_EXT_CLIENTES_TMP.FEC_EXTRACTO = v_fec_actual
                       and GE_EXT_CLIENTES_TMP.FRE_EXTRACTO = v_fre_extracto
                       and GE_EXT_CLIENTES_TMP.TIP_IMPRESION in ('C', 'S')
                     Order by GE_EXT_CLIENTES_TMP.COD_USU_OFICIAL, GE_EXT_CLIENTES_TMP.COD_PAIS, GE_EXT_CLIENTES_TMP.COD_CIUDAD,
                              upper(GE_EXT_CLIENTES_TMP.BARRIO), ltrim(upper(GE_EXT_CLIENTES_TMP.DIRECCION));
      v_Oficial ba_usuarios.cod_usuario%type;
      v_Cantidad number(10) := 0;
      r1   c1%rowtype;
    BEGIN
      v_lugar := 'lp_act_nro_control';
      If c1%isopen THEN
         CLOSE c1;
      End If;
      Open c1;
      Loop
         Fetch c1 INTO r1;
         Exit When c1%notfound;
         If r1.Oficial != v_Oficial or v_Oficial is null Then
            v_Cantidad := 0;
            v_Oficial  := r1.Oficial;
         End If;
         v_Cantidad := v_Cantidad + 1;
         Update GE_EXT_CLIENTES_TMP
            set NRO_CONTROL = v_Cantidad
          where rowid = r1.registro;
      End Loop;
   END;
   procedure lp_mar_ext_con_diferencia is
    -- P.V. 12-08-10 Cursor de Cuentas con diferencia para ahorros vistas y Cta. Corrientes.
    CURSOR DIFEREN IS
       SELECT GE_EXT_CLIENTES_TMP.COD_PERSONA, GE_EXT_CLIENTES_TMP.COD_EXTRACTO, GE_EXT_CLIENTES_TMP.FEC_EXTRACTO
         FROM GE_EXT_CLIENTES_TMP
        WHERE GE_EXT_CLIENTES_TMP.FEC_EXTRACTO = v_fec_actual
          AND GE_EXT_CLIENTES_TMP.COD_PERSONA = NVL(P_COD_PERSONA,GE_EXT_CLIENTES_TMP.COD_PERSONA)
          AND EXISTS (SELECT 0
                        FROM AH_CTA_VISTAS, GE_EXT_CLI_CUENTAS_TMP
                       WHERE AH_CTA_VISTAS.NRO_CUENTA = GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA
                         AND AH_CTA_VISTAS.COD_MODALIDAD = GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD
                         AND AH_CTA_VISTAS.COD_OFICINA = GE_EXT_CLI_CUENTAS_TMP.COD_OFICINA
                         AND GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA = GE_EXT_CLIENTES_TMP.COD_PERSONA
                         AND GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO = GE_EXT_CLIENTES_TMP.COD_EXTRACTO
                         AND GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO = GE_EXT_CLIENTES_TMP.FEC_EXTRACTO
                         AND GE_EXT_CLI_CUENTAS_TMP.FRE_EXTRACTO = GE_EXT_CLIENTES_TMP.FRE_EXTRACTO
                         AND GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA = NVL(P_NRO_CUENTA,GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA)
                         AND AH_CTA_VISTAS.COD_MODULO = 3
                         AND (NVL(GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL,0) <>
                              NVL(AH_CTA_VISTAS.SAL_TOTAL,0) - NVL(AH_CTA_VISTAS.SAL_RETENIDO,0) OR
                              NVL(GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL,0) <>
                              NVL(AH_CTA_VISTAS.SAL_TOT_BATCH,0) - NVL(AH_CTA_VISTAS.SAL_RET_BATCH,0)))
       UNION ALL
       SELECT GE_EXT_CLIENTES_TMP.COD_PERSONA, GE_EXT_CLIENTES_TMP.COD_EXTRACTO, GE_EXT_CLIENTES_TMP.FEC_EXTRACTO
         FROM GE_EXT_CLIENTES_TMP
        WHERE GE_EXT_CLIENTES_TMP.FEC_EXTRACTO = v_fec_actual
          AND GE_EXT_CLIENTES_TMP.COD_PERSONA = NVL(P_COD_PERSONA,GE_EXT_CLIENTES_TMP.COD_PERSONA)
          AND EXISTS (SELECT 0
                        FROM CC_CTA_CORRIENTES, GE_EXT_CLI_CUENTAS_TMP
                       WHERE CC_CTA_CORRIENTES.NRO_CUENTA = GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA
                         AND CC_CTA_CORRIENTES.COD_MODALIDAD = GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD
                         AND CC_CTA_CORRIENTES.COD_OFICINA = GE_EXT_CLI_CUENTAS_TMP.COD_OFICINA
                         AND GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA = GE_EXT_CLIENTES_TMP.COD_PERSONA
                         AND GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO = GE_EXT_CLIENTES_TMP.COD_EXTRACTO
                         AND GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO = GE_EXT_CLIENTES_TMP.FEC_EXTRACTO
                         AND GE_EXT_CLI_CUENTAS_TMP.FRE_EXTRACTO = GE_EXT_CLIENTES_TMP.FRE_EXTRACTO
                         AND GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA = NVL(P_NRO_CUENTA,GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA)
                         AND CC_CTA_CORRIENTES.COD_MODULO = 4
                         AND (NVL(GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL,0) <>
                              NVL(CC_CTA_CORRIENTES.SAL_TOTAL,0) - NVL(CC_CTA_CORRIENTES.SAL_RETENIDO,0) OR
                              NVL(GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL,0) <>
                              NVL(CC_CTA_CORRIENTES.SAL_TOT_BATCH,0) - NVL(CC_CTA_CORRIENTES.SAL_RET_BATCH,0)));
    BEGIN
       v_lugar := 'lp_mar_ext_con_diferencia';
       --- actualiza con lower (minuscula las cuentas que tuvieron dif. ---
       --- para que no imprima con los demas extractos --------------------
       FOR CA IN DIFEREN LOOP
         UPDATE GE_EXT_CLIENTES_TMP
            SET GE_EXT_CLIENTES_TMP.FRE_EXTRACTO = LOWER(GE_EXT_CLIENTES_TMP.FRE_EXTRACTO)
          WHERE GE_EXT_CLIENTES_TMP.COD_PERSONA = CA.COD_PERSONA
            AND GE_EXT_CLIENTES_TMP.COD_EXTRACTO = CA.COD_EXTRACTO
            AND GE_EXT_CLIENTES_TMP.FEC_EXTRACTO = CA.FEC_EXTRACTO;
       END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003,'Error al marcar diferencias '||sqlerrm);
   end;
   procedure lp_mar_ext_con_dif_detalle is
    -- P.V. 12-08-10 Si tiene par?metro por persona o cuenta trae solo esos movientos
    CURSOR DIFEREN IS
        SELECT GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA, GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO
          FROM GE_TRANSACCIONES, GE_EXT_CLI_MOVIMIENTOS_TMP, GE_EXT_CLI_CUENTAS_TMP
         WHERE GE_TRANSACCIONES.COD_MODULO = GE_EXT_CLI_MOVIMIENTOS_TMP.COD_MODULO
           and GE_TRANSACCIONES.COD_MODALIDAD = GE_EXT_CLI_MOVIMIENTOS_TMP.COD_MODALIDAD
           and GE_TRANSACCIONES.COD_TRANSACCION = GE_EXT_CLI_MOVIMIENTOS_TMP.COD_TRA_PADRE
           and GE_EXT_CLI_MOVIMIENTOS_TMP.COD_PERSONA = GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA
           AND GE_EXT_CLI_MOVIMIENTOS_TMP.COD_EXTRACTO = GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO
           AND GE_EXT_CLI_MOVIMIENTOS_TMP.FEC_EXTRACTO = GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO
           AND GE_EXT_CLI_MOVIMIENTOS_TMP.NRO_CUENTA = GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA
           AND GE_EXT_CLI_MOVIMIENTOS_TMP.COD_PERSONA = NVL(P_COD_PERSONA,GE_EXT_CLI_MOVIMIENTOS_TMP.COD_PERSONA)
           AND GE_EXT_CLI_MOVIMIENTOS_TMP.NRO_CUENTA = NVL(P_NRO_CUENTA,GE_EXT_CLI_MOVIMIENTOS_TMP.NRO_CUENTA)
           AND GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO = v_fec_actual
           AND GE_EXT_CLI_CUENTAS_TMP.FRE_EXTRACTO = v_fre_extracto
           AND GE_EXT_CLI_CUENTAS_TMP.TIP_CUENTA = 'A'
           --WA:06/08/2014 Se modifica para modalidad 49 Financieras del Pais
           AND GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD IN (31,41,42,48,49,334)
         GROUP BY GE_EXT_CLI_CUENTAS_TMP.COD_PERSONA, GE_EXT_CLI_CUENTAS_TMP.COD_EXTRACTO, GE_EXT_CLI_CUENTAS_TMP.FEC_EXTRACTO, GE_EXT_CLI_CUENTAS_TMP.NRO_CUENTA,
                  GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD, GE_EXT_CLI_CUENTAS_TMP.SAL_ANTERIOR, GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL
       HAVING DECODE(GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD,42,GE_EXT_CLI_CUENTAS_TMP.SAL_ANTERIOR*-1, 48,GE_EXT_CLI_CUENTAS_TMP.SAL_ANTERIOR*-1, 49,GE_EXT_CLI_CUENTAS_TMP.SAL_ANTERIOR*-1,GE_EXT_CLI_CUENTAS_TMP.SAL_ANTERIOR) +
        (SUM(GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_CREDITO) - SUM(GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_DEBITO))
         != DECODE(GE_EXT_CLI_CUENTAS_TMP.COD_MODALIDAD,42,GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL*-1,48,GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL*-1,49,GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL*-1,GE_EXT_CLI_CUENTAS_TMP.SAL_ACTUAL);
    BEGIN
      v_lugar := 'lp_mar_ext_con_dif_detalle';
      FOR CA IN DIFEREN LOOP
        UPDATE GE_EXT_CLIENTES_TMP
           SET GE_EXT_CLIENTES_TMP.FRE_EXTRACTO = LOWER(GE_EXT_CLIENTES_TMP.FRE_EXTRACTO)
         WHERE GE_EXT_CLIENTES_TMP.COD_PERSONA = CA.COD_PERSONA
           AND GE_EXT_CLIENTES_TMP.COD_EXTRACTO = CA.COD_EXTRACTO
           AND GE_EXT_CLIENTES_TMP.FEC_EXTRACTO = v_fec_actual
           AND GE_EXT_CLIENTES_TMP.FRE_EXTRACTO = v_fre_extracto;
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20004,'Error al marcar dif. detalle '||sqlerrm);
   end lp_mar_ext_con_dif_detalle;

   procedure lp_borrar_movimientos is
   Begin
      v_lugar := 'lp_borrar_movimientos';
      --------------------------------
      -- BORRA CABECERA DEL CLIENTE --
      --------------------------------
      DELETE GE_EXT_CLIENTES_TMP A
       WHERE NOT EXISTS (SELECT 1 FROM GE_EXT_CLI_MOVIMIENTOS_TMP B, GE_EXT_CLI_CUENTAS_TMP C
                          WHERE B.COD_PERSONA = A.COD_PERSONA
                            AND B.COD_EXTRACTO = A.COD_EXTRACTO
                            AND B.FEC_EXTRACTO = A.FEC_EXTRACTO
                            AND C.COD_PERSONA = B.COD_PERSONA
                            AND C.COD_EXTRACTO = B.COD_EXTRACTO
                            AND C.FEC_EXTRACTO = B.FEC_EXTRACTO
                            AND C.FRE_EXTRACTO = A.FRE_EXTRACTO
                            AND C.NRO_CUENTA = B.NRO_CUENTA)
         AND A.FEC_EXTRACTO = v_fec_actual;
      ----------------------------------------------
      -- BORRA CABECERA ACTIVO PASIVO DEL CLIENTE --
      ----------------------------------------------
      DELETE GE_EXT_CLI_CUENTAS_TMP A
       WHERE NOT EXISTS (SELECT 1 FROM GE_EXT_CLIENTES_TMP B
                          WHERE B.COD_PERSONA = A.COD_PERSONA
                            AND B.COD_EXTRACTO = A.COD_EXTRACTO
                            AND B.FEC_EXTRACTO = A.FEC_EXTRACTO
                            AND B.FRE_EXTRACTO = A.FRE_EXTRACTO)
         AND A.FEC_EXTRACTO = v_fec_actual;
      -------------------------------
      -- BORRA RESUMEN DEL CLIENTE --
      -------------------------------
      DELETE GE_EXT_RESUMENES_TMP A
       WHERE NOT EXISTS (SELECT 1 FROM GE_EXT_CLIENTES_TMP B
                          WHERE B.COD_PERSONA = A.COD_PERSONA
                            AND B.COD_EXTRACTO = A.COD_EXTRACTO
                            AND B.FEC_EXTRACTO = A.FEC_EXTRACTO
                           )
         AND A.FEC_EXTRACTO = v_fec_actual;
   end lp_borrar_movimientos;
   procedure lp_gen_extracto is
     v_cantidad NUMBER(06) := 0;
   --- Define el cursor ---
       CURSOR CTAS IS
         SELECT DISTINCT GE_CTA_CLIENTES.COD_MODULO,
                DECODE( GE_CTA_CLIENTES.COD_MODULO, 3, GE_CTA_CLIENTES.COD_MODALIDAD,
                                                    4, decode( GE_CTA_CLIENTES.COD_MODALIDAD, 41, 41, 43 ),
                                                       GE_CTA_CLIENTES.COD_MODULO ) COD_MODALIDAD
           FROM GE_CTA_CLIENTES
          WHERE GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
            and ge_cta_clientes.nro_cuenta = nvl(v_nro_cta_parametro, ge_cta_clientes.nro_cuenta) --si es x cuenta
            AND GE_CTA_CLIENTES.RELACION = 'P'
            AND GE_CTA_CLIENTES.COD_MODULO >= 3
            AND GE_CTA_CLIENTES.COD_MODULO <= 6
          ORDER BY decode(GE_CTA_CLIENTES.COD_MODULO, 4, 1, 3,
                   DECODE( GE_CTA_CLIENTES.COD_MODULO, 3, GE_CTA_CLIENTES.COD_MODALIDAD,
                                                    4, decode( GE_CTA_CLIENTES.COD_MODALIDAD, 41, 41, 43 ),
                                                       GE_CTA_CLIENTES.COD_MODULO ) );
   begin
     v_lugar := 'lp_gen_extracto';
      -- Inicializo la variable que separa los extractos especificos-
      v_cod_extracto := 1;
      -- CUENTAS CORRIENTE Y AHORRO A LA VISTA del CLIENTE ----------
      v_inserta     := 'N';
      v_cod_persona := p_COD_PERSONA;
      ---------------------------------------------------------------------------
      /*Esto evita que, si un cliente tiene una cuenta de vistas con modalidad 31
       y otra con 334, lp_generar_vistas se llame dos veces.*/
      v_cantidad:=0;
       SELECT COUNT(*)
      INTO v_cantidad
      FROM GE_CTA_CLIENTES
      WHERE COD_PERSONA = v_cod_persona
        AND NRO_CUENTA = NVL(v_nro_cta_parametro, NRO_CUENTA)
        AND RELACION = 'P'
        AND COD_MODULO = 3
        AND COD_MODALIDAD IN (31, 334);

      IF v_cantidad > 0 THEN
         lp_generar_vistas;
      END IF;
      ----------------------------------------------------------------------------
      FOR RCTA IN CTAS LOOP
          If rcta.COD_MODULO = 4 THEN
            IF rcta.cod_modalidad = 41 THEN
              lp_generar_ctacte;
            ELSE
              lp_generar_ctaban;
            END IF;
          /*ElsIf rcta.COD_MODULO = 3 and rcta.COD_MODALIDAD in (31,334) Then
             lp_generar_vistas;*/
          Elsif rcta.COD_MODULO = 3 and rcta.COD_MODALIDAD in (33,34,35,36) Then
             v_cod_modalidad := rcta.cod_modalidad;
             lp_generar_certificados;
          Elsif rcta.COD_MODULO = 3 and rcta.COD_MODALIDAD in (38) Then
             v_cod_modalidad := rcta.cod_modalidad;
             lp_generar_programados;
          Elsif rcta.COD_MODULO = 6 Then
             lp_generar_prestamos;
          Elsif rcta.COD_MODULO = 5 Then
             lp_generar_tarjetas;
        End If;
      END LOOP;
   end lp_gen_extracto;
   procedure lp_act_deb_cre_negativos is
    BEGIN
       v_lugar := 'lp_act_deb_cre_negativos';
       --Actualiza Debitos Negativos a Creditos--
       UPDATE GE_EXT_CLI_MOVIMIENTOS_TMP
          SET GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_CREDITO = ABS(GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_DEBITO),
              GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_DEBITO = 0
        WHERE GE_EXT_CLI_MOVIMIENTOS_TMP.FEC_EXTRACTO = v_fec_actual
          AND GE_EXT_CLI_MOVIMIENTOS_TMP.USU_INSERCION = USER -- para que actualice solo los generados por el usuario logueado
          AND GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_DEBITO < 0;
       --Actualiza Creditos Negativos a Debitos--
       UPDATE GE_EXT_CLI_MOVIMIENTOS_TMP
          SET GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_DEBITO = ABS(GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_CREDITO),
              GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_CREDITO = 0
        WHERE GE_EXT_CLI_MOVIMIENTOS_TMP.FEC_EXTRACTO = v_fec_actual
          AND GE_EXT_CLI_MOVIMIENTOS_TMP.USU_INSERCION = USER -- para que actualice solo los generados por el usuario logueado
          AND GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_CREDITO < 0;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003,'Error al actualizar creditos negativos '||sqlerrm);
   end lp_act_deb_cre_negativos;
--ajuste
  procedure lp_act_sal_cta_fecha is
  v_tot_creditos GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_CREDITO%type;
  v_tot_debitos  GE_EXT_CLI_MOVIMIENTOS_TMP.MTO_DEBITO%type;
  v_cod_modalidad     ge_cuentas.cod_modalidad%type;
  v_cod_modulo        ge_cuentas.cod_modulo%type;
  v_sal_ult_ext_mes   cc_sal_mensuales.sal_ini_mes%type;
  v_anho              number(4);
  v_mes               number(4);
  v_pri_dia_mes       ge_calendarios.pri_dia_mes_habil%type;
    CURSOR c_cta_gen IS
      SELECT a.*
        FROM GE_EXT_CLI_CUENTAS_TMP a;
    
     CURSOR c_rev IS
      SELECT a.nro_documento
        FROM GE_EXT_CLI_MOVIMIENTOS_TMP a
        GROUP BY a.nro_documento
        HAVING COUNT(*)>1; 
  
  BEGIN
     v_lugar := 'lp_act_sal_cta_fecha';
     v_pri_dia_mes:= null;
     v_pri_dia_mes:= to_date('01/'||to_char(p_fec_hasta,'mm/yyyy'),'dd/mm/yyyy');
       --para poder hacerlo de meses anteriores
          --Solo para CTACTE y AH
          --Obtenemos el modulo
         v_cod_modulo:=null;
          v_cod_modalidad:=null;
          v_anho:= to_number(to_char(v_fec_recibida,'yyyy'));
          v_mes:= to_number(to_char(v_fec_recibida,'mm'));
           begin
           select z.cod_modalidad , z.cod_modulo
             into v_cod_modalidad, v_cod_modulo
             from GE_EXT_CLI_CUENTAS_TMP z
               where z.nro_cuenta= v_nro_cta_parametro;

          exception
            when others then
                v_cod_modalidad:= null;
          end;

          --Obtenemos saldo inicial de mes
         /* if nvl(p_sal_anterior,0) = 0 then 
              if v_cod_modulo = 4 and v_cod_modalidad=  41 then
                  v_sal_ult_ext_mes:=0;
                  begin
                  select nvl(a.sal_ini_mes,0)
                     into v_sal_ult_ext_mes
                      from cc_sal_mensuales a
                       where  a.nro_cuenta= v_nro_cta_parametro
                         and a.ano= v_anho
                         and a.mes= v_mes ;
                  exception
                    when others then
                      v_sal_ult_ext_mes:=null;
                  end;

                elsif v_cod_modulo = 3 and v_cod_modalidad in (31,334)  then
                      v_sal_ult_ext_mes:=0;
                    begin
                    select nvl(a.sal_ini_mes,0)
                       into v_sal_ult_ext_mes
                        from ah_sal_mensuales a
                         where a.nro_cuenta= v_nro_cta_parametro
                           and a.ano= v_anho
                           and a.mes= v_mes;
                    exception
                      when others then
                        v_sal_ult_ext_mes:=null;
                    end;
                else
                  v_sal_ult_ext_mes:=null;
                end if;
        else*/
           v_sal_ult_ext_mes:=p_sal_anterior;
        --end if;
     --**** Fin de Ajuste --------------------
     --actualizamos las fechas de de insercion como fecha valor
     update GE_EXT_CLI_MOVIMIENTOS_TMP x
      set x.fec_valor= trunc(x.fec_insercion);
     commit;
      --Borramos los que son mayores a la fecha ingresada
      delete from GE_EXT_CLI_MOVIMIENTOS_TMP a
      where (to_date(a.fec_VALOR,'dd/mm/yyyy') > v_fec_recibida) ;
      commit;
      --Borramos los demas
      delete from GE_EXT_CLI_MOVIMIENTOS_TMP a
      where (to_date(a.fec_VALOR,'dd/mm/yyyy') <> v_fec_recibida) ;
      commit;
      --Borramos los que fueron reversados
      FOR r IN c_rev LOOP
           delete from GE_EXT_CLI_MOVIMIENTOS_TMP a
           where a.nro_documento= r.nro_documento  ;
           commit;
      end loop;
      
      
      update GE_EXT_CLI_CUENTAS_TMP z
            set z.sal_anterior =v_sal_ult_ext_mes
                --z.fec_extracto= v_fec_recibida
          where z.nro_cuenta= v_nro_cta_parametro;
        
      --Actualizamos saldo inicial primero
     /* --calculamos
      FOR x IN c_cta_gen LOOP
        v_tot_creditos:= 0;
        v_tot_debitos:= 0;
        --Calculamos el saldo inicial al menor a la fecha recibida
        select sum(a.mto_credito),  sum(a.mto_debito)
        into v_tot_creditos,v_tot_debitos
          from GE_EXT_CLI_MOVIMIENTOS_TMP a
           where a.nro_cuenta= x.nro_cuenta
           and a.fec_valor< v_fec_recibida
           and a.fec_valor>=v_pri_dia_mes;
         --Guardamos el saldo inicial
         update GE_EXT_CLI_CUENTAS_TMP z
            set z.sal_anterior = nvl(v_sal_ult_ext_mes,z.sal_anterior) + nvl(v_tot_creditos,0) - nvl(v_tot_Debitos,0)--,
                --z.fec_extracto= v_fec_recibida
          where z.nro_cuenta= x.nro_cuenta;
          commit;
      end loop;*/
      
      ----------------------------
      --calculamos saldo final
      FOR x IN c_cta_gen LOOP
        v_tot_creditos:= 0;
        v_tot_debitos:= 0;
        select sum(a.mto_credito),  sum(a.mto_debito)
        into v_tot_creditos,v_tot_debitos
          from GE_EXT_CLI_MOVIMIENTOS_TMP a
           where a.nro_cuenta= x.nro_cuenta;

        if nvl(v_tot_creditos,0) > 0  then
          update GE_EXT_CLI_CUENTAS_TMP z
            set z.sal_actual = nvl(z.sal_anterior,0)+  nvl(v_tot_creditos,0) - nvl(v_tot_Debitos,0)
          where z.nro_cuenta= x.nro_cuenta;
          commit;
        end if;
       end loop;
       
       
         --Actualización de fechas solicitado,
         --si es fecha habil, se asigna fecha de valor, sino se muestra fecha no habil
       update GE_EXT_CLI_MOVIMIENTOS_TMP a
         set a.fec_movimiento= 
                case when pag_cal.FU_OBT_FEC_HABIL(a.fec_valor,null, 0) 
                       = a.fec_valor
               then a.fec_valor
               else a.fec_movimiento
               end;
         commit;
     EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003,'Error al act.Sal_Fecha '||sqlerrm);
   end lp_act_sal_cta_fecha;
begin
  -- Carga los valores de fecha que va a utilizar en el proceso --
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
  begin
     v_nro_cta_parametro := trim(p_nro_cuenta);
  exception
     when others then
        v_nro_cta_parametro := null;
  end;


  pag_cal.pr_obt_dat_calendar(3);
  v_fec_actual   := pag_cal.G_FEC_ACTUAL;
  v_fec_recibida:= p_fec_hasta;
  -------
  v_pri_dia_mes_habil := pag_cal.G_PRI_DIA_MES_HABIL;
  -- Borra los extractos generados anteriormente para ese cliente...
  lp_borra_ext_generado;
  if v_est_modulo not in (2,4) then
     commit;
     raise_application_error(-20000,'Estado del Modulo no permite Impresion de Extractos a Requerimiento. Espere un momento..');
  end if;
  --
 -- raise_application_error(-20000,'error..'||v_nro_cta_parametro||'-'||p_cod_persona||'-'||p_fec_hasta);
  lp_gen_extracto;
  --
  -- P.V. 12-08-10 Solo marca los extractos con diferencia si se invoca el programa desde prg_env_ext_mail.
  if nvl(pae_cnf.fu_obt_cod_programa,'x') = 'prg_env_ext_mail' then
    -- Si env?a la fecha del extracto no verifica con el saldo del maestro de la cuenta.
    if p_fec_hasta is null then
      lp_mar_ext_con_diferencia;
    end if;
    --
    lp_mar_ext_con_dif_detalle;
  end if;
  --
  -- actualiza debitos y creditos negativos
  --
  lp_act_deb_cre_negativos;
  COMMIT;
  lp_act_tip_mensaje;
  COMMIT;
  --Actualiza saldos
 lp_act_sal_cta_fecha;



exception
   when OTHERS Then
     if sqlcode <= -20000 then
        raise;
     else
      raise_application_error(-20000,sqlerrm||' / '||v_lugar);
     end if;
end PRG_GEN_EXT_ESP_TMP;
/
