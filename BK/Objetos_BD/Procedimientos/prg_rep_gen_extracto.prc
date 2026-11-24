CREATE OR REPLACE PROCEDURE IT.PRG_REP_GEN_EXTRACTO (p_frecuencia in varchar2 default null,
                                              p_cod_persona in varchar2 default null) is

   -- Modificaciones realizadas el 30/07/2004 por OPGM...
   -- El default del parametro p_frecuencia se modifico para que sea nulo...
   -- Modificaciones realizadas el 29/06/2004 por OPGM...
   -- Se hicieron los cambios para que tome la transaccion 515 como debe ser...
   -- Se creó la función fug_obt_tra_tipo para cosiderar casos como el de la transaccion 515... 13/11/2009 V.O.
   -- AP 3015. Modificaciones realizadas el 18/05/2012 por FGF..
   -- Disminucion del tiempo de bloqueo de las tablas cc_cta_corrientes,cc_cta_bancarias,ah_cta_vistas

   -- Definicion de Variables Globales
   v_lugar             varchar2(2000) := 'Iniciando';
   v_cod_persona       ba_personas.cod_persona%type;
   v_nro_cuenta        ge_cta_clientes.nro_cuenta%type;
   v_cod_extracto      ge_ext_clientes.cod_extracto%type;
   v_cod_ext_separado  ge_ext_clientes.cod_extracto%type;
   v_cod_modalidad     ge_modalidades.cod_modalidad%type;
   ---
   v_fec_actual        ge_calendarios.fec_actual%type;
   v_pri_dia_mes_habil ge_calendarios.pri_dia_mes_habil%type;
   v_ult_dia_mes_habil ge_calendarios.ult_dia_mes_habil%type;
   v_inserta           varchar2(1);
   v_frecuencia        varchar2(1);
   --- Variables de Datos de Direccion
   v_dir_cliente       ge_ext_clientes.direccion%type;
   v_pri_obs_dir       ge_ext_clientes.det_direccion%type;
   v_seg_obs_dir       ge_ext_clientes.observacion%type;
   v_cod_pais          ge_ext_clientes.cod_pais%type;
   v_cod_ciudad        ge_ext_clientes.cod_ciudad%type;
   v_des_barrio        ge_ext_clientes.barrio%type;
   v_tel_cliente       ge_ext_clientes.telefono%type;
   v_tip_envio         ge_dir_envios.tip_envio%type;
   --sergio CROGENEXT
   v_piso varchar2(2000);
   v_departamento varchar2(2000);
   v_edificio varchar2(2000);
   v_direccion varchar2(2000);

--Sergio CROGENEXT-14 11-03-2015: control de dirección extractos
   v_tip_gen_extracto varchar2(1);--I = Individual / C = Consolidado
  -- v_tip_envio varchar2(1);--R = Retener / D = Enviar
   v_es_nomina varchar2(1);-- S =  es nómina / N = no es nómina
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
   ---
   v_fec_sig_habil     ge_calendarios.fec_actual%type;
   v_fec_quincena      ge_calendarios.fec_actual%type;
   v_fec_movimiento    ge_calendarios.fec_actual%type;
   v_sal_actual        ge_ext_cli_cuentas.sal_actual%type;
   v_nom_cliente       ba_personas.nom_completo%type;

   v_mto_bloqueo       number;
   v_sal_blo_anterior  number;
   v_cod_per_ente      ge_entes.cod_persona%type;

   v_msj               varchar2(500);
   ---
   --Generar movimientos retenidos por cuenta
   procedure lp_generar_mov_retenciones(p_nro_cuenta in varchar2) IS
--     V_EXISTE VARCHAR2(1);
      CURSOR RETENCIONES IS
      SELECT AH_RETENCIONES.COD_RETENCION,AH_RETENCIONES.NRO_DOCUMENTO,AH_RETENCIONES.NRO_CUENTA,
             AH_RETENCIONES.COD_MODULO,AH_RETENCIONES.COD_MODALIDAD,/*AH_RETENCIONES.MONTO*/AH_RETENCIONES.SAL_RETENIDO,--Se modico el campo MONTO x SAL_RETENIDO <<EF,09/09/2009>>
             AH_RETENCIONES.FEC_FINAL,AH_RETENCIONES.FEC_INICIO,
             AH_RETENCIONES.ROWID REGISTRO
        FROM AH_RETENCIONES
       WHERE AH_RETENCIONES.NRO_CUENTA = P_nro_cuenta
         AND AH_RETENCIONES.COD_MODALIDAD IN (31,41)
         AND AH_RETENCIONES.LIBERADO  = 'N'
         AND AH_RETENCIONES.FEC_FINAL >  v_fec_actual;
   BEGIN
    Begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1;End;

     v_lugar := 'lp_generar_mov_retenciones. Cta '||p_nro_cuenta;
--     V_EXISTE := 'N';
     --- verifico si ya existe una cabecera del extracto unico
     FOR RET IN RETENCIONES LOOP
         INSERT INTO GE_EXT_CLI_MOV_RETENIDOS(FEC_EXTRACTO,COD_RETENCION,NRO_DOCUMENTO,COD_PERSONA,
                                        MONTO,FEC_MOVIMIENTO,FEC_LIBERACION,NRO_CUENTA,COD_MODULO,
                                        COD_MODALIDAD,FRE_EXTRACTO, COD_EXTRACTO)
                     values(v_fec_actual,ret.cod_retencion,ret.nro_documento,v_cod_persona,
                            /*ret.monto*/ret.sal_retenido,ret.fec_inicio,ret.fec_final,ret.nro_cuenta,ret.cod_modulo, --Se modico el campo MONTO x SAL_RETENIDO <<EF,09/09/2009>>
                            ret.cod_modalidad,v_frecuencia, v_cod_extracto);
     END LOOP;
   end lp_generar_mov_retenciones;
   ---
   --Generar movimientos pendientes de pago por cuenta
   procedure lp_generar_mov_pendientes(p_nro_cuenta in varchar2) IS
--     V_EXISTE VARCHAR2(1);
      CURSOR pendientes IS
      SELECT nro_cuenta, fecha, cod_modulo, cod_modalidad, cod_transaccion, cod_mod_padre, cod_mad_padre, cod_tra_padre,
             monto, usu_insercion, hora, cod_movimiento, cod_usuario, cod_moneda, cod_oficina, cod_error, estado,
             cod_ofi_origen, concepto, cod_tasa, val_tasa, nro_documento, saldo, mto_exonerado, cod_usu_exonerador,
             motivo, observacion, fug_obt_des_transaccion(cod_mod_padre,cod_mad_padre,cod_tra_padre) descripcion,
             rowid registro
        FROM GE_MOV_PENDIENTES
       WHERE GE_MOV_PENDIENTES.NRO_CUENTA = P_nro_cuenta
         AND GE_MOV_PENDIENTES.COD_MODALIDAD IN (31,41)
         AND GE_MOV_PENDIENTES.ESTADO  = 'I'
         AND GE_MOV_PENDIENTES.FECHA <=  v_fec_actual;
   BEGIN
     v_lugar := 'lp_generar_mov_pendientes. Cta '||p_nro_cuenta;
--     V_EXISTE := 'N';
     --- verifico si ya existe una cabecera del extracto unico
     FOR pen IN pendientes LOOP
         INSERT INTO ge_ext_cli_mov_pendientes(FEC_EXTRACTO,Tip_Comision,COD_PERSONA,
                                        MONTO,FEC_MOVIMIENTO,NRO_CUENTA,COD_MODULO,
                                        COD_MODALIDAD,FRE_EXTRACTO, COD_EXTRACTO, descripcion)
                     values(v_fec_actual,pen.cod_transaccion,v_cod_persona,
                            pen.monto,pen.fecha,pen.nro_cuenta,pen.cod_modulo,
                            pen.cod_modalidad,v_frecuencia, v_cod_extracto, pen.descripcion);
     END LOOP;
   end lp_generar_mov_pendientes;
   function lf_obt_per_ente(p_cod_ente ge_entes.cod_ente%type)
     return varchar2 is
     vcod_per_ente ge_entes.cod_persona%type;
     begin
       select cod_persona
       into vcod_per_ente
       from ge_entes
       where cod_ente = p_cod_ente;
       if vcod_per_ente is not null then
         return vcod_per_ente;
       else
         return null;
       end if;
       exception
         when no_data_found then
         return null;
         when others then
         return null;
   end;
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

   --- Para frecuancia Quincenal obtengo fecha hábil desde la quincena.
   function lf_obt_fec_hab_quincena
   return date
   is
     v_fec_actual date := TO_DATE(fug_obt_pardinamico('EXT_FEC_SISTEMA'),'dd/mm/rrrr');
     v_result date;
   begin
     if (to_char(to_date(15||to_char(v_fec_actual,'mmyyyy'),'dd/mm/yyyy'),'D') = 1)
       then
       v_result := to_date(16||to_char(v_fec_actual,'mmyyyy'),'dd/mm/yyyy');
     elsif (to_char(to_date(15||to_char(v_fec_actual,'mmyyyy'),'dd/mm/yyyy'),'D') = 7)
       then
       v_result := to_date(17||to_char(v_fec_actual,'mmyyyy'),'dd/mm/yyyy');
     else
       v_result := to_date(15||to_char(v_fec_actual,'mmyyyy'),'dd/mm/yyyy');
     end if;
     return pag_cal.FU_OBT_FEC_SIG_HAB(v_result-1, null); -- null para p_cod_oficina.
   end lf_obt_fec_hab_quincena;
   ---

   procedure lp_eli_ext_generado is
   begin
      DELETE GE_EXT_CLI_MOVIMIENTOS
       where FEC_EXTRACTO = v_fec_actual
         and upper(FRE_EXTRACTO) = v_frecuencia;
      DELETE GE_EXT_RESUMENES A
       where FEC_EXTRACTO = v_fec_actual
         and upper(FRE_EXTRACTO) = v_frecuencia;
      DELETE GE_EXT_CLI_CUENTAS A
       where FEC_EXTRACTO = v_fec_actual
         and upper(FRE_EXTRACTO) = v_frecuencia;
      DELETE ge_ext_clientes
       where FEC_EXTRACTO = v_fec_actual
         and upper(FRE_EXTRACTO) = v_frecuencia;
      DELETE ge_ext_cli_mov_retenidos
       where FEC_EXTRACTO = v_fec_actual;
   end;
   function lf_ver_ext_generado return number is
       v_conteo number(14) := 0;
   begin
    v_lugar := 'lf_ver_ext_generado';
    -- Verificar mensajes de Extractos...
      SELECT COUNT(*)
        INTO v_conteo
        FROM GE_EXT_CLIENTES
       WHERE FEC_EXTRACTO = v_fec_actual
         AND (COD_PERSONA = P_COD_PERSONA OR P_COD_PERSONA IS NULL)
         AND upper(FRE_EXTRACTO) = v_frecuencia;
      Return v_conteo;
   end lf_ver_ext_generado;
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

        FROM ba_personas, BA_OFICINAS, BA_USUARIOS, GE_CLIENTES
       WHERE GE_CLIENTES.COD_PERSONA = V_COD_PERSONA
         AND BA_USUARIOS.COD_USUARIO = GE_CLIENTES.COD_USU_OFICIAL
         AND BA_OFICINAS.COD_OFICINA = BA_USUARIOS.COD_OFICINA
         and ge_clientes.cod_persona = ba_personas.cod_persona;
       v_es_empleado := FUG_ES_EMPLEADO(v_cod_persona);
    EXCEPTION
       WHEN OTHERS THEN
           v_es_empleado := 'N';
           v_tel_oficial := NULL;
           v_int_oficial := NULL;
           v_tip_extracto := null;
           v_cod_ofi_cliente  := null;
           v_cli_confidencial := null;
           v_cat_riesgo := null;
           v_fec_ult_clasif := null;
           v_cod_usu_oficial := NULL;
           v_nom_cliente := null;
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
       v_direccion := null;
       ---1. Leo la vista de acuerdo a los datos que me pasa --------------
       SELECT substr(gv.dir_envio,1,89),     gv.prim_observacion,   gv.seg_observacion,
              gv.cod_pais,      gv.cod_ciudad,         gv.des_barrio,
              gv.tel_principal, gv.tip_envio,

              gv.piso,gv.departamento,gv.edificio
         INTO v_dir_cliente, v_pri_obs_dir, v_seg_obs_dir,
              v_cod_pais,    v_cod_ciudad,  v_des_barrio,
              v_tel_cliente, v_tip_envio,

              v_piso,v_departamento,v_edificio
         FROM gv_dir_envios gv
        WHERE
          --Cliente gen. Individual (dirección personalizada por cuenta)
               ((gv.nro_cuenta = v_nro_cuenta and nvl(v_tip_gen_extracto,'C') = 'I'
                 and gv.COD_PERSONA = v_cod_persona and nvl(v_es_nomina,'N') = 'N')
                OR
          --Cliente gen. Consolidada (dirección personalizada por dirección de envío)
               (gv.nro_cuenta is null and nvl(v_tip_gen_extracto,'C') = 'C'
                 and gv.COD_PERSONA = v_cod_persona and nvl(v_es_nomina,'N') = 'N')
                OR
          --Cliente NÓMINA gen. Consolidada/individual (se tiene que traer la dirección principal del ente.)
               (gv.nro_cuenta is null and nvl(v_es_nomina,'N') = 'S' and gv.cod_persona = v_cod_per_ente
                 and gv.nro_cuenta is null));


               --se obtiene el piso-edificio-dpto si es que no se retiene el extracto
               if instr(v_dir_cliente,'RETENER EN ') = 0 then
                  if v_piso is not null then
                     v_direccion := ' Piso: '||v_piso;
                  end if;

                  if v_departamento is not null then
                    v_direccion:= v_direccion||' Dpto.: '||v_departamento;
                  end if;

                  if v_edificio is not null then
                    v_direccion:= v_direccion||' Edificio: '||v_edificio;
                  end if;



                  v_dir_cliente := substr(v_dir_cliente||v_direccion,1,89);

               end if;






       ---------------------------------------------------------------------
   EXCEPTION
       WHEN NO_DATA_FOUND Then null;
       WHEN TOO_MANY_ROWS Then null;
       WHEN OTHERS THEN v_lugar := substr(v_cod_persona||'-'||v_dir_cliente,1,2000);

   end lp_dir_envio;

   procedure lp_generar_ctacte is

      v_sal_ult_extracto NUMBER(18,2) default 0;
      v_mto_debito  NUMBER(18,2);
      v_mto_credito NUMBER(18,2);
      v_mto_deb     NUMBER(18,2);
      v_mto_cre     NUMBER(18,2);
      v_CAN         NUMBER(06) := 0;
      v_EXISTE      VARCHAR2(01) := 'N';
      v_TIENE_MOV   VARCHAR2(01) := 'N';
      v_CANTIDAD    NUMBER(06) := 0;
      v_imprime_extracto varchar2(1);
      ----------------------------------
      -- CURSOR DEL ARCHIVO PRINCIPAL --
      ----------------------------------
      CURSOR MAE_CUE IS
      SELECT GE_CTA_CLIENTES.COD_MODULO, GE_CTA_CLIENTES.COD_MODALIDAD, GE_CTA_CLIENTES.COD_OFICINA, GE_CTA_CLIENTES.NRO_CUENTA,
             CC_CTA_CORRIENTES.COD_MONEDA,
             CC_CTA_CORRIENTES.SAL_ULT_EXTRACTO,
             nvl(CC_CTA_CORRIENTES.NRO_FOLIO, 0) + 1 NRO_FOLIO, CC_CTA_CORRIENTES.DENOMINACION,
             CC_CTA_CORRIENTES.SAL_RET_BATCH, NVL(CC_CTA_CORRIENTES.FEC_ULT_EXTRACTO,CC_CTA_CORRIENTES.FEC_APERTURA-1) FEC_ULT_EXTRACTO,

             nvl(bpd.val_parametro,'C') SEPARADO,
             --
             CC_CTA_CORRIENTES.ROWID REGISTRO, cc_cta_corrientes.cta_combinada,
             cc_cta_corrientes.sal_total - cc_cta_corrientes.sal_retenido saldo, cc_cta_corrientes.tas_personalizada,
             cc_cta_corrientes.sal_bloqueado, cc_cta_corrientes.cod_ente,
             decode(cc_cta_corrientes.cod_ente,null,'N','S') es_nomina,--se obtiene si es nómina
             NVL(GE_PAQ_CUENTAS.COD_PAQUETE,0) COD_PAQUETE
        FROM GE_DIR_ENVIOS, CC_CTA_CORRIENTES, GE_CTA_CLIENTES, GE_PAQ_CUENTAS, ba_per_dat_adicionales bpd/*,
             ba_per_dat_adicionales bpd1*/
       WHERE GE_DIR_ENVIOS.COD_PERSONA (+) = GE_CTA_CLIENTES.COD_PERSONA--CROGENEXT-13 Sergio Servín 06/08/2014,
         AND GE_DIR_ENVIOS.NRO_CUENTA (+)  = GE_CTA_CLIENTES.NRO_CUENTA--CROGENEXT-13 Sergio Servín 06/08/2014,
         --
         AND GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
         AND GE_CTA_CLIENTES.RELACION = 'P'
--         and ge_cta_clientes.cod_persona = p_persona
         AND CC_CTA_CORRIENTES.COD_MODULO = GE_CTA_CLIENTES.COD_MODULO
         AND CC_CTA_CORRIENTES.COD_MODALIDAD = GE_CTA_CLIENTES.COD_MODALIDAD
         AND CC_CTA_CORRIENTES.COD_OFICINA = GE_CTA_CLIENTES.COD_OFICINA
         AND CC_CTA_CORRIENTES.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
         AND CC_CTA_CORRIENTES.FRE_EXTRACTO = v_frecuencia--CROGENEXT-13 Sergio Servín 06/08/2014

         and bpd.cod_persona(+) = GE_CTA_CLIENTES.COD_PERSONA
         and bpd.parametro(+)  = 'TIP_GEN_EXTRACTOS'
         AND ((CC_CTA_CORRIENTES.ESTADO NOT IN ('C','P')) OR
              (CC_CTA_CORRIENTES.ESTADO IN ('C','P') AND
               CC_CTA_CORRIENTES.FEC_ULT_MOVIMIENTO >=  v_pri_dia_mes_habil AND
               CC_CTA_CORRIENTES.FEC_ULT_MOVIMIENTO > NVL(CC_CTA_CORRIENTES.FEC_ULT_EXTRACTO,CC_CTA_CORRIENTES.FEC_APERTURA-1)))
         AND GE_PAQ_CUENTAS.NRO_CUENTA(+) = GE_CTA_CLIENTES.NRO_CUENTA
         AND GE_PAQ_CUENTAS.COD_PERSONA(+) = GE_CTA_CLIENTES.COD_PERSONA
       ORDER BY GE_PAQ_CUENTAS.COD_MODULO, GE_PAQ_CUENTAS.COD_MODALIDAD, GE_PAQ_CUENTAS.COD_SUB_MODALIDAD, GE_PAQ_CUENTAS.NRO_CUENTA;

v_SAL_ACUMULADO cc_sal_mensuales.sal_acu_deudor%type;
v_CAN_DIA_ACUMULADO cc_sal_mensuales.can_dia_acumulado%type;
v_SAL_PROMEDIO  cc_sal_mensuales.sal_acu_deudor%type;
v_nro_cta_combinada cc_cta_combinadas.nro_cta_ahorro%type;
v_val_tasa ge_tas_fechas.val_tasa%type;
v_val_tae  ge_tas_fechas.val_tasa%type;
v_mto_linea cc_lin_sobregiros.monto%type;
v_fec_vto_linea cc_lin_sobregiros.fec_vencimiento%type;
v_tipo ge_ext_cli_cuentas.tip_cuenta%type;
--v_can_mes number;--CROGENEXT-13 Sergio Servín 06/08/2014
--v_tot_mes number;--CROGENEXT-13 Sergio Servín 06/08/2014
--v_frecuencia varchar2(1);
      BEGIN
        v_lugar := 'lp_generar_ctacte';
        FOR AV IN MAE_CUE LOOP
          --CROGENEXT-13 Sergio Servín 06/08/2014
          --Para Obtener la cantidad de mes desde el último extracto emitido
          /*v_can_mes := round ((v_fec_actual - AV.FEC_ULT_EXTRACTO)/30);
          if v_frecuencia = 'M' then
             v_tot_mes := 1;
          else
             v_tot_mes := 3;
          end if;

          if v_can_mes = 1 and v_frecuencia = 'M' or v_can_mes = 3 and v_frecuencia = 'T' then*/
          --limpio variables
          v_SAL_PROMEDIO := null;
          v_nro_cta_combinada := null;
          v_val_tasa := null;
          v_val_tae  := null;
          v_cod_per_ente := lf_obt_per_ente(av.cod_ente);
          --- asigno el codigo de extracto unico -----------------
          v_nro_cuenta   := av.nro_cuenta;
--          v_cod_extracto := 1;
          v_sal_ult_extracto := nvl(AV.SAL_ULT_EXTRACTO,0);
          v_TIENE_MOV := 'N';
          v_CANTIDAD  := 0;
          v_mto_bloqueo   := lf_obt_mto_bloqueado(av.nro_cuenta);
          v_fec_movimiento := AV.FEC_ULT_EXTRACTO;

          --SE CAPTURA LOS DATOS PARA OBTENER LA DIRECCION CORRECTA DEL EXTRACTO :SServin 13-03-2015 CROGENEXT-14
          v_tip_gen_extracto := AV.SEPARADO;--se obtiene si es individual o consolidado
          --se obtiene si es nómina o no--
          v_es_nomina := AV.ES_NOMINA;
          -----

          --- la suma de todos los movimientos del historico -----
          SELECT SUM(DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'D',
                          NVL(CC_MOVIMIENTOS_HIS.MONTO,0),
                          0)
                          ),
                 SUM(DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta), 'C',
                           NVL(CC_MOVIMIENTOS_HIS.MONTO,0),
                           0)
                           ),
                 COUNT('X')
            INTO v_mto_debito, v_mto_credito, v_cantidad
            FROM GE_TRANSACCIONES, CC_MOVIMIENTOS_HIS
            WHERE CC_MOVIMIENTOS_HIS.COD_MODULO = AV.COD_MODULO
              AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = AV.COD_MODALIDAD
              AND CC_MOVIMIENTOS_HIS.COD_OFICINA = AV.COD_OFICINA
              AND CC_MOVIMIENTOS_HIS.NRO_CUENTA = AV.NRO_CUENTA
              AND CC_MOVIMIENTOS_HIS.FECHA > v_fec_movimiento
              AND CC_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
              AND(CC_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
                 (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
                  FEC_VALOR <= v_fec_movimiento      AND
                  EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                           WHERE CC_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
                             AND CC_MOVIMIENTOS_HIS.HOR_REVERSION  = REV.HORA
                             AND CC_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
                             AND CC_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                             -- DYDMR-5672 NAF 01/2017
                             AND CC_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
                             AND abs(CC_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO)
                          )) OR
                 (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' AND CC_MOVIMIENTOS_HIS.COD_TRA_PADRE = 303
                   AND CC_MOVIMIENTOS_HIS.COD_MAD_PADRE = 455))
              AND CC_MOVIMIENTOS_HIS.ESTADO = 'N'
              AND CC_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
              AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
              AND CC_MOVIMIENTOS_HIS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
              AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
              AND GE_TRANSACCIONES.TIPO IN ('C','D')
              AND NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B';

          -- SDC - AP 897/8 - Ingresa solo si no hay movimientos entonces busca si existe movimiento por bloqueo
          -- Aqui no se incluyen los Bloqueos para Act. el Sal Anterior.

          -- Se comenta para que ya no incluyan los desbloqueos. CB. 25/09/2013
         /*if nvl(v_cantidad,0) = 0 then
          SELECT SUM(DECODE(ge_transacciones.cod_transaccion, 515, 0, 560, 0,
                            decode(GE_TRANSACCIONES.TIPO,'D',NVL(CC_MOVIMIENTOS_HIS.MONTO,0),0))),
                 SUM(DECODE(ge_transacciones.cod_transaccion, 515, NVL(CC_MOVIMIENTOS_HIS.MONTO,0), 560, NVL(CC_MOVIMIENTOS_HIS.MONTO,0),
                            decode(GE_TRANSACCIONES.TIPO,'C',NVL(CC_MOVIMIENTOS_HIS.MONTO,0),0))),
                 COUNT('X')
            INTO v_mto_deb, v_mto_cre, v_can
            FROM GE_TRANSACCIONES, CC_MOVIMIENTOS_HIS
            WHERE CC_MOVIMIENTOS_HIS.COD_MODULO = AV.COD_MODULO
              AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = AV.COD_MODALIDAD
              AND CC_MOVIMIENTOS_HIS.COD_OFICINA = AV.COD_OFICINA
              AND CC_MOVIMIENTOS_HIS.NRO_CUENTA = AV.NRO_CUENTA
              AND CC_MOVIMIENTOS_HIS.FECHA > v_fec_movimiento
              AND CC_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
              AND (CC_MOVIMIENTOS_HIS.REVERSADO = 'N' or
                  (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' and FECHA <= v_fec_movimiento))
              AND CC_MOVIMIENTOS_HIS.ESTADO = 'N'
              AND CC_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
              AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
              AND CC_MOVIMIENTOS_HIS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
              AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
              AND GE_TRANSACCIONES.TIPO IN ('C','D')
              AND (NVL(GE_TRANSACCIONES.AFECTA,'XX') = 'B'
                     AND CC_MOVIMIENTOS_HIS.COD_CAUSA IN
                           (select cod_causa
                              from ge_par_causales
                             where parametro = 'COD_CAU_BLO_EXT'
                               and val_parametro = 'S' )
                     OR NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B' );
         end if;*/
          IF nvl(V_CANTIDAD,0) > 0 or nvl(v_can,0) > 0 THEN
             V_TIENE_MOV := 'S';
          END IF;
            V_EXISTE := 'N';
            --IF AV.SEPARADO = 'S' OR AV.COD_PAQUETE > 0  THEN --CROGENEXT-13 Sergio Servín 06/08/2014
            IF AV.SEPARADO = 'I' OR AV.COD_PAQUETE > 0 THEN
            --
               -- es una direccion especifica, no enviar en ext.unico --
               v_cod_ext_separado := v_cod_ext_separado + 1;
               v_cod_extracto     := v_cod_ext_separado;
               ---------------------------------------------------------
            ELSE
               v_cod_extracto     := 1;
               --- verifico si ya existe una cabecera del extracto unico
               BEGIN
                 SELECT 'S' INTO V_EXISTE
                   FROM GE_EXT_CLIENTES
                  WHERE GE_EXT_CLIENTES.COD_PERSONA = v_cod_persona
                    AND GE_EXT_CLIENTES.COD_EXTRACTO = v_cod_extracto
                    AND GE_EXT_CLIENTES.FEC_EXTRACTO = v_fec_actual
                    AND GE_EXT_CLIENTES.FRE_EXTRACTO = v_frecuencia;
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
               lp_obtener_datos_del_cliente;
               lp_dir_envio;
               v_imprime_extracto := v_tip_extracto;
               v_lugar := '1-insert GE_EXT_CLIENTES '||v_cod_persona||'-'||v_dir_cliente;
               INSERT INTO GE_EXT_CLIENTES (COD_PERSONA, FEC_EXTRACTO, FRE_EXTRACTO,
                                    FUNCIONARIO, NOM_CLIENTE, DIRECCION,
                                    TELEFONO, COD_USU_OFICIAL, COD_PAIS,
                                    COD_CIUDAD, TEL_OFICIAL, NRO_INTERNO,
                                    COD_EXTRACTO, DET_DIRECCION, OBSERVACION,
                                    BARRIO, COD_MENSAJE, tip_impresion,
                                    CLI_CONFIDENCIAL, COD_OFICINA,
                                    Cat_Riesgo,Fec_Ult_Clasif, Cod_Per_Empresa,
                                    tip_direccion )
                            VALUES (v_cod_persona, v_fec_actual,
                                    v_frecuencia,v_es_empleado,
                                    v_nom_cliente, v_dir_cliente,
                                    v_tel_cliente, v_cod_usu_oficial,
                                    v_cod_pais, v_cod_ciudad,
                                    v_tel_oficial, v_int_oficial,v_cod_extracto,
                                    v_pri_obs_dir, v_seg_obs_dir,
                                    v_des_barrio, '1', v_imprime_extracto,
                                    v_cli_confidencial, decode(AV.SEPARADO,'I',av.cod_oficina,v_cod_ofi_cliente),
                                    v_cat_riesgo, v_fec_ult_clasif, v_cod_per_ente,
                                    v_tip_envio);
               v_INSERTA := 'S';
            END IF;
            v_lugar := 'Cta.combinada';
            --busca la cuenta combinada si corresponde
            if av.cta_combinada ='S' then
               begin
                  select nro_cta_ahorro
                    into v_nro_cta_combinada
                    from cc_cta_combinadas
                   where nro_cta_cte = av.nro_cuenta;
               exception
                  when no_data_found then
                     null;
                  when others then
                     null;
               end;
            end if;
            v_lugar := 'Saldo Promedio';
            --obtiene saldo promedio
            pag_cta.PR_OBT_SAL_PROMEDIO(av.COD_MODULO,av.COD_MODALIDAD,av.COD_OFICINA,
                    av.NRO_CUENTA,v_fec_actual,v_fec_actual, v_SAL_ACUMULADO, v_SAL_PROMEDIO,v_CAN_DIA_ACUMULADO);
            --- cargo los valores para el calculo de la tasa --
            v_lugar := 'Tasa de la Cuenta';
            v_val_tasa := fug_obt_val_tasa(av.cod_modulo, av.cod_modalidad, av.cod_oficina, av.nro_cuenta, av.cod_moneda, v_SAL_PROMEDIO, av.tas_personalizada,
                          null, 550, v_fec_actual);--busca x la transaccion de sobregiro
            --obtiene tae
            v_lugar := 'Tae';
            v_val_tae := pas_bcp.FU_OBT_TAE(v_val_tasa,30);
            ----------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
            ----------------------------------------------------
            --si saldo negativo -> tipo Prestamo

            if NVL(v_sal_ult_extracto,0) + NVL(v_mto_credito,0) - NVL(v_mto_debito,0) < 0 then
               v_tipo := 'P';
            else --si saldo positivo -> tipo Ahorro
               v_tipo := 'A';
            end if;
            v_sal_blo_anterior := lf_obt_sal_blo_anterior(av.NRO_CUENTA,av.fec_ult_extracto);
            INSERT INTO GE_EXT_CLI_CUENTAS (GE_EXT_CLI_CUENTAS.COD_PERSONA, GE_EXT_CLI_CUENTAS.FEC_EXTRACTO, GE_EXT_CLI_CUENTAS.TIP_CUENTA,
                                 GE_EXT_CLI_CUENTAS.COD_OFICINA, GE_EXT_CLI_CUENTAS.COD_MODALIDAD, GE_EXT_CLI_CUENTAS.NRO_CUENTA,
                                 GE_EXT_CLI_CUENTAS.COD_MONEDA, GE_EXT_CLI_CUENTAS.SAL_ANTERIOR, GE_EXT_CLI_CUENTAS.SAL_ACTUAL,
                                 GE_EXT_CLI_CUENTAS.NRO_FOLIO, GE_EXT_CLI_CUENTAS.SAL_A_CONFIRMAR, GE_EXT_CLI_CUENTAS.COD_EXTRACTO,
                                 GE_EXT_CLI_CUENTAS.FRE_EXTRACTO, Sal_Promedio, nro_cta_combinada, Tas_Nominal, Tas_Efectiva,
                                 GE_EXT_CLI_CUENTAS.SAL_BLOQUEADO, GE_EXT_CLI_CUENTAS.COD_PER_EMPRESA,
                                 SAL_BLO_ANTERIOR)
                         VALUES (v_cod_persona,  v_fec_actual, v_tipo, --'A',
                                 AV.COD_OFICINA,AV.COD_MODALIDAD,AV.NRO_CUENTA,
                                 AV.COD_MONEDA, v_sal_ult_extracto,
                                 NVL(v_sal_ult_extracto,0) + NVL(v_mto_credito,0) - NVL(v_mto_debito,0),
                                 AV.NRO_FOLIO, AV.SAL_RET_BATCH, v_cod_extracto,
                                 v_frecuencia, v_sal_promedio, v_nro_cta_combinada, v_val_tasa, v_val_tae,
                                 v_mto_bloqueo, v_cod_per_ente, v_sal_blo_anterior);
            lp_generar_mov_retenciones(av.nro_cuenta);
            lp_generar_mov_pendientes(av.nro_cuenta);

           IF v_frecuencia = 'M' THEN
             -- Actualizar el Saldo Mensual Actual.
             BEGIN
               UPDATE CC_SAL_MENSUALES
                  SET SAL_ULT_EXTRACTO =
                      NVL(v_sal_ult_extracto,0) + NVL(v_mto_credito,0) - NVL(v_mto_debito,0)
                WHERE NRO_CUENTA = AV.NRO_CUENTA
                  AND ANO        = TO_NUMBER(TO_CHAR(v_fec_actual,'YYYY'))
                  AND MES        = TO_NUMBER(TO_CHAR(v_fec_actual,'MM'));

             EXCEPTION
               WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20003,'Error al Actualizar el Saldo Mensual en CTA.CTES. '||sqlerrm);
             END;
           END IF;

            IF V_TIENE_MOV = 'S' THEN
               --------------------------------------------
               -- INSERTA REGISTRO EN EL ARCHIVO DETALLE --
               --------------------------------------------
               INSERT INTO GE_EXT_CLI_MOVIMIENTOS (COD_PERSONA, FEC_EXTRACTO, FEC_MOVIMIENTO,
                                    FEC_VALOR, HOR_MOVIMIENTO, NRO_CUENTA,
                                    NRO_DOCUMENTO, COD_MODULO, COD_MODALIDAD,
                                    COD_TRA_PADRE, MTO_DEBITO, MTO_CREDITO,
                                    COD_EXTRACTO, FRE_EXTRACTO, NRO_SECUENCIA, cod_ofi_origen,
                                    FEC_INSERCION, ind_bloqueo)
               SELECT  v_cod_persona, v_fec_actual,
                       CC_MOVIMIENTOS_HIS.FECHA, CC_MOVIMIENTOS_HIS.FEC_VALOR, CC_MOVIMIENTOS_HIS.HORA, CC_MOVIMIENTOS_HIS.NRO_CUENTA,
                       CC_MOVIMIENTOS_HIS.NRO_DOCUMENTO, CC_MOVIMIENTOS_HIS.COD_MOD_PADRE,
                       CC_MOVIMIENTOS_HIS.COD_MAD_PADRE, CC_MOVIMIENTOS_HIS.COD_TRA_PADRE,

                       (DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                        ge_transacciones.tipo,
                                        ge_transacciones.afecta),
                                        'D',
                                        NVL(CC_MOVIMIENTOS_HIS.MONTO,0),0)),
                       (DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                        ge_transacciones.tipo,
                                        ge_transacciones.afecta),
                                        'C',
                                        NVL(CC_MOVIMIENTOS_HIS.MONTO,0),0)),

                       v_cod_extracto, v_frecuencia, CC_MOVIMIENTOS_HIS.NRO_SECUENCIA, cc_movimientos_his.cod_ofi_origen,CC_MOVIMIENTOS_HIS.FEC_INSERCION,
                       decode(ge_transacciones.afecta, 'B', 'S', 'N')
                 FROM GE_TRANSACCIONES, CC_MOVIMIENTOS_HIS
               WHERE CC_MOVIMIENTOS_HIS.COD_MODULO = AV.COD_MODULO
                 AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = AV.COD_MODALIDAD
                 AND CC_MOVIMIENTOS_HIS.COD_OFICINA = AV.COD_OFICINA
                 AND CC_MOVIMIENTOS_HIS.NRO_CUENTA = AV.NRO_CUENTA
                 AND CC_MOVIMIENTOS_HIS.FECHA > v_fec_movimiento -- 17/07/2009 V.O.
                 AND CC_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
                 AND(CC_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
                    (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
                     FEC_VALOR <= v_fec_movimiento   AND
                     EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                              WHERE CC_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
                                AND CC_MOVIMIENTOS_HIS.HOR_REVERSION  = REV.HORA
                                AND CC_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
                                AND CC_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                -- DYDMR-5672 NAF 01/2017
                                AND CC_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
                                AND abs(CC_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO)
                          )) OR
                     (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' AND CC_MOVIMIENTOS_HIS.COD_TRA_PADRE = 303
                      AND CC_MOVIMIENTOS_HIS.COD_MAD_PADRE = 455))
                 AND CC_MOVIMIENTOS_HIS.ESTADO = 'N'
                 AND CC_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                 AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                 AND CC_MOVIMIENTOS_HIS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                 AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                 AND GE_TRANSACCIONES.TIPO IN ('C','D')
                 AND NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B';

               IF SQL%FOUND THEN
	        --DESOPIMI-14 - Optimizar el proceso PRG_GEN_EXTRACTO (Generación Datos para Extracto) - DYD-SDSL-3162
                 INSERT INTO GE_CTA_EXTRACTOS_TMP (
                               NRO_CUENTA, COD_MODULO, COD_MODALIDAD,
                               NRO_FOLIO, FEC_ULT_EXTRACTO, SAL_ULT_EXTRACTO,
                               NOM_TABLA, COD_PERSONA)
                       VALUES (AV.NRO_CUENTA, AV.COD_MODULO, AV.COD_MODALIDAD,
                               AV.NRO_FOLIO, v_fec_actual, NVL(v_sal_ult_extracto,0) + NVL(v_mto_credito,0) -
                               NVL(v_mto_debito,0),
                               'CC_CTA_CORRIENTES', V_COD_PERSONA); --AP 3015
               END IF;
            END IF;

            --buscar linea de sobregiro
            v_fec_vto_linea := null;
            BEGIN
               select NVL(SUM(MONTO),0), min(fec_vencimiento)
                 INTO v_mto_linea, v_fec_vto_linea
                 FROM  cc_lin_sobregiros
                WHERE nro_cuenta = av.nro_cuenta
                  AND v_fec_actual between fec_inicio and fec_vencimiento
                  AND estado = 'A';
              ---------------------------------------------------------
              -- INSERTA REGISTRO EN EL ARCHIVO RESUMEN DE CTA CTE --SOLO SI TIENE SOBREGIRO
              ---------------------------------------------------------
              if v_fec_vto_linea is not null then
                INSERT INTO GE_EXT_RESUMENES (GE_EXT_RESUMENES.COD_PERSONA, GE_EXT_RESUMENES.FEC_EXTRACTO, GE_EXT_RESUMENES.TIPO,
                                     GE_EXT_RESUMENES.NRO_CUENTA, GE_EXT_RESUMENES.MTO_CAPITAL, GE_EXT_RESUMENES.MTO_INTERES,
                                     GE_EXT_RESUMENES.FEC_VENCIMIENTO, GE_EXT_RESUMENES.COD_EXTRACTO, GE_EXT_RESUMENES.FRE_EXTRACTO,
                                     ge_ext_resumenes.sal_disponible, COD_MODALIDAD, cod_moneda)
                             VALUES (v_cod_persona, v_fec_actual, '5',
                                     av.NRO_CUENTA, v_MTO_linea, av.saldo,
                                     v_fec_vto_LINEA, 1, v_frecuencia, (av.saldo - av.sal_bloqueado) + v_mto_linea, av.cod_modalidad, av.cod_moneda);
               end if;
            exception
               when others then
                  null;
            end;
           --end if;
         END LOOP;
   end lp_generar_ctacte;

  PROCEDURE lp_generar_ctaban IS
    v_sal_ult_extracto NUMBER(18,2) default 0;
    v_mto_debito       NUMBER(18,2);
    v_mto_credito      NUMBER(18,2);
    v_mto_deb          NUMBER(18,2);
    v_can              NUMBER(6) := 0;
    v_mto_cre          NUMBER(18,2);
    v_existe           VARCHAR2(1) := 'N';
    v_tiene_mov        VARCHAR2(1) := 'N';
    v_cantidad         NUMBER(6) := 0;
    v_imprime_extracto VARCHAR2(1);
    ----------------------------------
    -- CURSOR DEL ARCHIVO PRINCIPAL --
    ----------------------------------
    CURSOR cuentas
        IS select t.cod_modulo, t.cod_modalidad, t.cod_oficina, t.nro_cuenta,
                  c.cod_moneda, c.sal_ult_extracto, nvl(c.nro_folio, 0) + 1 nro_folio, c.denominacion,
                  c.sal_ret_batch, nvl(c.fec_ult_extracto,c.fec_apertura-1) fec_ult_extracto,

                  nvl(bpd.val_parametro,'C') SEPARADO,
                  --
                  c.rowid registro, c.sal_bloqueado
             from ge_dir_envios d, cc_cta_bancarias c, ge_cta_clientes t ,ba_per_dat_adicionales bpd/*,
                  ba_per_dat_adicionales bpd1*/
            where d.cod_persona (+) = t.cod_persona--CROGENEXT-13 Sergio Servín 06/08/2014
              and d.nro_cuenta (+)  = t.nro_cuenta--CROGENEXT-13 Sergio Servín 06/08/2014

              --
              and t.cod_persona = v_cod_persona
              and t.relacion = 'P'
              and c.cod_modulo = t.cod_modulo
              and c.cod_modalidad = t.cod_modalidad
              and c.cod_oficina = t.cod_oficina
              and c.nro_cuenta = t.nro_cuenta
              and c.fre_extracto = v_frecuencia --CROGENEXT-13 Sergio Servín 06/08/2014

              --
              and bpd.cod_persona(+) = T.COD_PERSONA
              and bpd.parametro(+)  = 'TIP_GEN_EXTRACTOS'

              and ( ( c.estado NOT IN( 'C', 'P' ) ) or
                    ( c.estado IN( 'C', 'P' ) and
                      c.fec_ult_movimiento >=  v_pri_dia_mes_habil and
                      c.fec_ult_movimiento > nvl( c.fec_ult_extracto, c.fec_apertura -1 ) ) );

  BEGIN
    v_lugar := 'lp_generar_ctaban';
    FOR b IN cuentas LOOP
     --CROGENEXT-13 Sergio Servín 06/08/2014
     --Para Obtener la cantidad de mes desde el último extracto emitido
     /*v_can_mes := round ((v_fec_actual - b.FEC_ULT_EXTRACTO)/30);
     if v_frecuencia = 'M' then
          v_tot_mes := 1;
     else
          v_tot_mes := 3;
     end if;

     if v_can_mes = 1 and v_frecuencia = 'M' or v_can_mes = 3 and v_frecuencia = 'T' then*/
      --- asigno el codigo de extracto unico -----------------
      v_nro_cuenta   := b.nro_cuenta;
      --WA:08/08/2014 Se agrega 49 para financiera Pais
      IF b.cod_modalidad in (42,48,49) THEN -- BANCOS DEL PAIS
        v_sal_ult_extracto := nvl( b.sal_ult_extracto, 0 ) * -1;
      ELSE
        v_sal_ult_extracto := nvl( b.sal_ult_extracto, 0 );
      END IF;
      v_tiene_mov := 'N';
      v_cantidad  := 0;
      v_mto_bloqueo := lf_obt_mto_bloqueado(b.nro_cuenta);
      --- la suma de todos los movimientos del historico -----
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
          into v_mto_debito, v_mto_credito, v_cantidad
          from ge_transacciones t, cc_movimientos_his m
         where m.cod_modulo = b.cod_modulo
           and m.cod_modalidad = b.cod_modalidad
           and m.cod_oficina = b.cod_oficina
           and m.nro_cuenta = b.nro_cuenta
           and m.fecha > b.fec_ult_extracto
           and m.fecha <= v_fec_actual
           AND (m.REVERSADO = 'N' OR
	   --DYDMR-6072 - Incidencia SAU - ITGF - Incidencia Generación de Datos de Cuentas Bancarias
                 (m.REVERSADO = 'S' AND
                  FEC_VALOR <= b.fec_ult_extracto      AND
                  EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                           WHERE m.FEC_VALOR = REV.FECHA
                             AND m.HOR_REVERSION  = REV.HORA
                             AND m.COD_USU_REVERSION = REV.COD_USUARIO
                             AND m.NRO_SECUENCIA = REV.NRO_SECUENCIA
                             -- DYDMR-5672 NAF 01/2017
                             AND m.NRO_CUENTA = REV.NRO_CUENTA
                             AND abs(m.MONTO) = abs(REV.MONTO)
                         )) OR
                 (m.REVERSADO = 'S' AND m.COD_TRA_PADRE = 303
                   AND m.COD_MAD_PADRE = 455))
           and m.estado = 'N'
           and m.cod_modulo = t.cod_modulo
           and m.cod_modalidad = t.cod_modalidad
           and m.cod_transaccion = t.cod_transaccion
           and nvl(t.afecta,'X') != 'B'
           and t.ve_cliente = 'S'
           and t.tipo IN( 'C', 'D' );

      EXCEPTION
        when others then
          v_mto_debito := 0;
          v_mto_credito := 0;
          v_cantidad := 0;
      END;
      ----------------------------------------------------------
      -- SDC - AP 897/8 - Si no tiene movimientos verifica si tiene bloqueos
      if nvl(v_cantidad,0) = 0 then
      BEGIN
        -- Aqui no se incluyen los Bloqueos para Act. el Sal Anterior.
        SELECT SUM(DECODE(t.cod_transaccion, 515, 0, 560, 0,
                          decode(t.TIPO,'D',NVL(m.MONTO,0),0))),
               SUM(DECODE(t.cod_transaccion, 515, NVL(m.MONTO,0), 560, NVL(m.MONTO,0),
                          decode(t.TIPO,'C',NVL(m.MONTO,0),0))),
               COUNT('X')
          into v_mto_deb, v_mto_cre, v_can
          from ge_transacciones t, cc_movimientos_his m
         where m.cod_modulo = b.cod_modulo
           and m.cod_modalidad = b.cod_modalidad
           and m.cod_oficina = b.cod_oficina
           and m.nro_cuenta = b.nro_cuenta
           and m.fecha > b.fec_ult_extracto
           and m.fecha <= v_fec_actual
           AND (m.REVERSADO = 'N' OR
	   --DYDMR-6072 - Incidencia SAU - ITGF - Incidencia Generación de Datos de Cuentas Bancarias
                 (m.REVERSADO = 'S' AND
                  FEC_VALOR <= b.fec_ult_extracto      AND
                  EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                           WHERE m.FEC_VALOR = REV.FECHA
                             AND m.HOR_REVERSION  = REV.HORA
                             AND m.COD_USU_REVERSION = REV.COD_USUARIO
                             AND m.NRO_SECUENCIA = REV.NRO_SECUENCIA
                             -- DYDMR-5672 NAF 01/2017
                             AND m.NRO_CUENTA = REV.NRO_CUENTA
                             AND abs(m.MONTO) = abs(REV.MONTO)
                         )) OR
                 (m.REVERSADO = 'S' AND m.COD_TRA_PADRE = 303
                   AND m.COD_MAD_PADRE = 455))
           and m.estado = 'N'
           and m.cod_modulo = t.cod_modulo
           and m.cod_modalidad = t.cod_modalidad
           and m.cod_transaccion = t.cod_transaccion
           and t.ve_cliente = 'S'
           and t.tipo IN( 'C', 'D' )
           AND (NVL(T.AFECTA,'XX') = 'B'
                     AND M.COD_CAUSA IN
                           (select cod_causa
                              from ge_par_causales
                             where parametro = 'COD_CAU_BLO_EXT'
                               and val_parametro = 'S' )
                     OR NVL(T.AFECTA,'XX') != 'B' );
      EXCEPTION
        when others then
          v_mto_deb := 0;
          v_mto_cre := 0;
          v_can := 0;
      END;
      end if;
      ----------------------------------------------------------

      IF nvl( v_cantidad, 0 ) > 0 or nvl(v_can,0) > 0 THEN
        v_tiene_mov := 'S';
      END IF;
      v_existe := 'N';
      --IF b.separado = 'S' THEN--CROGENEXT-13 Sergio Servín 06/08/2014
      IF b.separado = 'I' THEN
      --
         -- es una direccion especifica, no enviar en ext.unico --
         v_cod_ext_separado := v_cod_ext_separado + 1;
         v_cod_extracto     := v_cod_ext_separado;
         ---------------------------------------------------------
      ELSE
         v_cod_extracto     := 1;
        --- verifico si ya existe una cabecera del extracto unico
        BEGIN
          select 'S'
            into v_existe
            from ge_ext_clientes
           where cod_persona  = v_cod_persona
             and cod_extracto = v_cod_extracto
             and fec_extracto = v_fec_actual
             and fre_extracto = v_frecuencia;
          v_existe := 'S';
        EXCEPTION
          when no_data_found then
            v_existe := 'N';
          when too_many_rows then
            v_existe := 'S';
          when others then
            dbms_output.put_line( 'ERROR al Buscar el Extr.del Cliente. CONTINUO. ' || sqlerrm );
            v_existe := 'N';
        END;
      END IF;
      IF v_existe = 'N' THEN
        -- busco los datos del cliente ---------------------------
        lp_obtener_datos_del_cliente;
        lp_dir_envio;
        v_imprime_extracto := v_tip_extracto;
        v_lugar := '1-insert GE_EXT_CLIENTES '||v_cod_persona||'-'||v_dir_cliente;
        BEGIN
          insert into ge_ext_clientes( cod_persona,
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
                                       fec_ult_clasif,
                                       tip_direccion )
                               values( v_cod_persona,
                                       v_fec_actual,
                                       v_frecuencia,
                                       v_es_empleado,
                                       v_nom_cliente,--b.denominacion,
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
                                       --v_cod_ofi_cliente,
                                       decode(b.SEPARADO,'I',b.cod_oficina,v_cod_ofi_cliente),
                                       v_cat_riesgo,
                                       v_fec_ult_clasif,
                                       v_tip_envio );
        EXCEPTION
          when others then
            NULL;
        END;
        v_inserta := 'S';
      END IF;
      ----------------------------------------------------
      -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
      ----------------------------------------------------
      BEGIN
          --WA:08/08/2014 Se agrega 49 para financiera Pais
        if b.cod_modalidad in (42,48,49) then -- bancos del pais
            v_sal_actual := nvl( v_sal_ult_extracto, 0 ) - nvl( v_mto_credito, 0 ) + nvl( v_mto_debito, 0 );
        else
            v_sal_actual := nvl( v_sal_ult_extracto, 0 ) - nvl( v_mto_debito, 0 ) + nvl( v_mto_credito, 0 );
        end if;
        insert into ge_ext_cli_cuentas( cod_persona,
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
                                        sal_bloqueado )
                                values( v_cod_persona,
                                        v_fec_actual,
                                        'A',
                                        b.cod_oficina,
                                        b.cod_modalidad,
                                        b.nro_cuenta,
                                        b.cod_moneda,
                                        v_sal_ult_extracto,
                                        v_sal_actual,
                                        b.nro_folio,
                                        b.sal_ret_batch,
                                        v_cod_extracto,
                                        v_frecuencia,
                                        v_mto_bloqueo );
        --lp_generar_mov_retenciones(b.nro_cuenta);
      EXCEPTION
        when others then
            NULL;
      END;
      IF v_tiene_mov = 'S' THEN
        --------------------------------------------
        -- INSERTA REGISTRO EN EL ARCHIVO DETALLE --
        --------------------------------------------
        BEGIN
          insert into ge_ext_cli_movimientos( cod_persona,
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
                                              Fec_Insercion,
                                              ind_bloqueo)
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
                                              (decode(fug_obt_tra_tipo(t.cod_transaccion,t.tipo,t.afecta),
                                              'D',NVL(h.monto,0),0)),
                                              (decode(fug_obt_tra_tipo(t.cod_transaccion,t.tipo,afecta),
                                              'C',NVL(h.monto,0),0)),
                                              v_cod_extracto,
                                              v_frecuencia,
                                              h.nro_secuencia,
                                              h.cod_ofi_origen,
                                              h.fec_insercion,
                                              decode(t.afecta, 'B', 'S', 'N')
                                         from ge_transacciones t, cc_movimientos_his h
                                        where h.cod_modulo = b.cod_modulo
                                          and h.cod_modalidad = b.cod_modalidad
                                          and h.cod_oficina = b.cod_oficina
                                          and h.nro_cuenta = b.nro_cuenta
                                          and h.fecha > b.fec_ult_extracto                                     
                                          and h.fecha <= v_fec_actual
	   				  --DYDMR-6072 - Incidencia SAU - ITGF - Incidencia Generación de Datos de Cuentas Bancarias
                                          AND (h.REVERSADO = 'N' OR
                                                 (h.REVERSADO = 'S' AND
                                                  FEC_VALOR <= b.fec_ult_extracto      AND
                                                  EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                                                           WHERE h.FEC_VALOR = REV.FECHA
                                                             AND h.HOR_REVERSION  = REV.HORA
                                                             AND h.COD_USU_REVERSION = REV.COD_USUARIO
                                                             AND h.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                                             -- DYDMR-5672 NAF 01/2017
                                                             AND h.NRO_CUENTA = REV.NRO_CUENTA
                                                             AND abs(h.MONTO) = abs(REV.MONTO)
                                                         )) OR
                                                 (h.REVERSADO = 'S' AND h.COD_TRA_PADRE = 303
                                                   AND h.COD_MAD_PADRE = 455))
                                          and h.estado = 'N'
                                          and h.cod_modulo = t.cod_modulo
                                          and h.cod_modalidad = t.cod_modalidad
                                          and h.cod_transaccion = t.cod_transaccion
                                          AND (NVL(t.AFECTA,'XX') = 'B'
                                               AND h.COD_CAUSA IN
                                                     (select cod_causa
                                                        from ge_par_causales
                                                       where parametro = 'COD_CAU_BLO_EXT'
                                                         and val_parametro = 'S' )
                                               OR NVL(t.AFECTA,'XX') != 'B' )
                                          and t.ve_cliente = 'S'
                                          and t.tipo IN( 'C', 'D' );
          IF SQL%FOUND THEN
	    --DESOPIMI-14 - Optimizar el proceso PRG_GEN_EXTRACTO (Generación Datos para Extracto) - DYD-SDSL-3162	  
            INSERT INTO GE_CTA_EXTRACTOS_TMP(
                               NRO_CUENTA, COD_MODULO, COD_MODALIDAD,
                               NRO_FOLIO, FEC_ULT_EXTRACTO, SAL_ULT_EXTRACTO,
                               NOM_TABLA, COD_PERSONA)
                       VALUES (b.nro_cuenta, b.cod_modulo, b.cod_modalidad,
                               b.nro_folio, v_fec_actual,  v_sal_actual/*nvl( v_sal_ult_extracto, 0 ) -
                               nvl( v_mto_debito, 0 ) + nvl( v_mto_credito, 0 )*/,
                               'CC_CTA_BANCARIAS', V_COD_PERSONA); --AP 3015
          END IF;
        EXCEPTION
          when others then
            NULL;
        END;
      END IF;
      --END IF;
    END LOOP;
  END lp_generar_ctaban;

   procedure lp_generar_vistas is
      v_sal_ult_extracto NUMBER(18,2) default 0;
      v_mto_debito NUMBER(18,2);
      v_mto_credito NUMBER(18,2);
      v_mto_deb NUMBER(18,2);
      v_mto_cre NUMBER(18,2);
      v_CAN     NUMBER(06) := 0;
      v_EXISTE  VARCHAR2(01) := 'N';
      v_TIENE_MOV VARCHAR2(01) := 'N';
      v_CANTIDAD  NUMBER(06) := 0;
      v_imprime_extracto varchar2(1);
      ----------------------------------
      -- CURSOR DEL ARCHIVO PRINCIPAL --
      ----------------------------------
      CURSOR MAE_CUE IS
      SELECT GE_CTA_CLIENTES.COD_MODULO, GE_CTA_CLIENTES.COD_MODALIDAD, GE_CTA_CLIENTES.COD_OFICINA, GE_CTA_CLIENTES.NRO_CUENTA,
             AH_CTA_VISTAS.COD_MONEDA,
             AH_CTA_VISTAS.SAL_ULT_EXTRACTO,
             nvl(AH_CTA_VISTAS.NRO_FOLIO, 0) + 1 NRO_FOLIO, AH_CTA_VISTAS.DENOMINACION,
             AH_CTA_VISTAS.SAL_RET_BATCH, NVL(AH_CTA_VISTAS.FEC_ULT_EXTRACTO,AH_CTA_VISTAS.FEC_APERTURA-1) FEC_ULT_EXTRACTO,
             nvl(bpd.val_parametro,'C') SEPARADO,
             --
             AH_CTA_VISTAS.ROWID REGISTRO, ah_cta_vistas.cta_combinada, ah_cta_vistas.tas_personalizada, ah_cta_vistas.cod_tasa,
             AH_CTA_VISTAS.SAL_BLOQUEADO, AH_CTA_VISTAS.COD_ENTE,
             decode(AH_CTA_VISTAS.cod_ente,null,'N','S') es_nomina,--se obtiene si es nómina
             NVL(GE_PAQ_CUENTAS.COD_PAQUETE,0) COD_PAQUETE
        FROM GE_DIR_ENVIOS, AH_CTA_VISTAS, GE_CTA_CLIENTES, GE_PAQ_CUENTAS, ba_per_dat_adicionales bpd/*,
             ba_per_dat_adicionales bpd1*/
       WHERE GE_DIR_ENVIOS.COD_PERSONA (+) = GE_CTA_CLIENTES.COD_PERSONA--CROGENEXT-13 Sergio Servín 06/08/2014
         AND GE_DIR_ENVIOS.NRO_CUENTA (+)  = GE_CTA_CLIENTES.NRO_CUENTA--CROGENEXT-13 Sergio Servín 06/08/2014

         AND GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
         AND GE_CTA_CLIENTES.RELACION = 'P'
         AND AH_CTA_VISTAS.COD_MODULO = GE_CTA_CLIENTES.COD_MODULO
         AND AH_CTA_VISTAS.COD_MODALIDAD = GE_CTA_CLIENTES.COD_MODALIDAD
         AND AH_CTA_VISTAS.COD_OFICINA = GE_CTA_CLIENTES.COD_OFICINA
         AND AH_CTA_VISTAS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
         AND AH_CTA_VISTAS.FRE_EXTRACTO = v_frecuencia--CROGENEXT-13 Sergio Servín 06/08/2014

         --
         and bpd.cod_persona(+) = GE_CTA_CLIENTES.COD_PERSONA
         and bpd.parametro(+)  = 'TIP_GEN_EXTRACTOS'
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
         --CROGENEXT-13 Sergio Servín 06/08/2014
         --Para Obtener la cantidad de mes desde el último extracto emitido
         /*v_can_mes := round ((v_fec_actual - AV.FEC_ULT_EXTRACTO)/30);
         if v_frecuencia = 'M' then
              v_tot_mes := 1;
         else
              v_tot_mes := 3;
         end if;

         if v_can_mes = 1 and v_frecuencia = 'M' or v_can_mes = 3 and v_frecuencia = 'T' then*/
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
          v_cod_per_ente := lf_obt_per_ente(av.cod_ente);
          v_fec_movimiento := AV.FEC_ULT_EXTRACTO;

          --SE CAPTURA LOS DATOS PARA OBTENER LA DIRECCION CORRECTA DEL EXTRACTO :SServin 13-03-2015 CROGENEXT-14
          v_tip_gen_extracto := AV.SEPARADO;--se obtiene si es individual o consolidado
          --se obtiene si es nómina o no--
          v_es_nomina := AV.ES_NOMINA;
          -----

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
            WHERE AH_MOVIMIENTOS_HIS.COD_MODULO = AV.COD_MODULO
              AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = AV.COD_MODALIDAD
              AND AH_MOVIMIENTOS_HIS.COD_OFICINA = AV.COD_OFICINA
              AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = AV.NRO_CUENTA
              AND AH_MOVIMIENTOS_HIS.FECHA > v_fec_movimiento
              AND AH_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
              AND(AH_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
                 (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
                  FEC_VALOR <= v_fec_movimiento   AND
                  EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                           WHERE AH_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
                             AND AH_MOVIMIENTOS_HIS.HOR_REVERSION  = REV.HORA
                             AND AH_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
                             AND AH_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                             -- DYDMR-5672 NAF 01/2017
                             AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
                             AND abs(AH_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO)
                          )) OR
                  (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND AH_MOVIMIENTOS_HIS.COD_TRA_PADRE = 303
                   AND AH_MOVIMIENTOS_HIS.Cod_Mad_Padre = 455))
              AND AH_MOVIMIENTOS_HIS.ESTADO = 'N'
              AND AH_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
              AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
              AND AH_MOVIMIENTOS_HIS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
              AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
              AND GE_TRANSACCIONES.TIPO IN ('C','D')
              AND NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B';

        -- SDC - AP 897/8 - Ingresa solo si no hay movimientos entonces busca si existe movimiento por bloqueo
        -- Aqui no se incluyen los Bloqueos para Act. el Sal Anterior.

        -- Se comenta para que ya no incluyan los desbloqueos. CB. 25/09/2013
        /*if nvl(v_cantidad,0) = 0 then
        SELECT SUM(DECODE(GE_TRANSACCIONES.cod_transaccion, 515, 0, 560, 0,
                          decode(GE_TRANSACCIONES.TIPO,'D',NVL(AH_MOVIMIENTOS_HIS.MONTO,0),0))),
               SUM(DECODE(GE_TRANSACCIONES.cod_transaccion, 515, NVL(AH_MOVIMIENTOS_HIS.MONTO,0), 560, NVL(AH_MOVIMIENTOS_HIS.MONTO,0),
                          decode(GE_TRANSACCIONES.TIPO,'C',NVL(AH_MOVIMIENTOS_HIS.MONTO,0),0))),
               COUNT('X')
            INTO v_mto_deb, v_mto_cre, v_can
            FROM GE_TRANSACCIONES, AH_MOVIMIENTOS_HIS
            WHERE AH_MOVIMIENTOS_HIS.COD_MODULO = AV.COD_MODULO
              AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = AV.COD_MODALIDAD
              AND AH_MOVIMIENTOS_HIS.COD_OFICINA = AV.COD_OFICINA
              AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = AV.NRO_CUENTA
              AND AH_MOVIMIENTOS_HIS.FECHA > v_fec_movimiento
              AND AH_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
              AND (AH_MOVIMIENTOS_HIS.REVERSADO = 'N' or
                  (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' and FECHA <= v_fec_movimiento))
              AND AH_MOVIMIENTOS_HIS.ESTADO = 'N'
              AND AH_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
              AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
              AND AH_MOVIMIENTOS_HIS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
              AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
              AND GE_TRANSACCIONES.TIPO IN ('C','D')
              AND (NVL(GE_TRANSACCIONES.AFECTA,'XX') = 'B'
                     AND AH_MOVIMIENTOS_HIS.COD_CAUSA IN
                           (select cod_causa
                              from ge_par_causales
                             where parametro = 'COD_CAU_BLO_EXT'
                               and val_parametro = 'S' )
                     OR NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B' );
        end if;*/
          IF nvl(V_CANTIDAD,0) > 0 or nvl(v_can,0) > 0 THEN
             V_TIENE_MOV := 'S';
          END IF;
            V_EXISTE := 'N';
            --IF AV.SEPARADO = 'S' OR AV.COD_PAQUETE > 0 THEN--CROGENEXT-13 Sergio Servín 06/08/2014
            IF AV.SEPARADO = 'I' OR AV.COD_PAQUETE > 0 THEN
            --
               -- es una direccion especifica, no enviar en ext.unico --
               v_cod_ext_separado := v_cod_ext_separado + 1;
               v_cod_extracto     := v_cod_ext_separado;
               ---------------------------------------------------------
            ELSE
               v_cod_extracto     := 1;
               --- verifico si ya existe una cabecera del extracto unico
               BEGIN
                 SELECT 'S' INTO V_EXISTE
                   FROM GE_EXT_CLIENTES
                  WHERE GE_EXT_CLIENTES.COD_PERSONA = v_cod_persona
                    AND GE_EXT_CLIENTES.COD_EXTRACTO = v_cod_extracto
                    AND GE_EXT_CLIENTES.FEC_EXTRACTO = v_fec_actual
                    AND GE_EXT_CLIENTES.FRE_EXTRACTO = v_frecuencia;
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
               v_imprime_extracto := v_tip_extracto;
               v_lugar := '1-insert GE_EXT_CLIENTES '||v_cod_persona||'-'||v_dir_cliente;
               INSERT INTO GE_EXT_CLIENTES (COD_PERSONA, FEC_EXTRACTO, FRE_EXTRACTO,
                                    FUNCIONARIO, NOM_CLIENTE, DIRECCION,
                                    TELEFONO, COD_USU_OFICIAL, COD_PAIS,
                                    COD_CIUDAD, TEL_OFICIAL, NRO_INTERNO,
                                    COD_EXTRACTO, DET_DIRECCION, OBSERVACION,
                                    BARRIO, COD_MENSAJE, tip_impresion,
                                    CLI_CONFIDENCIAL, COD_OFICINA,
                                    cat_riesgo,Fec_Ult_Clasif,Cod_Per_Empresa,
                                    tip_direccion )
                            VALUES (v_cod_persona, v_fec_actual,
                                    v_frecuencia,v_es_empleado,
                                    v_nom_cliente, v_dir_cliente,
                                    v_tel_cliente, v_cod_usu_oficial,
                                    v_cod_pais, v_cod_ciudad,
                                    v_tel_oficial, v_int_oficial,v_cod_extracto,
                                    v_pri_obs_dir, v_seg_obs_dir,
                                    v_des_barrio, '1', v_imprime_extracto,
                                    v_cli_confidencial, decode(AV.SEPARADO,'I',av.cod_oficina,v_cod_ofi_cliente),
                                    v_cat_riesgo, v_fec_ult_clasif,v_cod_per_ente,
                                    v_tip_envio);
               v_INSERTA := 'S';
            END IF;
            v_lugar := 'Cta.combinada';
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
            v_lugar := 'Saldo promedio';
            --obtiene saldo promedio
            pag_cta.PR_OBT_SAL_PROMEDIO(av.COD_MODULO,av.COD_MODALIDAD,av.COD_OFICINA,
                    av.NRO_CUENTA,v_fec_actual,v_fec_actual, v_SAL_ACUMULADO, v_SAL_PROMEDIO,v_CAN_DIA_ACUMULADO);
            v_lugar := 'Obtener Tasa';
            --- cargo los valores para el calculo de la tasa --
            v_val_tasa := fug_obt_val_tasa(av.cod_modulo, av.cod_modalidad, av.cod_oficina, av.nro_cuenta, av.cod_moneda, v_SAL_PROMEDIO, av.tas_personalizada,
                          av.cod_tasa, null, v_fec_actual);

            --obtiene tae
            v_lugar := 'Tae';
            v_val_tae := pas_bcp.FU_OBT_TAE(v_val_tasa,30);
            ----------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
            ----------------------------------------------------
            v_sal_blo_anterior := lf_obt_sal_blo_anterior(av.NRO_CUENTA,av.fec_ult_extracto);
            INSERT INTO GE_EXT_CLI_CUENTAS (GE_EXT_CLI_CUENTAS.COD_PERSONA, GE_EXT_CLI_CUENTAS.FEC_EXTRACTO, GE_EXT_CLI_CUENTAS.TIP_CUENTA,
                                 GE_EXT_CLI_CUENTAS.COD_OFICINA, GE_EXT_CLI_CUENTAS.COD_MODALIDAD, GE_EXT_CLI_CUENTAS.NRO_CUENTA,
                                 GE_EXT_CLI_CUENTAS.COD_MONEDA, GE_EXT_CLI_CUENTAS.SAL_ANTERIOR, GE_EXT_CLI_CUENTAS.SAL_ACTUAL,
                                 GE_EXT_CLI_CUENTAS.NRO_FOLIO, GE_EXT_CLI_CUENTAS.SAL_A_CONFIRMAR, GE_EXT_CLI_CUENTAS.COD_EXTRACTO,
                                 GE_EXT_CLI_CUENTAS.FRE_EXTRACTO, Sal_Promedio, Nro_Cta_Combinada, Tas_Nominal, tas_efectiva,
                                 GE_EXT_CLI_CUENTAS.SAL_BLOQUEADO, GE_EXT_CLI_CUENTAS.Cod_Per_Empresa, sal_blo_anterior)
                         VALUES (v_cod_persona,  v_fec_actual, 'A',
                                 AV.COD_OFICINA,AV.COD_MODALIDAD,AV.NRO_CUENTA,
                                 AV.COD_MONEDA, v_sal_ult_extracto,
                                 NVL(v_sal_ult_extracto,0) + NVL(v_mto_credito,0) -
                                                     NVL(v_mto_debito,0),
                                 AV.NRO_FOLIO, AV.SAL_RET_BATCH, v_cod_extracto,
                                 v_frecuencia, v_SAL_PROMEDIO, v_nro_cta_combinada, v_val_tasa, v_val_tae,
                                 v_mto_bloqueo, v_cod_per_ente, v_sal_blo_anterior);
            lp_generar_mov_retenciones(av.nro_cuenta);
            lp_generar_mov_pendientes(av.nro_cuenta);
           -- Si es Fin de Mes Actualizar el Saldo Mensual Actual.
           IF v_frecuencia = 'M' THEN
             BEGIN
               UPDATE AH_SAL_MENSUALES
                  SET SAL_ULT_EXTRACTO = NVL(v_sal_ult_extracto,0) + NVL(v_mto_credito,0) -
                                         NVL(v_mto_debito,0)
                WHERE NRO_CUENTA = AV.NRO_CUENTA
                  AND ANO        = TO_NUMBER(TO_CHAR(v_fec_actual,'YYYY'))
                  AND MES        = TO_NUMBER(TO_CHAR(v_fec_actual,'MM'));

             EXCEPTION
               WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20003,'Error al Actualizar el Saldo Mensual en CTA.VISTAS. '||sqlerrm);
             END;
            END IF;

            IF V_TIENE_MOV = 'S' THEN
               --------------------------------------------
               -- INSERTA REGISTRO EN EL ARCHIVO DETALLE --
               --------------------------------------------
               INSERT INTO GE_EXT_CLI_MOVIMIENTOS (COD_PERSONA, FEC_EXTRACTO, FEC_MOVIMIENTO,
                                    FEC_VALOR, HOR_MOVIMIENTO, NRO_CUENTA,
                                    NRO_DOCUMENTO, COD_MODULO, COD_MODALIDAD,
                                    COD_TRA_PADRE, MTO_DEBITO, MTO_CREDITO,
                                    COD_EXTRACTO, FRE_EXTRACTO, NRO_SECUENCIA, cod_ofi_origen,
                                    Fec_Insercion, ind_bloqueo)
               SELECT  v_cod_persona, v_fec_actual,
                       AH_MOVIMIENTOS_HIS.FECHA, AH_MOVIMIENTOS_HIS.FEC_VALOR, AH_MOVIMIENTOS_HIS.HORA, AH_MOVIMIENTOS_HIS.NRO_CUENTA,
                       AH_MOVIMIENTOS_HIS.NRO_DOCUMENTO, AH_MOVIMIENTOS_HIS.COD_MOD_PADRE, AH_MOVIMIENTOS_HIS.COD_MAD_PADRE, AH_MOVIMIENTOS_HIS.COD_TRA_PADRE,

                       (DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta),'D',NVL(AH_MOVIMIENTOS_HIS.MONTO,0),0)),
                       (DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta),'C',NVL(AH_MOVIMIENTOS_HIS.MONTO,0),0)),

                       v_cod_extracto, v_frecuencia, AH_MOVIMIENTOS_HIS.NRO_SECUENCIA, ah_movimientos_his.cod_ofi_origen, ah_movimientos_his.fec_insercion,
                       decode(ge_transacciones.afecta, 'B', 'S', 'N')
                 FROM GE_TRANSACCIONES, AH_MOVIMIENTOS_HIS
               WHERE AH_MOVIMIENTOS_HIS.COD_MODULO = AV.COD_MODULO
                 AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = AV.COD_MODALIDAD
                 AND AH_MOVIMIENTOS_HIS.COD_OFICINA = AV.COD_OFICINA
                 AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = AV.NRO_CUENTA
                 AND AH_MOVIMIENTOS_HIS.FECHA > v_fec_movimiento
                 AND AH_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
                 AND(AH_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
                    (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
                     FEC_VALOR <= v_fec_movimiento   AND
                     EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                              WHERE AH_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
                                AND AH_MOVIMIENTOS_HIS.HOR_REVERSION  = REV.HORA
                                AND AH_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
                                AND AH_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                                -- DYDMR-5672 NAF 01/2017
                                AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
                                AND abs(AH_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO)
                          )) OR
                   (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND AH_MOVIMIENTOS_HIS.COD_TRA_PADRE = 303
                    AND AH_MOVIMIENTOS_HIS.Cod_Mad_Padre = 455))
                 AND AH_MOVIMIENTOS_HIS.ESTADO = 'N'
                 AND AH_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                 AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                 AND AH_MOVIMIENTOS_HIS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                 AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                 AND GE_TRANSACCIONES.TIPO IN ('C','D')
                 AND NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B';

               IF SQL%FOUND THEN
		--DESOPIMI-14 - Optimizar el proceso PRG_GEN_EXTRACTO (Generación Datos para Extracto) - DYD-SDSL-3162	       
                INSERT INTO GE_CTA_EXTRACTOS_TMP (
                                        NRO_CUENTA, COD_MODULO, COD_MODALIDAD,
                                        NRO_FOLIO, FEC_ULT_EXTRACTO, SAL_ULT_EXTRACTO,
                                        NOM_TABLA, COD_PERSONA)
                                VALUES (AV.NRO_CUENTA, AV.COD_MODULO, AV.COD_MODALIDAD,
                                        AV.NRO_FOLIO, v_fec_actual, NVL(v_sal_ult_extracto,0) +
                                        NVL(v_mto_credito,0) - NVL(v_mto_debito,0),
                                        'AH_CTA_VISTAS', V_COD_PERSONA); --AP 3015
               END IF;

            END IF;
           --END IF;
         END LOOP;
   end lp_generar_vistas;
   --
   procedure lp_generar_plazos is
   begin
      null;
   end lp_generar_plazos;
   --
   procedure lp_generar_certificados is
      ----------------------------------
      -- CURSOR DEL ARCHIVO PRINCIPAL --
      ----------------------------------
      CURSOR MAE_CUE IS
      SELECT GE_CTA_CLIENTES.COD_MODULO, GE_CTA_CLIENTES.COD_MODALIDAD, GE_CTA_CLIENTES.COD_OFICINA, GE_CTA_CLIENTES.NRO_CUENTA,
             AH_CTA_CERTIFICADOS.COD_MONEDA, AH_CTA_CERTIFICADOS.TAS_PERSONALIZADA, AH_CTA_CERTIFICADOS.COD_TASA, AH_CTA_CERTIFICADOS.CAPITAL,
             AH_CTA_CERTIFICADOS.FEC_VENCIMIENTO, AH_CTA_CERTIFICADOS.SAL_RET_BATCH,
             AH_CTA_CERTIFICADOS.SAL_TOT_BATCH, AH_CTA_CERTIFICADOS.FEC_APERTURA,
             fue_obt_titulo(AH_CTA_CERTIFICADOS.BENEFICIARIO) DENOMINACION,
             ah_cta_certificados.tip_capitalizacion ,
             ah_cta_certificados.est_cer_batch, AH_CTA_CERTIFICADOS.SAL_BLOQUEADO, GE_CTA_CLIENTES.cod_persona
        FROM AH_CTA_CERTIFICADOS, GE_CTA_CLIENTES/*,ba_per_dat_adicionales bpd1*/
       WHERE GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
         AND GE_CTA_CLIENTES.COD_MODALIDAD = v_cod_modalidad
         AND GE_CTA_CLIENTES.RELACION = 'P'
         AND AH_CTA_CERTIFICADOS.COD_MODULO = GE_CTA_CLIENTES.COD_MODULO
         AND AH_CTA_CERTIFICADOS.COD_MODALIDAD = GE_CTA_CLIENTES.COD_MODALIDAD
         AND AH_CTA_CERTIFICADOS.COD_OFICINA = GE_CTA_CLIENTES.COD_OFICINA
         AND AH_CTA_CERTIFICADOS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
         AND AH_CTA_CERTIFICADOS.EST_BATCH NOT IN ('C','T')
         AND NVL(AH_CTA_CERTIFICADOS.SAL_TOT_BATCH,0) > 0;

         --CROGENEXT-13 Sergio Servín 06/08/2014
         --AND fue_per_dat_adicional(GE_CTA_CLIENTES.COD_PERSONA,'FRE_EXTRACTOS') = v_frecuencia;
         --and bpd1.cod_persona = GE_CTA_CLIENTES.COD_PERSONA
         --and bpd1.parametro  = 'FRE_EXTRACTOS'
         --and bpd1.val_parametro = v_frecuencia;
         --
     v_val_tasa ge_tas_fechas.val_tasa%type;
     v_val_tae  ge_tas_fechas.val_tasa%type;
     v_fec_vencimiento ah_cupones.fec_vencimiento%type;
     v_mto_interes     ah_cupones.mto_interes%Type;
     --v_can_mes number;--CROGENEXT-13 Sergio Servín 06/08/2014
     --v_tot_mes number;--CROGENEXT-13 Sergio Servín 06/08/2014
     --v_cod_persona_ext ba_personas.cod_persona%type := p_cod_persona; --CROGENEXT-13 Sergio Servín 06/08/2014
      BEGIN
        FOR CD IN MAE_CUE LOOP
         --CROGENEXT-13 Sergio Servín 06/08/2014
         --Para Obtener la cantidad de mes desde el último extracto emitido
         /*v_can_mes := round ((v_fec_actual -
         to_date(fue_per_dat_adicional(CD.COD_PERSONA,'FEC_ULT_EXTRACTOS'),'DD/MM/YYYY'))/30);
         if v_frecuencia = 'M' then
              v_tot_mes := 1;
         else
              v_tot_mes := 3;
         end if;

         if v_can_mes = 1 and v_frecuencia = 'M' or v_can_mes = 3 and v_frecuencia = 'T' then*/


            --limpio variables
            v_mto_interes := null;
            v_fec_vencimiento := null;
            --- cargo los valores para el calculo de la tasa --
            v_val_tasa := fug_obt_val_tasa(cd.cod_modulo, cd.cod_modalidad, cd.cod_oficina, cd.nro_cuenta, cd.cod_moneda, cd.capital, cd.tas_personalizada,
                          cd.cod_tasa, null, v_fec_actual);
            --obtiene tae
            v_val_tae := pas_bcp.FU_OBT_TAE_CDA(cd.tip_capitalizacion,v_val_tasa, cd.fec_vencimiento - cd.fec_apertura, cd.CAPITAL);
            v_mto_bloqueo := lf_obt_mto_bloqueado(cd.nro_cuenta);
            ----------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
            ----------------------------------------------------
            INSERT INTO GE_EXT_CLI_CUENTAS (GE_EXT_CLI_CUENTAS.COD_PERSONA, GE_EXT_CLI_CUENTAS.FEC_EXTRACTO, GE_EXT_CLI_CUENTAS.TIP_CUENTA,
                                 GE_EXT_CLI_CUENTAS.COD_OFICINA, GE_EXT_CLI_CUENTAS.COD_MODALIDAD, GE_EXT_CLI_CUENTAS.NRO_CUENTA,
                                 GE_EXT_CLI_CUENTAS.COD_MONEDA, GE_EXT_CLI_CUENTAS.SAL_ACTUAL, GE_EXT_CLI_CUENTAS.SAL_A_CONFIRMAR,
                                 GE_EXT_CLI_CUENTAS.COD_EXTRACTO, GE_EXT_CLI_CUENTAS.FRE_EXTRACTO, Tas_Nominal, tas_efectiva,
                                 GE_EXT_CLI_CUENTAS.SAL_BLOQUEADO)
                         VALUES (v_cod_persona, v_fec_actual, 'A',
                                 CD.COD_OFICINA, CD.COD_MODALIDAD,
                                 CD.NRO_CUENTA, CD.COD_MONEDA,
                                 CD.SAL_TOT_BATCH, CD.SAL_RET_BATCH, 1,
                                 v_frecuencia, v_val_tasa, v_val_tae,
                                 v_mto_bloqueo);
            --lp_generar_mov_retenciones(CD.NRO_CUENTA);
            -------------------------------------------------------
            -- CALCULA interes del sgte cupon --
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
            INSERT INTO GE_EXT_RESUMENES (GE_EXT_RESUMENES.COD_PERSONA, GE_EXT_RESUMENES.FEC_EXTRACTO, GE_EXT_RESUMENES.TIPO,
                                 GE_EXT_RESUMENES.NRO_CUENTA, GE_EXT_RESUMENES.MTO_CAPITAL, GE_EXT_RESUMENES.MTO_INTERES,
                                 GE_EXT_RESUMENES.FEC_VENCIMIENTO, GE_EXT_RESUMENES.COD_EXTRACTO, GE_EXT_RESUMENES.FRE_EXTRACTO,
                                 GE_EXT_RESUMENES.FEC_INICIO, GE_EXT_RESUMENES.BENEFICIARIO, Cod_Modalidad, cod_moneda)
                         VALUES (v_cod_persona, v_fec_actual,
                                 DECODE(CD.COD_MODALIDAD,33,'2','6'),
                                 CD.NRO_CUENTA, decode(cd.est_cer_batch,'P',0,CD.CAPITAL),
                                 v_mto_interes, v_fec_vencimiento, 1,
                                 v_frecuencia, CD.FEC_APERTURA, CD.DENOMINACION, cd.cod_modalidad, cd.cod_moneda);
         --END IF;
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
             PR_CTA_PRESTAMOS.COD_MONEDA, NVL(PR_CTA_PRESTAMOS.SAL_CAPITAL,0) + NVL(PR_CTA_PRESTAMOS.SAL_INT_ADELANTADO,0) + NVL(SAL_INTERES,0) saldo_capital, GE_CTA_CLIENTES.COD_PERSONA
        FROM PR_CTA_PRESTAMOS, GE_CTA_CLIENTES/*, ba_per_dat_adicionales bpd1*/
       WHERE GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
         AND GE_CTA_CLIENTES.RELACION = 'P'
         AND PR_CTA_PRESTAMOS.COD_MODULO = GE_CTA_CLIENTES.COD_MODULO
         AND PR_CTA_PRESTAMOS.COD_MODALIDAD = GE_CTA_CLIENTES.COD_MODALIDAD
         AND PR_CTA_PRESTAMOS.COD_OFICINA = GE_CTA_CLIENTES.COD_OFICINA
         AND PR_CTA_PRESTAMOS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
         AND PR_CTA_PRESTAMOS.ESTADO <> 'N'
         AND PR_CTA_PRESTAMOS.COD_MODALIDAD <> 699;
         --CROGENEXT-13 Sergio Servín 06/08/2014
         --AND fue_per_dat_adicional(GE_CTA_CLIENTES.COD_PERSONA,'FRE_EXTRACTOS') = v_frecuencia;
         --and bpd1.cod_persona = GE_CTA_CLIENTES.COD_PERSONA
         --and bpd1.parametro  = 'FRE_EXTRACTOS'
         --and bpd1.val_parametro = v_frecuencia;
         --
        V_INSERTAR VARCHAR2(01);
v_val_tasa ge_tas_fechas.val_tasa%type;
v_val_tae  ge_tas_fechas.val_tasa%type;
--v_can_mes number;--CROGENEXT-13 Sergio Servín 06/08/2014
--v_tot_mes number;--CROGENEXT-13 Sergio Servín 06/08/2014
      BEGIN
         FOR PR IN MAE_CUE LOOP
           --CROGENEXT-13 Sergio Servín 06/08/2014
           --Para Obtener la cantidad de mes desde el último extracto emitido
           /*v_can_mes := round ((v_fec_actual -
           to_date(fue_per_dat_adicional(PR.COD_PERSONA,'FEC_ULT_EXTRACTOS'),'DD/MM/YYYY'))/30);
           if v_frecuencia = 'M' then
                v_tot_mes := 1;
           else
                v_tot_mes := 3;
           end if;

           if v_can_mes = 1 and v_frecuencia = 'M' or v_can_mes = 3 and v_frecuencia = 'T' then*/

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
            INSERT INTO GE_EXT_CLI_CUENTAS (GE_EXT_CLI_CUENTAS.COD_PERSONA, GE_EXT_CLI_CUENTAS.FEC_EXTRACTO, GE_EXT_CLI_CUENTAS.TIP_CUENTA,
                                 GE_EXT_CLI_CUENTAS.COD_OFICINA, GE_EXT_CLI_CUENTAS.COD_MODALIDAD, GE_EXT_CLI_CUENTAS.NRO_CUENTA,
                                 GE_EXT_CLI_CUENTAS.COD_MONEDA, GE_EXT_CLI_CUENTAS.SAL_ACTUAL, GE_EXT_CLI_CUENTAS.COD_EXTRACTO,
                                 GE_EXT_CLI_CUENTAS.FRE_EXTRACTO, Tas_Nominal, Tas_Efectiva,
                                 GE_EXT_CLI_CUENTAS.SAL_BLOQUEADO)
                         VALUES (v_cod_persona,  v_fec_actual, 'P',
                                 PR.COD_OFICINA, PR.COD_MODALIDAD, PR.NRO_CUENTA,
                                 PR.COD_MONEDA, PR.saldo_capital, 1,
                                 v_frecuencia, v_val_tasa, v_val_tae,0);
            ---------------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO RESUMEN DE PRESTAMOS --
            ---------------------------------------------------------
            INSERT INTO GE_EXT_RESUMENES (GE_EXT_RESUMENES.COD_PERSONA, GE_EXT_RESUMENES.FEC_EXTRACTO, GE_EXT_RESUMENES.TIPO,
                                 GE_EXT_RESUMENES.NRO_CUENTA, GE_EXT_RESUMENES.MTO_CAPITAL, GE_EXT_RESUMENES.MTO_INTERES,
                                 GE_EXT_RESUMENES.FEC_VENCIMIENTO, GE_EXT_RESUMENES.COD_EXTRACTO, GE_EXT_RESUMENES.FRE_EXTRACTO,
                                 GE_EXT_RESUMENES.SAL_DISPONIBLE, Cod_Modalidad, cod_moneda)
                         VALUES (v_cod_persona, v_fec_actual, '3',
                                 PR.NRO_CUENTA, PR.TOT_PRESTAMO, v_sal_capital,
                                 v_fec_vencimiento, 1, v_frecuencia, pr.saldo_capital, pr.cod_modalidad, pr.cod_moneda);
            END IF;
            --END IF;
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
            INSERT INTO GE_EXT_CLI_CUENTAS (GE_EXT_CLI_CUENTAS.COD_PERSONA, GE_EXT_CLI_CUENTAS.FEC_EXTRACTO, GE_EXT_CLI_CUENTAS.TIP_CUENTA,
                                 GE_EXT_CLI_CUENTAS.COD_OFICINA, GE_EXT_CLI_CUENTAS.COD_MODALIDAD, GE_EXT_CLI_CUENTAS.NRO_CUENTA,
                                 GE_EXT_CLI_CUENTAS.COD_MONEDA, GE_EXT_CLI_CUENTAS.SAL_ACTUAL, GE_EXT_CLI_CUENTAS.COD_EXTRACTO,
                                 GE_EXT_CLI_CUENTAS.FRE_EXTRACTO, Tas_Nominal, Tas_Efectiva)
                         VALUES (v_cod_persona,  v_fec_actual, 'P',
                                 TA.COD_OFICINA,TA.COD_MODALIDAD,TA.NRO_TARJETA,
                                 TA.COD_MONEDA,TA.SAL_ULT_EXTRACTO, 1,
                                 v_frecuencia, v_val_tasa, v_val_tae);
            ---------------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO RESUMEN DE TARJETAS --
            ---------------------------------------------------------
            INSERT INTO GE_EXT_RESUMENES (GE_EXT_RESUMENES.COD_PERSONA, GE_EXT_RESUMENES.FEC_EXTRACTO, GE_EXT_RESUMENES.TIPO,
                                 GE_EXT_RESUMENES.NRO_CUENTA, GE_EXT_RESUMENES.MTO_CAPITAL, GE_EXT_RESUMENES.MTO_INTERES,
                                 GE_EXT_RESUMENES.FEC_VENCIMIENTO, GE_EXT_RESUMENES.COD_EXTRACTO, GE_EXT_RESUMENES.FRE_EXTRACTO,
                                 GE_EXT_RESUMENES.SAL_DISPONIBLE, cod_modalidad, cod_moneda)
                         VALUES (v_cod_persona, v_fec_actual, '4',
                                 TA.nro_tarjeta, TA.mto_pag_minimo, TA.sal_disponible,
                                 TA.fec_vct_ult_cierre, 1, v_frecuencia, TA.SALDO, ta.cod_modalidad, ta.cod_moneda);
         END LOOP;
   end lp_generar_tarjetas;

   --
   procedure lp_act_tip_mensaje is
   begin
      -- Debe actualizar de acuerdo a los sqls
      null;
   end lp_act_tip_mensaje;

   PROCEDURE lp_act_nro_control IS
       Cursor c1 is Select GE_EXT_CLIENTES.COD_USU_OFICIAL OFICIAL, rowid registro
                      From GE_EXT_CLIENTES
                     Where GE_EXT_CLIENTES.FEC_EXTRACTO = v_fec_actual
                       and GE_EXT_CLIENTES.FRE_EXTRACTO = v_frecuencia
                       and (cod_persona = p_cod_persona or p_cod_persona is null)
                       and GE_EXT_CLIENTES.TIP_IMPRESION in ('C', 'S', 'X')
                     Order by GE_EXT_CLIENTES.COD_USU_OFICIAL, GE_EXT_CLIENTES.COD_PAIS, GE_EXT_CLIENTES.COD_CIUDAD,
                              upper(GE_EXT_CLIENTES.BARRIO), ltrim(upper(GE_EXT_CLIENTES.DIRECCION));
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
         Update GE_EXT_CLIENTES
            set NRO_CONTROL = v_Cantidad
          where rowid = r1.registro;
      End Loop;
   END;
   procedure lp_mar_ext_con_diferencia is
    BEGIN
       v_lugar := 'lp_mar_ext_con_diferencia';
       --- actualiza con lower (minuscula las cuentas que tuvieron dif. ---
       --- para que no imprima con los demas extractos --------------------
       UPDATE GE_EXT_CLIENTES
          SET GE_EXT_CLIENTES.FRE_EXTRACTO = LOWER(GE_EXT_CLIENTES.FRE_EXTRACTO)
        WHERE GE_EXT_CLIENTES.FEC_EXTRACTO = v_fec_actual
          AND GE_EXT_CLIENTES.FRE_EXTRACTO = v_frecuencia
          and (cod_persona = p_cod_persona or p_cod_persona is null)
          AND EXISTS (SELECT 0
                        FROM GE_EXT_CLI_CUENTAS,AH_CTA_VISTAS
                       WHERE GE_EXT_CLI_CUENTAS.COD_PERSONA = GE_EXT_CLIENTES.COD_PERSONA
                         AND GE_EXT_CLI_CUENTAS.COD_EXTRACTO = GE_EXT_CLIENTES.COD_EXTRACTO
                         AND GE_EXT_CLI_CUENTAS.FEC_EXTRACTO = GE_EXT_CLIENTES.FEC_EXTRACTO
                         AND GE_EXT_CLI_CUENTAS.FRE_EXTRACTO = GE_EXT_CLIENTES.FRE_EXTRACTO
                         AND AH_CTA_VISTAS.COD_MODULO = 3
                         AND AH_CTA_VISTAS.COD_MODALIDAD = GE_EXT_CLI_CUENTAS.COD_MODALIDAD
                         AND AH_CTA_VISTAS.COD_OFICINA = GE_EXT_CLI_CUENTAS.COD_OFICINA
                         AND AH_CTA_VISTAS.NRO_CUENTA = GE_EXT_CLI_CUENTAS.NRO_CUENTA
                         AND AH_CTA_VISTAS.FEC_ULT_EXTRACTO = v_fec_actual
                         AND (NVL(AH_CTA_VISTAS.SAL_ULT_EXTRACTO,0) <>
                              NVL(AH_CTA_VISTAS.SAL_TOTAL,0) - NVL(AH_CTA_VISTAS.SAL_RETENIDO,0) OR
                              NVL(AH_CTA_VISTAS.SAL_ULT_EXTRACTO,0) <>
                              NVL(AH_CTA_VISTAS.SAL_TOT_BATCH,0) - NVL(AH_CTA_VISTAS.SAL_RET_BATCH,0)));
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003,'Error al marcar diferencias '||sqlerrm);
   end;
   procedure lp_mar_ext_con_dif_detalle is
    CURSOR DIFEREN IS
        SELECT GE_EXT_CLI_CUENTAS.COD_PERSONA, GE_EXT_CLI_CUENTAS.COD_EXTRACTO
          FROM GE_TRANSACCIONES, GE_EXT_CLI_MOVIMIENTOS, GE_EXT_CLI_CUENTAS
         WHERE GE_TRANSACCIONES.COD_MODULO = GE_EXT_CLI_MOVIMIENTOS.COD_MODULO
           and GE_TRANSACCIONES.COD_MODALIDAD = GE_EXT_CLI_MOVIMIENTOS.COD_MODALIDAD
           and GE_TRANSACCIONES.COD_TRANSACCION = GE_EXT_CLI_MOVIMIENTOS.COD_TRA_PADRE
           and GE_EXT_CLI_MOVIMIENTOS.COD_PERSONA = GE_EXT_CLI_CUENTAS.COD_PERSONA
           AND GE_EXT_CLI_MOVIMIENTOS.COD_EXTRACTO = GE_EXT_CLI_CUENTAS.COD_EXTRACTO
           AND GE_EXT_CLI_MOVIMIENTOS.FEC_EXTRACTO = GE_EXT_CLI_CUENTAS.FEC_EXTRACTO
           AND GE_EXT_CLI_MOVIMIENTOS.NRO_CUENTA = GE_EXT_CLI_CUENTAS.NRO_CUENTA
           AND GE_EXT_CLI_CUENTAS.FEC_EXTRACTO = v_fec_actual
           AND GE_EXT_CLI_CUENTAS.FRE_EXTRACTO = v_frecuencia
           AND GE_EXT_CLI_CUENTAS.TIP_CUENTA = 'A'
           and (GE_EXT_CLI_CUENTAS.COD_PERSONA = P_COD_PERSONA OR P_COD_PERSONA IS NULL)
           --WA:08/08/2014 Se agrega 49 para financiera Pais
           AND GE_EXT_CLI_CUENTAS.COD_MODALIDAD IN (31,41,42,48,49)
           AND NVL(GE_EXT_CLI_MOVIMIENTOS.IND_BLOQUEO, 'N') = 'N'
           --WA:08/08/2014 Se agrega 49 para financiera Pais
         GROUP BY GE_EXT_CLI_CUENTAS.COD_PERSONA, GE_EXT_CLI_CUENTAS.COD_EXTRACTO, GE_EXT_CLI_CUENTAS.FEC_EXTRACTO, GE_EXT_CLI_CUENTAS.NRO_CUENTA,
                  GE_EXT_CLI_CUENTAS.COD_MODALIDAD, GE_EXT_CLI_CUENTAS.SAL_ANTERIOR, GE_EXT_CLI_CUENTAS.SAL_ACTUAL
       HAVING DECODE(GE_EXT_CLI_CUENTAS.COD_MODALIDAD,42,GE_EXT_CLI_CUENTAS.SAL_ANTERIOR*-1, 48,GE_EXT_CLI_CUENTAS.SAL_ANTERIOR*-1,49,GE_EXT_CLI_CUENTAS.SAL_ANTERIOR*-1,GE_EXT_CLI_CUENTAS.SAL_ANTERIOR) +
        (SUM(GE_EXT_CLI_MOVIMIENTOS.MTO_CREDITO) - SUM(GE_EXT_CLI_MOVIMIENTOS.MTO_DEBITO))
         != DECODE(GE_EXT_CLI_CUENTAS.COD_MODALIDAD,42,GE_EXT_CLI_CUENTAS.SAL_ACTUAL*-1,48,GE_EXT_CLI_CUENTAS.SAL_ACTUAL*-1,49,GE_EXT_CLI_CUENTAS.SAL_ACTUAL*-1,GE_EXT_CLI_CUENTAS.SAL_ACTUAL);
    BEGIN
      v_lugar := 'lp_mar_ext_con_dif_detalle';
      FOR CA IN DIFEREN LOOP
        UPDATE GE_EXT_CLIENTES
           SET GE_EXT_CLIENTES.FRE_EXTRACTO = LOWER(GE_EXT_CLIENTES.FRE_EXTRACTO)
         WHERE GE_EXT_CLIENTES.COD_PERSONA = CA.COD_PERSONA
           AND GE_EXT_CLIENTES.COD_EXTRACTO = CA.COD_EXTRACTO
           AND GE_EXT_CLIENTES.FEC_EXTRACTO = v_fec_actual
           AND GE_EXT_CLIENTES.FRE_EXTRACTO = v_frecuencia;
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20004,'Error al marcar dif. detalle '||sqlerrm);
   end lp_mar_ext_con_dif_detalle;

   procedure lp_act_tip_impresion is
   Begin
      v_lugar := 'LP_ACT_TIP_IMPRESION';
      ----------------------------------------------
      -- BORRA CABECERA ACTIVO PASIVO DEL CLIENTE --
      ----------------------------------------------
       UPDATE GE_EXT_CLIENTES A
          SET A.TIP_IMPRESION = 'N'
       WHERE NOT EXISTS (SELECT 1 FROM GE_EXT_CLI_MOVIMIENTOS B, GE_EXT_CLI_CUENTAS C
                          WHERE B.COD_PERSONA = A.COD_PERSONA
                            AND B.COD_EXTRACTO = A.COD_EXTRACTO
                            AND B.FEC_EXTRACTO = A.FEC_EXTRACTO
                            AND C.COD_PERSONA = B.COD_PERSONA
                            AND C.COD_EXTRACTO = B.COD_EXTRACTO
                            AND C.FEC_EXTRACTO = B.FEC_EXTRACTO
                            AND C.FRE_EXTRACTO||'' = A.FRE_EXTRACTO
                            AND C.NRO_CUENTA = B.NRO_CUENTA)
         AND NOT EXISTS (SELECT 0 FROM GE_EXT_CLI_MOV_PENDIENTES X
                         WHERE X.COD_PERSONA = A.COD_PERSONA
                           AND X.FEC_EXTRACTO = A.FEC_EXTRACTO
                           AND X.FRE_EXTRACTO = A.FRE_EXTRACTO
                           AND X.COD_EXTRACTO = A.COD_EXTRACTO)
         AND A.FEC_EXTRACTO = v_fec_actual
         and a.fre_extracto = v_frecuencia
         AND (A.COD_PERSONA = P_COD_PERSONA OR P_COD_PERSONA IS NULL)
         and a.tip_impresion <> 'N';
   end;

   procedure lp_borrar_movimientos is
   Begin
      v_lugar := 'lp_borrar_movimientos';
      ----------------------------------------------
      -- BORRA CABECERA ACTIVO PASIVO DEL CLIENTE --
      ----------------------------------------------
       DELETE GE_EXT_CLIENTES A
       WHERE NOT EXISTS (SELECT 1 FROM GE_EXT_CLI_MOVIMIENTOS B, GE_EXT_CLI_CUENTAS C
                          WHERE B.COD_PERSONA = A.COD_PERSONA
                            AND B.COD_EXTRACTO = A.COD_EXTRACTO
                            AND B.FEC_EXTRACTO = A.FEC_EXTRACTO
                            AND C.COD_PERSONA = B.COD_PERSONA
                            AND C.COD_EXTRACTO = B.COD_EXTRACTO
                            AND C.FEC_EXTRACTO = B.FEC_EXTRACTO
                            AND C.FRE_EXTRACTO||'' = A.FRE_EXTRACTO
                            AND C.NRO_CUENTA = B.NRO_CUENTA)
         AND A.FEC_EXTRACTO = v_fec_actual
         and a.fre_extracto = v_frecuencia
         AND (A.COD_PERSONA = P_COD_PERSONA OR P_COD_PERSONA IS NULL);
      ----------------------------------------------
      -- BORRA CABECERA ACTIVO PASIVO DEL CLIENTE --
      ----------------------------------------------
      DELETE GE_EXT_CLI_CUENTAS A
       WHERE NOT EXISTS (SELECT 1 FROM GE_EXT_CLIENTES B
                          WHERE B.COD_PERSONA = A.COD_PERSONA
                            AND B.COD_EXTRACTO = A.COD_EXTRACTO
                            AND B.FEC_EXTRACTO = A.FEC_EXTRACTO
                            AND B.FRE_EXTRACTO = A.FRE_EXTRACTO)
         AND A.FEC_EXTRACTO = v_fec_actual
         and a.fre_extracto = v_frecuencia
         AND (A.COD_PERSONA = P_COD_PERSONA OR P_COD_PERSONA IS NULL);
      -------------------------------
      -- BORRA RESUMEN DEL CLIENTE --
      -------------------------------
      DELETE GE_EXT_RESUMENES A
       WHERE NOT EXISTS (SELECT 1 FROM GE_EXT_CLIENTES B
                          WHERE B.COD_PERSONA = A.COD_PERSONA
                            AND B.COD_EXTRACTO = A.COD_EXTRACTO
                            AND B.FEC_EXTRACTO = A.FEC_EXTRACTO
                           )
         AND A.FEC_EXTRACTO = v_fec_actual
         and a.fre_extracto = v_frecuencia
         AND (A.COD_PERSONA = P_COD_PERSONA OR P_COD_PERSONA IS NULL);
   end lp_borrar_movimientos;
   ---
   procedure lp_act_folio_ahorros is
      CURSOR CABECERA IS
         SELECT GE_EXT_CLI_CUENTAS.COD_MODALIDAD, GE_EXT_CLI_CUENTAS.COD_OFICINA, GE_EXT_CLI_CUENTAS.NRO_CUENTA,
                GE_EXT_CLI_CUENTAS.COD_PERSONA, GE_EXT_CLI_CUENTAS.COD_EXTRACTO, GE_EXT_CLI_CUENTAS.NRO_FOLIO,
                GE_EXT_CLI_CUENTAS.SAL_ACTUAL
           FROM GE_EXT_CLI_CUENTAS
          WHERE GE_EXT_CLI_CUENTAS.FEC_EXTRACTO = v_fec_actual
            AND GE_EXT_CLI_CUENTAS.FRE_EXTRACTO = v_frecuencia
            AND GE_EXT_CLI_CUENTAS.TIP_CUENTA = 'A'
            AND (COD_PERSONA = P_COD_PERSONA OR P_COD_PERSONA IS NULL)
            AND GE_EXT_CLI_CUENTAS.COD_MODALIDAD = 31;
   begin
      v_lugar := 'lp_act_folio_ahorros';
      FOR CA IN CABECERA LOOP
        -- actualizo los datos de la cuenta ---------------------------
        UPDATE AH_MOVIMIENTOS_HIS
          SET NRO_FOLIO = NVL(CA.NRO_FOLIO, 0)
        WHERE AH_MOVIMIENTOS_HIS.COD_MODULO = 3
          AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = CA.COD_MODALIDAD
          AND AH_MOVIMIENTOS_HIS.COD_OFICINA = CA.COD_OFICINA
          AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = CA.NRO_CUENTA
          AND AH_MOVIMIENTOS_HIS.FECHA >= v_pri_dia_mes_habil
          AND AH_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
          AND(AH_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
             (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
              FEC_VALOR < v_pri_dia_mes_habil    AND
              EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                       WHERE AH_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
                         AND AH_MOVIMIENTOS_HIS.HOR_REVERSION  = REV.HORA
                         AND AH_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
                         AND AH_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                         -- DYDMR-5672 NAF 01/2017
                         AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
                         AND abs(AH_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO)
                      )) OR
             (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND AH_MOVIMIENTOS_HIS.COD_TRA_PADRE = 303
              AND AH_MOVIMIENTOS_HIS.Cod_Mad_Padre = 455))
          AND AH_MOVIMIENTOS_HIS.ESTADO = 'N'
          AND AH_MOVIMIENTOS_HIS.NRO_FOLIO IS NULL;
      END LOOP;
   end lp_act_folio_ahorros;
   ---
   procedure lp_act_folio_ctactes is
      CURSOR CABECERA IS
         SELECT GE_EXT_CLI_CUENTAS.COD_MODALIDAD, GE_EXT_CLI_CUENTAS.COD_OFICINA, GE_EXT_CLI_CUENTAS.NRO_CUENTA,
                GE_EXT_CLI_CUENTAS.COD_PERSONA, GE_EXT_CLI_CUENTAS.COD_EXTRACTO, GE_EXT_CLI_CUENTAS.NRO_FOLIO,
                GE_EXT_CLI_CUENTAS.SAL_ACTUAL
           FROM GE_EXT_CLI_CUENTAS
          WHERE GE_EXT_CLI_CUENTAS.FEC_EXTRACTO = v_fec_actual
            AND GE_EXT_CLI_CUENTAS.FRE_EXTRACTO = v_frecuencia
            AND GE_EXT_CLI_CUENTAS.TIP_CUENTA in ('A','P') --para q tome sobregiradas
            AND (COD_PERSONA = P_COD_PERSONA OR P_COD_PERSONA IS NULL)
            AND GE_EXT_CLI_CUENTAS.COD_MODALIDAD BETWEEN 41 AND 49;
   begin
      v_lugar := 'lp_act_folio_ctactes';
      FOR CA IN CABECERA LOOP
        -- actualizo los datos de la cuenta ---------------------------
        UPDATE CC_MOVIMIENTOS_HIS
          SET NRO_FOLIO = NVL(CA.NRO_FOLIO, 0)
        WHERE CC_MOVIMIENTOS_HIS.COD_MODULO = 4
          AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = CA.COD_MODALIDAD
          AND CC_MOVIMIENTOS_HIS.COD_OFICINA = CA.COD_OFICINA
          AND CC_MOVIMIENTOS_HIS.NRO_CUENTA = CA.NRO_CUENTA
          AND CC_MOVIMIENTOS_HIS.FECHA >= v_pri_dia_mes_habil
          AND CC_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
          AND(CC_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
             (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
              CC_MOVIMIENTOS_HIS.FEC_VALOR < v_pri_dia_mes_habil AND
              EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                       WHERE CC_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
                         AND CC_MOVIMIENTOS_HIS.HOR_REVERSION  = REV.HORA
                         AND CC_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
                         AND CC_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                         -- DYDMR-5672 NAF 01/2017
                         AND CC_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
                         AND abs(CC_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO)
                      )) OR
             (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' AND CC_MOVIMIENTOS_HIS.COD_TRA_PADRE = 303
              AND CC_MOVIMIENTOS_HIS.COD_MAD_PADRE = 455))
          AND CC_MOVIMIENTOS_HIS.ESTADO = 'N'
          AND CC_MOVIMIENTOS_HIS.NRO_FOLIO IS NULL;
      END LOOP;
   end lp_act_folio_ctactes;
   ---
   procedure lp_gen_extracto is
   --- Define el cursor ---
   CURSOR MAE_CLI IS
      SELECT DISTINCT GE_CTA_CLIENTES.COD_PERSONA
        FROM GE_CUENTAS, GE_CTA_CLIENTES/*, ba_per_dat_adicionales bpd*/
       WHERE GE_CUENTAS.COD_MODULO = GE_CTA_CLIENTES.COD_MODULO
         AND GE_CUENTAS.COD_MODALIDAD = GE_CTA_CLIENTES.COD_MODALIDAD
         AND GE_CUENTAS.COD_OFICINA = GE_CTA_CLIENTES.COD_OFICINA
         AND GE_CUENTAS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
         AND GE_CUENTAS.fre_extracto = v_frecuencia
         AND GE_CTA_CLIENTES.RELACION = 'P'
         and (p_cod_persona is null or ge_cta_clientes.cod_persona = p_cod_persona)
         AND GE_CUENTAS.COD_MODULO != 5
         AND ((GE_CUENTAS.ESTADO NOT IN ('X','A','C','P')) OR
             (GE_CUENTAS.ESTADO IN ('C','P') AND GE_CUENTAS.FEC_MODIFICACION >=
              v_pri_dia_mes_habil));
         --
       CURSOR CTAS IS
         SELECT DISTINCT GE_CTA_CLIENTES.COD_MODULO,
                DECODE( GE_CTA_CLIENTES.COD_MODULO, 3, GE_CTA_CLIENTES.COD_MODALIDAD,
                                                    4, decode( GE_CTA_CLIENTES.COD_MODALIDAD, 41, 41, 43 ),
                                                       GE_CTA_CLIENTES.COD_MODULO ) COD_MODALIDAD
           FROM GE_CTA_CLIENTES
          WHERE GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
            AND GE_CTA_CLIENTES.RELACION = 'P'
            AND GE_CTA_CLIENTES.COD_MODULO >= 3
            AND GE_CTA_CLIENTES.COD_MODULO <= 6
          ORDER BY decode(GE_CTA_CLIENTES.COD_MODULO, 4, 1, 3,
                DECODE( GE_CTA_CLIENTES.COD_MODULO, 3, GE_CTA_CLIENTES.COD_MODALIDAD,
                                                    4, decode( GE_CTA_CLIENTES.COD_MODALIDAD, 41, 41, 43 ),
                                                       GE_CTA_CLIENTES.COD_MODULO ) );
   begin
     v_lugar := 'lp_gen_extracto';
     FOR CL IN MAE_CLI LOOP
       -- dbms_output.put_line('Generando datos del Cliente '||cl.COD_PERSONA);
        -- Inicializo la variable que separa los extractos especificos-
        v_cod_extracto     := 1;
        v_cod_ext_separado := 1;
        -- CUENTAS CORRIENTE Y AHORRO A LA VISTA del CLIENTE ----------
        v_inserta     := 'N';
        v_cod_persona := CL.COD_PERSONA;
        FOR RCTA IN CTAS LOOP
            If rcta.COD_MODULO = 4 Then
              IF rcta.cod_modalidad = 41 THEN
                lp_generar_ctacte;
              ELSE
                lp_generar_ctaban;
              END IF;
            ElsIf rcta.COD_MODULO = 3 and rcta.COD_MODALIDAD = 31 Then
               lp_generar_vistas;
            Elsif rcta.COD_MODULO = 3 and rcta.COD_MODALIDAD in (33,34,35) Then
                v_cod_modalidad := rcta.cod_modalidad;
                lp_generar_certificados;
                --commit;
            Elsif rcta.COD_MODULO = 6 Then
                lp_generar_prestamos;
            End if;
                   --CROGENEXT-13 Sergio Servín 06/08/2014
                --   elsif rcta.COD_MODULO = 5 Then
               -- lp_generar_tarjetas;
           --End If;
        END LOOP;

      END LOOP;
   end lp_gen_extracto;

   procedure lp_act_maestro is
     cursor cur_actualizador is
      SELECT *
        FROM GE_CTA_EXTRACTOS_TMP;
   begin
     for t in cur_actualizador loop
        if t.NOM_TABLA = 'CC_CTA_CORRIENTES' then
         UPDATE cc_cta_corrientes e
            set e.nro_folio        = t.nro_folio,
                e.fec_ult_extracto = t.fec_ult_extracto,
                e.sal_ult_extracto = t.sal_ult_extracto
          where e.nro_cuenta       = t.nro_cuenta;
          PRG_ACT_DAT_EXT_PERSONAS(t.nro_cuenta, t.fec_ult_extracto,v_lugar,v_fec_actual);
        elsif t.NOM_TABLA = 'CC_CTA_BANCARIAS' then
         UPDATE cc_cta_bancarias e
            set e.nro_folio        = t.nro_folio,
                e.fec_ult_extracto = t.fec_ult_extracto,
                e.sal_ult_extracto = t.sal_ult_extracto
          where e.nro_cuenta       = t.nro_cuenta;
          PRG_ACT_DAT_EXT_PERSONAS(t.nro_cuenta, t.fec_ult_extracto,v_lugar,v_fec_actual);
        elsif t.NOM_TABLA = 'AH_CTA_VISTAS'  then
         UPDATE ah_cta_vistas e
            set e.nro_folio        = t.nro_folio,
                e.fec_ult_extracto = t.fec_ult_extracto,
                e.sal_ult_extracto = t.sal_ult_extracto
          where e.nro_cuenta       = t.nro_cuenta;
          PRG_ACT_DAT_EXT_PERSONAS(t.nro_cuenta, t.fec_ult_extracto,v_lugar,v_fec_actual);
        end if;
     end loop;

   end lp_act_maestro;


begin

  -- Carga los valores de fecha que va a utilizar en el proceso --
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;

  --pag_cal.pr_obt_dat_calendar(3);
  v_fec_actual        := TO_DATE(fug_obt_pardinamico('EXT_FEC_SISTEMA'),'dd/mm/rrrr');
  v_pri_dia_mes_habil := TO_DATE(fug_obt_pardinamico('EXT_FEC_PRI_DIA_MES_HAB'),'dd/mm/rrrr');
  v_fec_sig_habil     := TO_DATE(fug_obt_pardinamico('EXT_FEC_SIG_DIA_HAB'),'dd/mm/rrrr');
  v_ult_dia_mes_habil := TO_DATE(fug_obt_pardinamico('EXT_FEC_ULT_DIA_HAB'),'dd/mm/rrrr');
  v_fec_quincena      := lf_obt_fec_hab_quincena;

  v_msj := null;
  sql_util.ejecute_dml('TRUNCATE TABLE GE_CTA_EXTRACTOS_TMP', v_msj);
  if v_msj is not null then
     RAISE_APPLICATION_ERROR(-20001, v_msj);
  end if;

  if p_frecuencia is null Then
     v_frecuencia := 'D'; -- Primero procesa los extractos diarios...
     -- Verifica que no se haya generado el extracto anteriormente --
     if lf_ver_ext_generado > 0 Then
        lp_eli_ext_generado;
     end if;
     --
     --
     lp_gen_extracto;
     --
     lp_act_tip_mensaje;
     --
     lp_act_nro_control;
     --
     lp_mar_ext_con_diferencia;
     --
     lp_mar_ext_con_dif_detalle;
     --
     lp_act_folio_ahorros;
     --
     lp_act_folio_ctactes;
      --
     lp_act_maestro;

     prg_act_cod_mensaje(v_fec_actual,v_frecuencia);
     -- Verifica si debe procesar el extracto semanal...
     If to_number(to_char(v_fec_actual, 'D')) > to_number(to_char(v_fec_sig_habil,'D')) or
        v_fec_actual = v_ult_dia_mes_habil Then
        -- Es el ultimo dia habil de la semana o es el ultimo dia habil del mes...
         v_frecuencia := 'S'; -- Procesa los extractos Semanales
         -- Verifica que no se haya generado el extracto anteriormente --
         if lf_ver_ext_generado > 0 Then
            lp_eli_ext_generado;
         end if;
         --
         --
         lp_gen_extracto;
         --
         lp_act_tip_mensaje;
         --
         lp_act_nro_control;
         --
         lp_mar_ext_con_diferencia;
         --
         lp_mar_ext_con_dif_detalle;
         --
         lp_act_folio_ahorros;
         --
         lp_act_folio_ctactes;
         --
         lp_act_maestro;

         prg_act_cod_mensaje(v_fec_actual,v_frecuencia);

         --CROGENEXT-13 Sergio Servín 06/08/2014
         /*v_frecuencia := 'T'; -- Procesa los extractos Trimestrales
         --
         --
         lp_gen_extracto;
         --
         lp_act_tip_impresion; -- cambia a no impreso los extractos sin movimientos
         --
         lp_act_tip_mensaje;
         --
         lp_act_nro_control;
         --
         lp_mar_ext_con_diferencia;
         --
         lp_mar_ext_con_dif_detalle;
         --
         lp_act_folio_ahorros;
         --
         lp_act_folio_ctactes;
         --
         lp_act_maestro;
         prg_act_cod_mensaje(v_fec_actual,v_frecuencia);*/



     End If;

     -- Verifica si debe procesar el extracto quincenal...
     if v_fec_actual = v_fec_quincena then
        -- Es el primer día hábil desde la quincena...
         v_frecuencia := 'Q'; -- Procesa los extractos Quincenales
         -- Verifica que no se haya generado el extracto anteriormente --
         if lf_ver_ext_generado > 0 Then
            lp_eli_ext_generado;
         end if;
         --
         --
         lp_gen_extracto;
         --
         lp_act_tip_mensaje;
         --
         lp_act_nro_control;
         --
         lp_mar_ext_con_diferencia;
         --
         lp_mar_ext_con_dif_detalle;
         --
         lp_act_folio_ahorros;
         --
         lp_act_folio_ctactes;
         --
         lp_act_maestro;

         prg_act_cod_mensaje(v_fec_actual,v_frecuencia);
     End If;

     If v_fec_actual = v_ult_dia_mes_habil Then
        -- Es el ultimo dia habil del mes...
         v_frecuencia := 'M'; -- Procesa los extractos Mensuales
         -- Verifica que no se haya generado el extracto anteriormente --
         if lf_ver_ext_generado > 0 Then
            lp_eli_ext_generado;
         end if;
         --
         --
         lp_gen_extracto;
         --
         lp_act_tip_impresion; -- cambia a no impreso los extractos sin movimientos
         --
         lp_act_tip_mensaje;
         --
         lp_act_nro_control;
         --
         lp_mar_ext_con_diferencia;
         --
         lp_mar_ext_con_dif_detalle;
         --
         lp_act_folio_ahorros;
         --
         lp_act_folio_ctactes;
         --
         lp_act_maestro;

         prg_act_cod_mensaje(v_fec_actual,v_frecuencia);

         --CROGENEXT-13 Sergio Servín 06/08/2014
         /*v_frecuencia := 'T'; -- Procesa los extractos Trimestrales
         --
         --
         lp_gen_extracto;
         --
         lp_act_tip_impresion; -- cambia a no impreso los extractos sin movimientos
         --
         lp_act_tip_mensaje;
         --
         lp_act_nro_control;
         --
         lp_mar_ext_con_diferencia;
         --
         lp_mar_ext_con_dif_detalle;
         --
         lp_act_folio_ahorros;
         --
         lp_act_folio_ctactes;
         --
         lp_act_maestro;
         prg_act_cod_mensaje(v_fec_actual,v_frecuencia);*/
     End If;
  else
     v_frecuencia := p_frecuencia;
     -- Verifica que no se haya generado el extracto anteriormente --
     if lf_ver_ext_generado > 0 Then
        RAISE_APPLICATION_ERROR(-20001,'Extracto Generado Anteriormente');
     end if;
     --
     --
     lp_gen_extracto;
     --
     lp_act_tip_mensaje;
     --
     lp_act_nro_control;
     --
     lp_mar_ext_con_diferencia;
     --
     lp_mar_ext_con_dif_detalle;
     --
     lp_act_folio_ahorros;
     --
     lp_act_folio_ctactes;
     --
     lp_act_maestro;

     prg_act_cod_mensaje(v_fec_actual,v_frecuencia);
  end if;

exception
  when OTHERS Then
     if sqlcode <= -20000 then
        raise;
     else
        raise_application_error(-20000,v_lugar||'-'||sqlerrm);
     end if;
end PRG_REP_GEN_EXTRACTO;
/

