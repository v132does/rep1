CREATE OR REPLACE PROCEDURE IT."PRG_GEN_EXT_CLIENTES"(p_frecuencia IN VARCHAR2 DEFAULT NULL) IS
  ------------------------------------------------
  --Modificaciones realizadas por Ramon Pavon-----
  --DESOPIMI-15 - Req. Optimizacion - 19.01.2017--
  ------------------------------------------------

  -- Definicion de Variables Globales
  v_lugar            VARCHAR2(2000) := 'Iniciando';
  v_cod_persona      ba_personas.cod_persona%TYPE;
  v_nro_cuenta       ge_cta_clientes.nro_cuenta%TYPE;
  v_cod_extracto     GE_ARQ_clientes.cod_extracto%TYPE;
  v_cod_ext_separado GE_ARQ_clientes.cod_extracto%TYPE;
  v_cod_modalidad    ge_modalidades.cod_modalidad%TYPE;
  ---
  v_fec_actual        ge_calendarios.fec_actual%TYPE;
  v_pri_dia_mes_habil ge_calendarios.pri_dia_mes_habil%TYPE;
  v_ult_dia_mes_habil ge_calendarios.ult_dia_mes_habil%TYPE;
  v_fec_sig_habil     DATE;
  v_fec_quincena      DATE;
  v_inserta           VARCHAR2(1);
  v_frecuencia        VARCHAR2(1);

  --- Variables de Datos de Direccion
  v_dir_cliente GE_ARQ_clientes.direccion%TYPE;
  v_pri_obs_dir GE_ARQ_clientes.det_direccion%TYPE;
  v_seg_obs_dir GE_ARQ_clientes.observacion%TYPE;
  v_cod_pais    GE_ARQ_clientes.cod_pais%TYPE;
  v_cod_ciudad  GE_ARQ_clientes.cod_ciudad%TYPE;
  v_des_barrio  GE_ARQ_clientes.barrio%TYPE;
  v_tel_cliente GE_ARQ_clientes.telefono%TYPE;
  v_tip_envio   ge_dir_envios.tip_envio%TYPE;
  --sergio CROGENEXT
  v_piso             VARCHAR2(2000);
  v_departamento     VARCHAR2(2000);
  v_edificio         VARCHAR2(2000);
  v_direccion        VARCHAR2(2000);
  v_tip_gen_extracto VARCHAR2(1); --I = Individual / C = Consolidado
  v_es_nomina        VARCHAR2(1); -- S =  es nomina / N = no es nomina

  --- Variables de Datos del Oficial
  v_es_empleado      VARCHAR2(1);
  v_cli_confidencial VARCHAR2(1);
  v_cat_riesgo       ge_clientes.cat_riesgo%TYPE;
  v_fec_ult_clasif   ge_clientes.fec_ult_clasif%TYPE;
  v_cod_ofi_cliente  NUMBER(4);
  v_cod_usu_oficial  ge_clientes.cod_usu_oficial%TYPE;
  v_tel_oficial      ba_oficinas.telefono%TYPE;
  v_int_oficial      ba_usuarios.nro_interno%TYPE;
  v_tip_extracto     ge_clientes.tip_extracto%TYPE;
  v_fec_movimiento   ge_calendarios.fec_actual%TYPE;
  v_sal_actual       GE_ARQ_cli_cuentas.sal_actual%TYPE;
  v_nom_cliente      ba_personas.nom_completo%TYPE;
  v_mto_bloqueo      NUMBER;
  v_sal_blo_anterior NUMBER;
  v_cod_per_ente     ge_entes.cod_persona%TYPE;
  v_msj              VARCHAR2(500);
  v_cod_seg_fun      ge_clientes.cod_seg_cliente%TYPE;
  v_cod_seg_cliente  ge_clientes.cod_seg_cliente%TYPE;
  v_ano              NUMBER(4);
  v_mes              NUMBER(2);

  --Variables de Trabajo--
  v_hor_inicio            VARCHAR2(8);
  v_hor_fin               VARCHAR2(8);
  v_cod_programa          ge_log_procesos.cod_programa%TYPE;
  v_ind_act_dat_extractos ge_par_dinamicos.val_parametro%TYPE;
  v_fre_generar           VARCHAR2(50);
  v_tab_estadistica       VARCHAR2(500);
  --DYDMR-9148 - Incidencia SAU - ITGF - Generación de Base de Datos para Envio
  v_uti_dir_ente ge_par_entes.val_parametro%TYPE;
  FUNCTION lf_obt_fec_hab_quincena RETURN DATE IS
    v_result DATE;
  BEGIN
    IF (to_char(to_date(15 || to_char(v_fec_actual, 'mmyyyy'), 'dd/mm/yyyy'), 'D') = 1) THEN
      v_result := to_date(16 || to_char(v_fec_actual, 'mmyyyy'), 'dd/mm/yyyy');
    ELSIF (to_char(to_date(15 || to_char(v_fec_actual, 'mmyyyy'), 'dd/mm/yyyy'), 'D') = 7) THEN
      v_result := to_date(17 || to_char(v_fec_actual, 'mmyyyy'), 'dd/mm/yyyy');
    ELSE
      v_result := to_date(15 || to_char(v_fec_actual, 'mmyyyy'), 'dd/mm/yyyy');
    END IF;
    RETURN pag_cal.FU_OBT_FEC_SIG_HAB(v_result - 1, NULL); -- null para p_cod_oficina.
  END lf_obt_fec_hab_quincena;

  PROCEDURE pr_cal_fre_ext_generar IS
  BEGIN
    v_fre_generar := NULL;
    IF p_frecuencia IS NULL THEN
      --Primero procesa los extractos diarios...
      v_fre_generar := ',D,'; -- Primero procesa los extractos diarios...
      -- Verifica si debe procesar el extracto semanal...
      IF to_number(to_char(v_fec_actual, 'D')) >
         to_number(to_char(v_fec_sig_habil, 'D'))
         OR v_fec_actual = v_ult_dia_mes_habil THEN
        -- Es el ultimo dia habil de la semana o es el ultimo dia habil del mes...
        v_fre_generar := v_fre_generar || 'S,'; -- Procesa los extractos Semanales
      END IF;
      -- Verifica si debe procesar el extracto quincenal...
      IF v_fec_actual = v_fec_quincena THEN
        -- Es el primer dia habil desde la quincena...
        -- Verifica que no se haya generado el extracto anteriormente --
        v_fre_generar := v_fre_generar || 'Q,'; -- Procesa los extractos Quincenales
      END IF;
      -- Verifica si debe procesar el extracto mensual...
      IF v_fec_actual = v_ult_dia_mes_habil THEN
        -- Es el ultimo dia habil del mes...
        -- Verifica que no se haya generado el extracto anteriormente --
        v_fre_generar := v_fre_generar || 'M,'; -- Procesa los extractos Mensuales
      END IF;
    ELSE
      v_fre_generar := '.' || p_frecuencia || '.';
    END IF;
  END pr_cal_fre_ext_generar;

  PROCEDURE lp_ins_mov_tmp_cte IS
  
  BEGIN
    INSERT INTO GE_ARQ_CLI_MOV_GENERAR
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             x.nro_cuenta,
             x.cod_moneda,
             x.cod_oficina,
             cod_error,
             x.cod_retencion,
             fec_fin_retencion,
             est_cuenta,
             x.estado,
             cod_causa,
             x.cod_banco,
             cod_ofi_origen,
             x.concepto,
             x.cod_tasa,
             val_tasa,
             cod_rubro,
             cod_ref_cambio,
             reversado,
             cod_usu_reversion,
             hor_reversion,
             emi_aviso,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             x.cod_transaccion,
             x.cod_modulo,
             x.cod_modalidad,
             mto_equ_local,
             nro_caja,
             cotizacion,
             cod_bco_central,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             protegido,
             cod_autorizacion,
             cod_usu_autorizador,
             x.usu_insercion,
             x.fec_insercion,
             x.usu_modificacion,
             x.fec_modificacion,
             tip_mov_rubro,
             cod_tip_ope_cambio,
             x.nro_folio,
             referencia,
             x.cod_persona,
             cod_sit_contable,
             nro_conciliacion
      FROM cc_movimientos_his x,
           GE_ARQ_CLI_CUENTAS z,
           GE_TRANSACCIONES   y,
           cc_cta_corrientes  k
      WHERE z.nro_cuenta = x.nro_cuenta
      AND k.nro_cuenta = x.nro_cuenta
      AND x.fecha > nvl(k.fec_ult_extracto, k.fec_apertura - 1)
      AND x.fecha <= v_fec_actual
      AND (x.REVERSADO = 'N' OR
            (x.REVERSADO = 'S' AND
            FEC_VALOR <= nvl(k.fec_ult_extracto, k.fec_apertura - 1) AND
            EXISTS (SELECT 1
                  FROM CC_MOVIMIENTOS_HIS REV -- CB. 25/09/2013.
                  WHERE x.FEC_VALOR = REV.FECHA
                  AND x.HOR_REVERSION = REV.HORA
                  AND x.COD_USU_REVERSION = REV.COD_USUARIO
                  AND x.NRO_SECUENCIA = REV.NRO_SECUENCIA
                       -- DYDMR-5672 NAF 01/2017
                  AND x.NRO_CUENTA = REV.NRO_CUENTA
                  AND abs(x.MONTO) = abs(REV.MONTO))) OR
            (x.REVERSADO = 'S' AND x.COD_TRA_PADRE IN (303, 302) AND
            x.Cod_Mad_Padre = 455))
      AND x.ESTADO = 'N'
      AND x.COD_MODULO = y.COD_MODULO
      AND x.COD_MODALIDAD = y.COD_MODALIDAD
      AND x.COD_TRANSACCION = y.COD_TRANSACCION
      AND y.VE_CLIENTE = 'S'
      AND NVL(y.AFECTA, 'XX') != 'B'
      AND y.TIPO IN ('C', 'D');
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20010, 'ERROR. En lp_tra_ge_movimientos.' ||
                               SQLERRM);
  END lp_ins_mov_tmp_cte;

  PROCEDURE lp_ins_mov_tmp_ban IS
  
  BEGIN
    INSERT INTO GE_ARQ_CLI_MOV_GENERAR
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             x.nro_cuenta,
             x.cod_moneda,
             x.cod_oficina,
             cod_error,
             x.cod_retencion,
             fec_fin_retencion,
             est_cuenta,
             x.estado,
             cod_causa,
             x.cod_banco,
             cod_ofi_origen,
             x.concepto,
             x.cod_tasa,
             val_tasa,
             x.cod_rubro,
             cod_ref_cambio,
             reversado,
             cod_usu_reversion,
             hor_reversion,
             emi_aviso,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             x.cod_transaccion,
             x.cod_modulo,
             x.cod_modalidad,
             mto_equ_local,
             nro_caja,
             cotizacion,
             cod_bco_central,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             protegido,
             cod_autorizacion,
             cod_usu_autorizador,
             x.usu_insercion,
             x.fec_insercion,
             x.usu_modificacion,
             x.fec_modificacion,
             tip_mov_rubro,
             cod_tip_ope_cambio,
             x.nro_folio,
             referencia,
             x.cod_persona,
             cod_sit_contable,
             nro_conciliacion
      FROM cc_movimientos_his x,
           ge_arq_cli_cuentas z,
           GE_TRANSACCIONES   y,
           cc_cta_bancarias   k
      WHERE z.nro_cuenta = x.nro_cuenta
      AND k.nro_cuenta = x.nro_cuenta
      AND x.fecha > nvl(k.fec_ult_extracto, k.fec_apertura - 1)
      AND x.fecha <= v_fec_actual
      AND (x.REVERSADO = 'N' OR
            (x.REVERSADO = 'S' AND
            FEC_VALOR <= nvl(k.fec_ult_extracto, k.fec_apertura - 1) AND
            EXISTS (SELECT 1
                  FROM CC_MOVIMIENTOS_HIS REV -- CB. 25/09/2013.
                  WHERE x.FEC_VALOR = REV.FECHA
                  AND x.HOR_REVERSION = REV.HORA
                  AND x.COD_USU_REVERSION = REV.COD_USUARIO
                  AND x.NRO_SECUENCIA = REV.NRO_SECUENCIA
                       -- DYDMR-5672 NAF 01/2017
                  AND x.NRO_CUENTA = REV.NRO_CUENTA
                  AND abs(x.MONTO) = abs(REV.MONTO))) OR
            (x.REVERSADO = 'S' AND x.COD_TRA_PADRE IN (303, 302) AND
            x.Cod_Mad_Padre = 455))
      AND x.ESTADO = 'N'
      AND x.COD_MODULO = y.COD_MODULO
      AND x.COD_MODALIDAD = y.COD_MODALIDAD
      AND x.COD_TRANSACCION = y.COD_TRANSACCION
      AND y.VE_CLIENTE = 'S'
      AND NVL(y.AFECTA, 'XX') != 'B'
      AND y.TIPO IN ('C', 'D')
      AND k.cod_modulo = 4
      AND z.COD_MODALIDAD <> 41;
  
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20020, 'ERROR. En lp_tra_ge_movimientos.' ||
                               SQLERRM);
  END lp_ins_mov_tmp_ban;

  PROCEDURE lp_ins_mov_tmp_vis IS
  
  BEGIN
    INSERT INTO GE_ARQ_CLI_MOV_GENERAR
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             x.nro_cuenta,
             x.cod_moneda,
             x.cod_oficina,
             cod_error,
             x.cod_retencion,
             fec_fin_retencion,
             est_cuenta,
             x.estado,
             cod_causa,
             x.cod_banco,
             cod_ofi_origen,
             x.concepto,
             x.cod_tasa,
             val_tasa,
             cod_rubro,
             cod_ref_cambio,
             reversado,
             cod_usu_reversion,
             hor_reversion,
             emi_aviso,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             x.cod_transaccion,
             x.cod_modulo,
             x.cod_modalidad,
             mto_equ_local,
             nro_caja,
             cotizacion,
             cod_bco_central,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             protegido,
             cod_autorizacion,
             cod_usu_autorizador,
             x.usu_insercion,
             x.fec_insercion,
             x.usu_modificacion,
             x.fec_modificacion,
             tip_mov_rubro,
             cod_tip_ope_cambio,
             x.nro_folio,
             referencia,
             x.cod_persona,
             cod_sit_contable,
             nro_conciliacion
      FROM ah_movimientos_his x,
           GE_ARQ_CLI_CUENTAS z,
           GE_TRANSACCIONES   y,
           AH_CTA_VISTAS      k
      WHERE z.nro_cuenta = x.nro_cuenta
      AND k.nro_cuenta = x.nro_cuenta
      AND x.fecha > nvl(k.fec_ult_extracto, k.fec_apertura - 1)
      AND x.fecha <= v_fec_actual
      AND (x.REVERSADO = 'N' OR
            (x.REVERSADO = 'S' AND
            FEC_VALOR <= nvl(k.fec_ult_extracto, k.fec_apertura - 1) AND
            EXISTS (SELECT 1
                  FROM AH_MOVIMIENTOS_HIS REV -- CB. 25/09/2013.
                  WHERE x.FEC_VALOR = REV.FECHA
                  AND x.HOR_REVERSION = REV.HORA
                  AND x.COD_USU_REVERSION = REV.COD_USUARIO
                  AND x.NRO_SECUENCIA = REV.NRO_SECUENCIA
                       -- DYDMR-5672 NAF 01/2017
                  AND x.NRO_CUENTA = REV.NRO_CUENTA
                  AND abs(x.MONTO) = abs(REV.MONTO))) OR
            (x.REVERSADO = 'S' AND x.COD_TRA_PADRE IN (303, 302) AND
            x.Cod_Mad_Padre = 455))
      AND x.ESTADO = 'N'
      AND x.COD_MODULO = y.COD_MODULO
      AND x.COD_MODALIDAD = y.COD_MODALIDAD
      AND x.COD_TRANSACCION = y.COD_TRANSACCION
      AND y.VE_CLIENTE = 'S'
      AND NVL(y.AFECTA, 'XX') != 'B'
      AND y.TIPO IN ('C', 'D');
  
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20030, 'ERROR. En lp_tra_ge_movimientos.' ||
                               SQLERRM);
  END lp_ins_mov_tmp_vis;

  PROCEDURE lp_ins_mov_tmp_rev IS
  BEGIN
    INSERT INTO GE_ARQ_CLI_MOV_GENERAR
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             x.nro_cuenta,
             x.cod_moneda,
             x.cod_oficina,
             cod_error,
             x.cod_retencion,
             fec_fin_retencion,
             est_cuenta,
             x.estado,
             cod_causa,
             x.cod_banco,
             cod_ofi_origen,
             x.concepto,
             x.cod_tasa,
             val_tasa,
             cod_rubro,
             cod_ref_cambio,
             reversado,
             cod_usu_reversion,
             hor_reversion,
             emi_aviso,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             x.cod_transaccion,
             x.cod_modulo,
             x.cod_modalidad,
             mto_equ_local,
             nro_caja,
             cotizacion,
             cod_bco_central,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             protegido,
             cod_autorizacion,
             cod_usu_autorizador,
             x.usu_insercion,
             x.fec_insercion,
             x.usu_modificacion,
             x.fec_modificacion,
             tip_mov_rubro,
             cod_tip_ope_cambio,
             x.nro_folio,
             referencia,
             x.cod_persona,
             cod_sit_contable,
             nro_conciliacion
      FROM cc_movimientos_his x
      WHERE EXISTS (SELECT 1
             FROM GE_ARQ_CLI_MOV_GENERAR t
             WHERE t.reversado = 'S'
             AND t.fec_valor < v_pri_dia_mes_habil
             AND t.fec_valor = x.fecha
             AND t.hor_reversion = x.hora
             AND t.cod_usu_reversion = x.cod_usuario
             AND t.nro_cuenta = x.nro_cuenta
             AND t.reversado = x.reversado);
  
    INSERT INTO GE_ARQ_CLI_MOV_GENERAR
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             x.nro_cuenta,
             x.cod_moneda,
             x.cod_oficina,
             cod_error,
             x.cod_retencion,
             fec_fin_retencion,
             est_cuenta,
             x.estado,
             cod_causa,
             x.cod_banco,
             cod_ofi_origen,
             x.concepto,
             x.cod_tasa,
             val_tasa,
             cod_rubro,
             cod_ref_cambio,
             reversado,
             cod_usu_reversion,
             hor_reversion,
             emi_aviso,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             x.cod_transaccion,
             x.cod_modulo,
             x.cod_modalidad,
             mto_equ_local,
             nro_caja,
             cotizacion,
             cod_bco_central,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             protegido,
             cod_autorizacion,
             cod_usu_autorizador,
             x.usu_insercion,
             x.fec_insercion,
             x.usu_modificacion,
             x.fec_modificacion,
             tip_mov_rubro,
             cod_tip_ope_cambio,
             x.nro_folio,
             referencia,
             x.cod_persona,
             cod_sit_contable,
             nro_conciliacion
      FROM ah_movimientos_his x
      WHERE EXISTS (SELECT 1
             FROM GE_ARQ_CLI_MOV_GENERAR t
             WHERE t.reversado = 'S'
             AND t.fec_valor < v_pri_dia_mes_habil
             AND t.fec_valor = x.fecha
             AND t.hor_reversion = x.hora
             AND t.cod_usu_reversion = x.cod_usuario
             AND t.nro_cuenta = x.nro_cuenta
             AND t.reversado = x.reversado);
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20040, 'ERROR. En lp_ins_mov_tmp_rever.' ||
                               SQLERRM);
  END lp_ins_mov_tmp_rev;
  ---
  PROCEDURE lp_ins_ge_arq_cli_mov_cte IS
    v_nom_tabla VARCHAR2(500) := 'ge_arq_cli_movimientos';
  
  BEGIN
    INSERT INTO ge_arq_cli_movimientos
      SELECT (DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta), 'D', NVL(CC_MOVIMIENTOS_HIS.MONTO, 0), 0)),
             (DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta), 'C', NVL(CC_MOVIMIENTOS_HIS.MONTO, 0), 0)),
             NULL,
             CC_MOVIMIENTOS_HIS.COD_TRA_PADRE,
             cta.cod_persona,
             v_fec_actual,
             cta.cod_extracto,
             CC_MOVIMIENTOS_HIS.NRO_CUENTA,
             CC_MOVIMIENTOS_HIS.FECHA,
             CC_MOVIMIENTOS_HIS.FEC_VALOR,
             CC_MOVIMIENTOS_HIS.HORA,
             CC_MOVIMIENTOS_HIS.NRO_DOCUMENTO,
             CC_MOVIMIENTOS_HIS.COD_MOD_PADRE,
             CC_MOVIMIENTOS_HIS.COD_MAD_PADRE,
             USER,
             CC_MOVIMIENTOS_HIS.FEC_INSERCION,
             USER,
             SYSDATE,
             cta.fre_extracto,
             CC_MOVIMIENTOS_HIS.NRO_SECUENCIA,
             cc_movimientos_his.cod_ofi_origen,
             NULL,
             decode(ge_transacciones.afecta, 'B', 'S', 'N')
      FROM GE_TRANSACCIONES,
           GE_ARQ_CLI_MOV_GENERAR CC_MOVIMIENTOS_HIS,
           ge_arq_cli_cuentas     cta,
           cc_cta_corrientes      mae
      WHERE CC_MOVIMIENTOS_HIS.COD_MODULO = mae.COD_MODULO
      AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = cta.COD_MODALIDAD
      AND CC_MOVIMIENTOS_HIS.COD_OFICINA = cta.COD_OFICINA
      AND CC_MOVIMIENTOS_HIS.NRO_CUENTA = cta.NRO_CUENTA
      AND MAE.NRO_CUENTA = cta.NRO_CUENTA
      AND CC_MOVIMIENTOS_HIS.FECHA >
            NVL(MAE.FEC_ULT_EXTRACTO, MAE.FEC_APERTURA - 1) -- 17/07/2009 V.O.
      AND CC_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
      AND (CC_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
            (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
            FEC_VALOR <= NVL(MAE.FEC_ULT_EXTRACTO, MAE.FEC_APERTURA - 1) AND
            EXISTS (SELECT 1
                  FROM GE_ARQ_CLI_MOV_GENERAR REV -- CB. 25/09/2013.
                  WHERE CC_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
                  AND CC_MOVIMIENTOS_HIS.HOR_REVERSION = REV.HORA
                  AND CC_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
                  AND CC_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                       -- DYDMR-5672 NAF 01/2017
                  AND CC_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
                  AND abs(CC_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO))) OR
            (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
            CC_MOVIMIENTOS_HIS.COD_TRA_PADRE IN (303, 302) AND
            CC_MOVIMIENTOS_HIS.COD_MAD_PADRE = 455))
      AND CC_MOVIMIENTOS_HIS.ESTADO = 'N'
      AND CC_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
      AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
      AND CC_MOVIMIENTOS_HIS.COD_TRANSACCION =
            GE_TRANSACCIONES.COD_TRANSACCION
      AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
      AND GE_TRANSACCIONES.TIPO IN ('C', 'D')
      AND NVL(GE_TRANSACCIONES.AFECTA, 'XX') != 'B';
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'ERROR. En ' || v_nom_tabla || '-' ||
                               SQLERRM);
  END lp_ins_ge_arq_cli_mov_cte;

  PROCEDURE lp_ins_ge_arq_cli_mov_ban IS
    v_nom_tabla VARCHAR2(500) := 'GE_ARQ_cli_movimientos';
  
  BEGIN
    INSERT INTO GE_ARQ_cli_movimientos
      SELECT (decode(fug_obt_tra_tipo(t.cod_transaccion, t.tipo, t.afecta), 'D', NVL(h.monto, 0), 0)),
             (decode(fug_obt_tra_tipo(t.cod_transaccion, t.tipo, afecta), 'C', NVL(h.monto, 0), 0)),
             NULL,
             h.cod_tra_padre,
             b.cod_persona,
             v_fec_actual,
             b.cod_extracto,
             h.nro_cuenta,
             h.fecha,
             h.fec_valor,
             h.hora,
             h.nro_documento,
             h.cod_mod_padre,
             h.cod_mad_padre,
             h.usu_insercion,
             h.fec_insercion,
             h.usu_modificacion,
             h.fec_modificacion,
             b.fre_extracto,
             h.nro_secuencia,
             h.cod_ofi_origen,
             NULL,
             decode(t.afecta, 'B', 'S', 'N')
      FROM ge_transacciones       t,
           GE_ARQ_CLI_MOV_GENERAR h,
           ge_arq_cli_cuentas     b,
           cc_cta_bancarias       mae
      WHERE h.cod_modulo = mae.cod_modulo
      AND h.cod_modalidad = b.cod_modalidad
      AND h.cod_oficina = b.cod_oficina
      AND h.nro_cuenta = b.nro_cuenta
      AND mae.nro_cuenta = b.nro_cuenta
      AND h.fecha > NVL(MAE.FEC_ULT_EXTRACTO, MAE.FEC_APERTURA - 1)
      AND (h.REVERSADO = 'N' OR
            (h.REVERSADO = 'S' AND
            h.FEC_VALOR <= nvl(mae.fec_ult_extracto, mae.fec_apertura - 1) AND
            EXISTS (SELECT 1
                  FROM GE_ARQ_CLI_MOV_GENERAR REV -- CB. 25/09/2013.
                  WHERE h.FEC_VALOR = REV.FECHA
                  AND h.HOR_REVERSION = REV.HORA
                  AND h.COD_USU_REVERSION = REV.COD_USUARIO
                  AND h.NRO_SECUENCIA = REV.NRO_SECUENCIA
                       -- DYDMR-5672 NAF 01/2017
                  AND h.NRO_CUENTA = REV.NRO_CUENTA
                  AND abs(h.MONTO) = abs(REV.MONTO))) OR
            (h.REVERSADO = 'S' AND h.COD_TRA_PADRE IN (303, 302) AND
            h.Cod_Mad_Padre = 455))
      AND h.fecha <= v_fec_actual
      AND h.estado = 'N'
      AND h.cod_modulo = t.cod_modulo
      AND h.cod_modalidad = t.cod_modalidad
      AND h.cod_transaccion = t.cod_transaccion
      AND (NVL(t.AFECTA, 'XX') = 'B' AND EXISTS
             (SELECT 1
              FROM ge_par_causales r
              WHERE r.cod_causa = h.cod_causa
              AND r.parametro = 'COD_CAU_BLO_EXT'
              AND r.val_parametro = 'S') OR NVL(t.AFECTA, 'XX') != 'B')
      AND t.ve_cliente = 'S'
      AND t.tipo IN ('C', 'D')
      AND mae.COD_MODULO = 4
      AND b.COD_MODALIDAD <> 41;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'ERROR. En ' || v_nom_tabla || '-' ||
                               SQLERRM);
  END lp_ins_ge_arq_cli_mov_ban;

  PROCEDURE lp_ins_ge_arq_cli_mov_vis IS
    v_nom_tabla VARCHAR2(500) := 'ge_arq_cli_movimientos';
  
  BEGIN
    INSERT INTO ge_arq_cli_movimientos
      SELECT (DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta), 'D', NVL(AH_MOVIMIENTOS_HIS.MONTO, 0), 0)),
             (DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta), 'C', NVL(AH_MOVIMIENTOS_HIS.MONTO, 0), 0)),
             NULL,
             AH_MOVIMIENTOS_HIS.COD_TRA_PADRE,
             cta.cod_persona,
             v_fec_actual,
             cta.cod_extracto,
             AH_MOVIMIENTOS_HIS.NRO_CUENTA,
             AH_MOVIMIENTOS_HIS.FECHA,
             AH_MOVIMIENTOS_HIS.FEC_VALOR,
             AH_MOVIMIENTOS_HIS.HORA,
             AH_MOVIMIENTOS_HIS.NRO_DOCUMENTO,
             AH_MOVIMIENTOS_HIS.COD_MOD_PADRE,
             AH_MOVIMIENTOS_HIS.COD_MAD_PADRE,
             USER,
             AH_MOVIMIENTOS_HIS.FEC_INSERCION,
             USER,
             SYSDATE,
             cta.fre_extracto,
             AH_MOVIMIENTOS_HIS.NRO_SECUENCIA,
             AH_MOVIMIENTOS_HIS.cod_ofi_origen,
             NULL,
             decode(ge_transacciones.afecta, 'B', 'S', 'N')
      FROM GE_TRANSACCIONES,
           GE_ARQ_CLI_MOV_GENERAR AH_MOVIMIENTOS_HIS,
           ge_arq_cli_cuentas     cta,
           ah_cta_vistas          mae
      WHERE AH_MOVIMIENTOS_HIS.COD_MODULO = mae.COD_MODULO
      AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = cta.COD_MODALIDAD
      AND AH_MOVIMIENTOS_HIS.COD_OFICINA = cta.COD_OFICINA
      AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = cta.NRO_CUENTA
      AND MAE.NRO_CUENTA = cta.NRO_CUENTA
      AND AH_MOVIMIENTOS_HIS.FECHA >
            NVL(MAE.FEC_ULT_EXTRACTO, MAE.FEC_APERTURA - 1) -- 17/07/2009 V.O.
      AND AH_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
      AND (AH_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
            (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
            FEC_VALOR <= NVL(MAE.FEC_ULT_EXTRACTO, MAE.FEC_APERTURA - 1) AND
            EXISTS (SELECT 1
                  FROM GE_ARQ_CLI_MOV_GENERAR REV -- CB. 25/09/2013.
                  WHERE AH_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
                  AND AH_MOVIMIENTOS_HIS.HOR_REVERSION = REV.HORA
                  AND AH_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
                  AND AH_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                       -- DYDMR-5672 NAF 01/2017
                  AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
                  AND abs(AH_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO))) OR
            (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
            AH_MOVIMIENTOS_HIS.COD_TRA_PADRE IN (303, 302) AND
            AH_MOVIMIENTOS_HIS.COD_MAD_PADRE = 455))
      AND AH_MOVIMIENTOS_HIS.ESTADO = 'N'
      AND AH_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
      AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
      AND AH_MOVIMIENTOS_HIS.COD_TRANSACCION =
            GE_TRANSACCIONES.COD_TRANSACCION
      AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
      AND GE_TRANSACCIONES.TIPO IN ('C', 'D')
      AND NVL(GE_TRANSACCIONES.AFECTA, 'XX') != 'B';
  
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'ERROR. En ' || v_nom_tabla || '-' ||
                               SQLERRM);
  END lp_ins_ge_arq_cli_mov_vis;

  ---
  PROCEDURE lp_tru_tab_temporales IS
  BEGIN
    v_msj := NULL;
    sql_util.ejecute_dml('TRUNCATE TABLE GE_ARQ_DIR_ENVIOS', v_msj);
    IF v_msj IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20001, v_msj);
    END IF;
    v_msj := NULL;
    sql_util.ejecute_dml('TRUNCATE TABLE GE_ARQ_EXTRACTOS', v_msj);
    IF v_msj IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20001, v_msj);
    END IF;
    v_msj := NULL;
    sql_util.ejecute_dml('TRUNCATE TABLE GE_ARQ_RESUMENES', v_msj);
    IF v_msj IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20001, v_msj);
    END IF;
    v_msj := NULL;
    sql_util.ejecute_dml('TRUNCATE TABLE GE_ARQ_CLI_MOV_RETENIDOS', v_msj);
    IF v_msj IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20001, v_msj);
    END IF;
    v_msj := NULL;
    sql_util.ejecute_dml('TRUNCATE TABLE GE_ARQ_CLI_MOV_PENDIENTES', v_msj);
    IF v_msj IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20001, v_msj);
    END IF;
    v_msj := NULL;
    sql_util.ejecute_dml('TRUNCATE TABLE GE_ARQ_CLI_MOVIMIENTOS', v_msj);
    IF v_msj IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20001, v_msj);
    END IF;
    v_msj := NULL;
    sql_util.ejecute_dml('TRUNCATE TABLE GE_ARQ_CLI_CUENTAS', v_msj);
    IF v_msj IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20001, v_msj);
    END IF;
    v_msj := NULL;
    sql_util.ejecute_dml('TRUNCATE TABLE GE_ARQ_CLIENTES', v_msj);
    IF v_msj IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20001, v_msj);
    END IF;
    v_msj := NULL;
    sql_util.ejecute_dml('TRUNCATE TABLE GE_ARQ_CLI_MOV_GENERAR', v_msj);
    IF v_msj IS NOT NULL THEN
      raise_application_error(-20000, v_msj);
    END IF;
    sql_util.ejecute_dml('TRUNCATE TABLE GE_ARQ_SAL_MEN_CTACTES', v_msj);
    IF v_msj IS NOT NULL THEN
      raise_application_error(-20000, v_msj);
    END IF;
    sql_util.ejecute_dml('TRUNCATE TABLE GE_ARQ_SAL_MEN_AHORROS', v_msj);
    IF v_msj IS NOT NULL THEN
      raise_application_error(-20000, v_msj);
    END IF;
  END lp_tru_tab_temporales;

  PROCEDURE lp_car_tab_temporales IS
  BEGIN
    NULL;
    INSERT INTO ge_arq_dir_envios
      SELECT a.*
      FROM gv_dir_envios a;
  
    INSERT INTO ge_arq_sal_men_ahorros
      SELECT a.*
      FROM ah_sal_mensuales a
      WHERE a.ano = v_ano
      AND a.mes = v_mes;
  
    INSERT INTO ge_arq_sal_men_ctactes
      SELECT a.*
      FROM cc_sal_mensuales a
      WHERE a.ano = v_ano
      AND a.mes = v_mes;
  
    --Generacion de Estadisticas--
    BEGIN
      dbms_stats.gather_table_stats('IT', 'GE_ARQ_DIR_ENVIOS');
    END;
    BEGIN
      dbms_stats.gather_table_stats('IT', 'GE_ARQ_SAL_MEN_AHORROS');
    END;
    BEGIN
      dbms_stats.gather_table_stats('IT', 'GE_ARQ_SAL_MEN_CTACTES');
    END;
  END lp_car_tab_temporales;

  PROCEDURE lp_act_ge_arq_cli_cue_sal_act IS
  BEGIN
    --Saldo Actual--
    UPDATE ge_arq_cli_cuentas a
    SET a.sal_actual =
        (SELECT CASE
                  WHEN a.cod_modalidad IN (42, 48, 49) THEN
                   a.sal_anterior - SUM(nvl(y.mto_credito, 0)) +
                   SUM(nvl(y.mto_debito, 0))
                  ELSE
                   a.sal_anterior + SUM(nvl(y.mto_credito, 0)) -
                   SUM(nvl(y.mto_debito, 0))
                END
         FROM GE_ARQ_CLI_MOVIMIENTOS y
         WHERE y.nro_cuenta = a.nro_cuenta)
    WHERE EXISTS (SELECT 1
           FROM GE_ARQ_CLI_MOVIMIENTOS y
           WHERE y.nro_cuenta = a.nro_cuenta);
  END lp_act_ge_arq_cli_cue_sal_act;

  PROCEDURE lp_act_ge_arq_cli_cue_sal_pro IS
  BEGIN
    --Saldo Promedio Ctacte--
    UPDATE ge_arq_cli_cuentas a
    SET a.sal_promedio =
        (SELECT nvl(z.sal_acu_diario, 0) / nvl(z.can_dia_acumulado, 0)
         FROM ge_arq_sal_men_ctactes z
         WHERE z.nro_cuenta = a.nro_cuenta
         AND z.ano = v_ano
         AND z.mes = v_mes
         AND z.can_dia_acumulado > 0)
    WHERE a.cod_modalidad = 41
    AND EXISTS (SELECT 1
           FROM ge_arq_sal_men_ctactes z
           WHERE z.nro_cuenta = a.nro_cuenta
           AND z.ano = v_ano
           AND z.mes = v_mes
           AND z.can_dia_acumulado > 0);
  
    --Saldo Promedio Vista--
    UPDATE ge_arq_cli_cuentas a
    SET a.sal_promedio =
        (SELECT nvl(z.sal_acu_diario, 0) / nvl(z.can_dia_acumulado, 0)
         FROM ge_arq_sal_men_ahorros z
         WHERE z.nro_cuenta = a.nro_cuenta
         AND z.ano = v_ano
         AND z.mes = v_mes
         AND z.can_dia_acumulado > 0)
    WHERE a.cod_modalidad = 31
    AND EXISTS (SELECT 1
           FROM ge_arq_sal_men_ahorros z
           WHERE z.nro_cuenta = a.nro_cuenta
           AND z.ano = v_ano
           AND z.mes = v_mes
           AND z.can_dia_acumulado > 0);
  
  END lp_act_ge_arq_cli_cue_sal_pro;

  PROCEDURE lp_act_ge_arq_cli_cue_tip_cta IS
  
  BEGIN
    --Actualiza Tipo de Cuenta y Tasa Nominal--
    UPDATE ge_arq_cli_cuentas a
    SET a.tip_cuenta = (CASE
                          WHEN a.sal_actual < 0 THEN
                           'P'
                          ELSE
                           'A'
                        END)
    WHERE a.cod_modalidad = 41;
  END lp_act_ge_arq_cli_cue_tip_cta;

  PROCEDURE lp_act_ge_arq_cli_cue_tasas IS
    --Cursores--
    CURSOR c_cta_cte IS
      SELECT a.rowid registro,
             fug_obt_val_tasa(b.cod_modulo, b.cod_modalidad, b.cod_oficina, b.nro_cuenta, b.cod_moneda, a.sal_promedio, b.tas_personalizada, NULL, 550, a.fec_extracto) tas_nominal
      FROM ge_arq_cli_cuentas a, cc_cta_corrientes b
      WHERE a.cod_modalidad = 41
      AND a.nro_cuenta = b.nro_cuenta;
  
    CURSOR c_cta_vis IS
      SELECT a.rowid registro,
             fug_obt_val_tasa(b.cod_modulo, b.cod_modalidad, b.cod_oficina, b.nro_cuenta, b.cod_moneda, a.sal_promedio, b.tas_personalizada, b.cod_tasa, NULL, a.fec_extracto) tas_nominal
      FROM ge_arq_cli_cuentas a, ah_cta_vistas b
      WHERE a.cod_modalidad = 31
      AND a.nro_cuenta = b.nro_cuenta;
  
    CURSOR c_cta_cda IS
      SELECT a.rowid registro,
             fug_obt_val_tasa(b.cod_modulo, b.cod_modalidad, b.cod_oficina, b.nro_cuenta, b.cod_moneda, b.capital, b.tas_personalizada, b.cod_tasa, NULL, a.fec_extracto) tas_nominal,
             ---
             b.tip_capitalizacion,
             (b.fec_vencimiento - b.fec_apertura) dia_plazo,
             b.capital
      FROM ge_arq_cli_cuentas a, ah_cta_certificados b
      WHERE a.cod_modalidad IN (33, 34, 35)
      AND a.nro_cuenta = b.nro_cuenta;
  
  BEGIN
    --Actualiza Tasa Nominal Cta.Cte.--
    FOR det IN c_cta_cte
    LOOP
      UPDATE ge_arq_cli_cuentas a
      SET a.tas_nominal  = det.tas_nominal,
          a.tas_efectiva = pas_bcp.FU_OBT_TAE(det.tas_nominal, 30)
      WHERE ROWID = det.registro;
    END LOOP;
  
    --Actualiza Tasa Nominal Vista--
    FOR det IN c_cta_vis
    LOOP
      UPDATE ge_arq_cli_cuentas a
      SET a.tas_nominal  = det.tas_nominal,
          a.tas_efectiva = pas_bcp.FU_OBT_TAE(det.tas_nominal, 30)
      WHERE ROWID = det.registro;
    END LOOP;
  
    --Actualiza Tasa Nominal CDA--
    FOR det IN c_cta_cda
    LOOP
      UPDATE ge_arq_cli_cuentas a
      SET a.tas_nominal  = det.tas_nominal,
          a.tas_efectiva = pas_bcp.FU_OBT_TAE_CDA(det.tip_capitalizacion, det.tas_nominal, det.dia_plazo, det.capital)
      WHERE ROWID = det.registro;
    END LOOP;
  
  END lp_act_ge_arq_cli_cue_tasas;

  PROCEDURE lp_act_ge_arq_cli_cue_tie_com IS
  BEGIN
    --Actualiza Cta Comb. Cta.Cte--
    UPDATE ge_arq_cli_cuentas a
    SET a.nro_cta_combinada =
        (SELECT z.nro_cta_ahorro
         FROM cc_cta_combinadas z, cc_cta_corrientes k
         WHERE z.nro_cta_cte = a.nro_cuenta
         AND k.nro_cuenta = a.nro_cuenta
         AND k.cta_combinada = 'S')
    WHERE a.cod_modalidad = 41
    AND EXISTS (SELECT 1
           FROM cc_cta_combinadas z, cc_cta_corrientes k
           WHERE z.nro_cta_cte = a.nro_cuenta
           AND k.nro_cuenta = a.nro_cuenta
           AND k.cta_combinada = 'S');
  
    --Actualiza Cta Comb. Vista--
    UPDATE ge_arq_cli_cuentas a
    SET a.nro_cta_combinada =
        (SELECT z.nro_cta_cte
         FROM cc_cta_combinadas z, ah_cta_vistas k
         WHERE z.nro_cta_ahorro = a.nro_cuenta
         AND k.nro_cuenta = a.nro_cuenta
         AND k.cta_combinada = 'S')
    WHERE a.cod_modalidad = 31
    AND EXISTS (SELECT 1
           FROM cc_cta_combinadas z, ah_cta_vistas k
           WHERE z.nro_cta_ahorro = a.nro_cuenta
           AND k.nro_cuenta = a.nro_cuenta
           AND k.cta_combinada = 'S');
  
  END lp_act_ge_arq_cli_cue_tie_com;

  PROCEDURE lp_act_ge_arq_cli_dat_fun_bco IS
  BEGIN
    --Actualiza funcionario existe en ba_usuarios--
    UPDATE ge_arq_clientes a
    SET a.funcionario = 'S'
    WHERE a.funcionario = 'N'
    AND EXISTS (SELECT 1
           FROM ba_usuarios x
           WHERE x.cod_persona = a.cod_persona
           AND x.estado = 'A');
  
    --Actualiza funcionario con segmento--
    UPDATE ge_arq_clientes a
    SET a.funcionario = 'S'
    WHERE a.funcionario = 'N'
    AND EXISTS (SELECT 1
           FROM ge_clientes x
           WHERE x.cod_persona = a.cod_persona
           AND x.cod_seg_cliente = v_cod_seg_fun);
  
  END lp_act_ge_arq_cli_dat_fun_bco;

  PROCEDURE lp_act_ge_arq_cli_cue_sal_men IS
  BEGIN
    --Actualizar saldos mensuales ctacte--
    UPDATE CC_SAL_MENSUALES a
    SET SAL_ULT_EXTRACTO =
        (SELECT x.sal_actual
         FROM ge_arq_cli_cuentas x
         WHERE x.nro_cuenta = a.nro_cuenta
         AND x.fre_extracto = 'M')
    WHERE ANO = v_ano
    AND MES = v_mes
    AND EXISTS (SELECT 1
           FROM ge_arq_cli_cuentas x
           WHERE x.nro_cuenta = a.nro_cuenta
           AND x.fre_extracto = 'M');
    ----Actualizar saldos mensuales vista--
    UPDATE AH_SAL_MENSUALES a
    SET SAL_ULT_EXTRACTO =
        (SELECT x.sal_actual
         FROM ge_arq_cli_cuentas x
         WHERE x.nro_cuenta = a.nro_cuenta
         AND x.fre_extracto = 'M')
    WHERE ANO = v_ano
    AND MES = v_mes
    AND A.COD_MODALIDAD = 31
    AND EXISTS (SELECT 1
           FROM ge_arq_cli_cuentas x
           WHERE x.nro_cuenta = a.nro_cuenta
           AND x.fre_extracto = 'M');
  END lp_act_ge_arq_cli_cue_sal_men;

  PROCEDURE lp_ins_ge_arq_cli_cue_mov_ret IS
  BEGIN
    INSERT INTO GE_ARQ_CLI_MOV_RETENIDOS
      SELECT v_fec_actual,
             AH_RETENCIONES.COD_RETENCION,
             AH_RETENCIONES.NRO_DOCUMENTO,
             x.cod_persona,
             AH_RETENCIONES.SAL_RETENIDO,
             AH_RETENCIONES.FEC_INICIO,
             AH_RETENCIONES.FEC_FINAL,
             AH_RETENCIONES.NRO_CUENTA,
             AH_RETENCIONES.COD_MODULO,
             AH_RETENCIONES.COD_MODALIDAD,
             NULL,
             NULL,
             NULL,
             NULL,
             x.fre_extracto,
             x.cod_extracto,
             NULL
      FROM AH_RETENCIONES, ge_arq_cli_cuentas x
      WHERE AH_RETENCIONES.NRO_CUENTA = x.nro_cuenta
      AND x.fec_extracto = v_fec_actual
      AND AH_RETENCIONES.LIBERADO = 'N'
      AND AH_RETENCIONES.COD_MODALIDAD IN (31, 41)
      AND AH_RETENCIONES.FEC_FINAL > v_fec_actual;
  
    --Calculo de Estadisticas--
    BEGIN
      dbms_stats.gather_table_stats('IT', 'GE_ARQ_CLI_MOV_RETENIDOS');
    END;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20050, 'ERROR. En lp_tra_ge_movimientos.' ||
                               SQLERRM);
  END lp_ins_ge_arq_cli_cue_mov_ret;

  PROCEDURE lp_ins_ge_arq_cli_cue_mov_pen IS
  BEGIN
    INSERT INTO GE_ARQ_CLI_MOV_PENDIENTES
      SELECT v_fec_actual,
             x.fre_extracto,
             x.cod_extracto,
             pen.cod_transaccion,
             fug_obt_des_transaccion(cod_mod_padre, cod_mad_padre, cod_tra_padre) descripcion,
             pen.monto,
             x.cod_persona,
             pen.fecha,
             pen.nro_cuenta,
             pen.cod_modulo,
             pen.cod_modalidad,
             NULL,
             NULL,
             NULL,
             NULL,
             NULL,
             NULL
      FROM GE_MOV_PENDIENTES pen, ge_arq_cli_cuentas x
      WHERE pen.NRO_CUENTA = x.nro_cuenta
      AND pen.COD_MODALIDAD IN (31, 41)
      AND pen.ESTADO = 'I'
      AND pen.FECHA <= v_fec_actual;
  
    --Calculo de Estadisticas--
    BEGIN
      dbms_stats.gather_table_stats('IT', 'GE_ARQ_CLI_MOV_PENDIENTES');
    END;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20060, 'ERROR. En lp_tra_ge_movimientos.' ||
                               SQLERRM);
  END lp_ins_ge_arq_cli_cue_mov_pen;

  PROCEDURE lp_ins_ge_arq_extractos IS
  BEGIN
    INSERT INTO GE_ARQ_EXTRACTOS
      (NRO_CUENTA,
       COD_MODULO,
       COD_MODALIDAD,
       NRO_FOLIO,
       FEC_ULT_EXTRACTO,
       SAL_ULT_EXTRACTO,
       NOM_TABLA,
       COD_PERSONA)
      SELECT x.nro_cuenta,
             decode(x.cod_modalidad, 31, 3, 4),
             x.cod_modalidad,
             x.nro_folio,
             x.fec_extracto,
             x.sal_actual,
             CASE
               WHEN x.cod_modalidad = 41 THEN
                'CC_CTA_CORRIENTES'
               WHEN x.cod_modalidad = 31 THEN
                'AH_CTA_VISTAS'
               ELSE
                'CC_CTA_BANCARIAS'
             END,
             x.cod_persona
      FROM ge_arq_cli_cuentas x
      WHERE EXISTS (SELECT 1
             FROM ge_arq_cli_movimientos z
             WHERE z.nro_cuenta = x.nro_cuenta);
  
    --Calculo de Estadisticas--
    BEGIN
      dbms_stats.gather_table_stats('IT', 'GE_ARQ_EXTRACTOS');
    END;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'ERROR. ge_arq_extractos.' || SQLERRM);
  END lp_ins_ge_arq_extractos;

  PROCEDURE lp_ins_ge_arq_resumenes IS
  BEGIN
    INSERT INTO GE_ARQ_RESUMENES
      (COD_PERSONA,
       FEC_EXTRACTO,
       TIPO,
       NRO_CUENTA,
       MTO_INTERES,
       COD_EXTRACTO,
       FRE_EXTRACTO,
       COD_MODALIDAD,
       COD_MONEDA,
       FEC_VENCIMIENTO,
       MTO_CAPITAL,
       SAL_DISPONIBLE)
    
      SELECT y.cod_persona,
             y.fec_extracto,
             '5',
             x.nro_cuenta,
             nvl(z.sal_total, 0) - nvl(z.sal_retenido, 0),
             y.cod_extracto,
             y.fre_extracto,
             z.cod_modalidad,
             z.cod_moneda,
             x.fec_vto_linea,
             x.mto_linea,
             nvl(x.mto_linea, 0) +
             (nvl(z.sal_total, 0) - nvl(z.sal_retenido, 0) -
              nvl(z.sal_bloqueado, 0))
      FROM ge_arq_cli_cuentas y,
           CC_CTA_CORRIENTES z,
           (SELECT x.nro_cuenta,
                   MIN(x.fec_vencimiento) fec_vto_linea,
                   SUM(nvl(x.monto, 0)) mto_linea
            FROM cc_lin_sobregiros x
            WHERE x.estado = 'A'
            AND v_fec_actual BETWEEN x.fec_inicio AND x.fec_vencimiento
            AND x.fec_vencimiento IS NOT NULL
            AND x.nro_cuenta IS NOT NULL
            GROUP BY x.nro_cuenta) x
      WHERE z.nro_cuenta = y.nro_cuenta
      AND x.nro_cuenta = y.nro_cuenta
      AND z.cod_modalidad = 41; --Cuentas Corrientes--
    --Calculo de Estadisticas--
    BEGIN
      dbms_stats.gather_table_stats('IT', 'GE_ARQ_RESUMENES');
    END;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'ERROR. ge_arq_extractos.' || SQLERRM);
  END lp_ins_ge_arq_resumenes;

  FUNCTION lf_obt_mto_bloqueado(p_nro_cuenta IN VARCHAR2) RETURN NUMBER IS
    vmto_bloqueo NUMBER DEFAULT 0;
  BEGIN
    SELECT nvl(SUM(monto), 0)
    INTO vmto_bloqueo
    FROM ge_bloqueos x
    WHERE EXISTS (SELECT 1
           FROM ge_par_causales y
           WHERE y.cod_causa = x.cod_causa
           AND y.parametro = 'COD_CAU_BLO_EXT'
           AND y.val_parametro = 'S')
    AND nro_cuenta = p_nro_cuenta;
    RETURN vmto_bloqueo;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 0;
    WHEN OTHERS THEN
      RETURN 0;
  END;

  PROCEDURE lp_eli_ext_generado IS
  BEGIN
    DELETE GE_EXT_CLI_MOVIMIENTOS
    WHERE FEC_EXTRACTO = V_FEC_ACTUAL
    AND INSTR(V_FRE_GENERAR, ',' || UPPER(FRE_EXTRACTO) || ',') > 0;
    DELETE GE_EXT_RESUMENES A
    WHERE FEC_EXTRACTO = V_FEC_ACTUAL
    AND INSTR(V_FRE_GENERAR, ',' || UPPER(FRE_EXTRACTO) || ',') > 0;
    DELETE GE_EXT_CLI_CUENTAS A
    WHERE FEC_EXTRACTO = V_FEC_ACTUAL
    AND INSTR(V_FRE_GENERAR, ',' || UPPER(FRE_EXTRACTO) || ',') > 0;
    DELETE GE_EXT_CLIENTES
    WHERE FEC_EXTRACTO = V_FEC_ACTUAL
    AND INSTR(V_FRE_GENERAR, ',' || UPPER(FRE_EXTRACTO) || ',') > 0;
    DELETE GE_EXT_CLI_MOV_RETENIDOS
    WHERE FEC_EXTRACTO = V_FEC_ACTUAL
    AND INSTR(V_FRE_GENERAR, ',' || UPPER(FRE_EXTRACTO) || ',') > 0;
    DELETE GE_EXT_CLI_MOV_PENDIENTES
    WHERE FEC_EXTRACTO = V_FEC_ACTUAL
    AND INSTR(V_FRE_GENERAR, ',' || UPPER(FRE_EXTRACTO) || ',') > 0;
    DELETE GE_CTA_EXTRACTOS_TMP
    WHERE FEC_ULT_EXTRACTO = V_FEC_ACTUAL;
  END;

  FUNCTION lf_ver_ext_generado RETURN NUMBER IS
    v_conteo NUMBER(14) := 0;
  BEGIN
    v_lugar := 'lf_ver_ext_generado';
    -- Verificar mensajes de Extractos...
    SELECT COUNT(*)
    INTO v_conteo
    FROM GE_ARQ_CLIENTES
    WHERE FEC_EXTRACTO = v_fec_actual
    AND INSTR(V_FRE_GENERAR, ',' || UPPER(FRE_EXTRACTO) || ',') > 0;
    RETURN v_conteo;
  END lf_ver_ext_generado;

  PROCEDURE lp_obtener_datos_del_cliente IS
  BEGIN
    v_lugar := 'lp_obtener_datos_del_cliente';
  
    SELECT ge_clientes.cod_usu_oficial,
           ba_USUARIOS.TELEFONO,
           BA_USUARIOS.NRO_INTERNO,
           ge_clientes.tip_extracto,
           ge_clientes.cod_oficina,
           ge_clientes.cli_confidencial,
           nom_completo,
           pap_cat.fu_obt_cat_crc(v_cod_persona, v_fec_actual, 'N'), /*ge_clientes.fec_ult_clasif,*/
           ge_clientes.cod_seg_cliente
    INTO v_cod_usu_oficial,
         v_tel_oficial,
         v_int_oficial,
         v_tip_extracto,
         v_cod_ofi_cliente,
         v_cli_confidencial,
         v_nom_cliente,
         v_cat_riesgo, /*v_fec_ult_clasif,*/
         v_cod_seg_cliente
    FROM ba_personas, BA_OFICINAS, BA_USUARIOS, GE_CLIENTES
    WHERE GE_CLIENTES.COD_PERSONA = V_COD_PERSONA
    AND BA_USUARIOS.COD_USUARIO = GE_CLIENTES.COD_USU_OFICIAL
    AND BA_OFICINAS.COD_OFICINA = BA_USUARIOS.COD_OFICINA
    AND ge_clientes.cod_persona = ba_personas.cod_persona;
  
    -- la ultima fecha calificada, DYDMR-10562
    BEGIN
      SELECT MAX(trunc(fec_insercion))
      INTO v_fec_ult_clasif
      FROM ge_cla_operaciones
      WHERE cod_persona = V_COD_PERSONA
      AND rownum = 1;
    EXCEPTION
      WHEN no_data_found THEN
        BEGIN
          SELECT MAX(fecha)
          INTO v_fec_ult_clasif
          FROM ge_cla_operaciones_his
          WHERE fecha >= add_months(v_fec_actual, -6)
          AND cod_persona = V_COD_PERSONA;
        EXCEPTION
          WHEN no_data_found THEN
            v_fec_ult_clasif := NULL;
          WHEN OTHERS THEN
            v_fec_ult_clasif := NULL;
        END;
      WHEN OTHERS THEN
        v_fec_ult_clasif := NULL;
    END;
    ---           
  EXCEPTION
    WHEN OTHERS THEN
      v_es_empleado      := 'N';
      v_tel_oficial      := NULL;
      v_int_oficial      := NULL;
      v_tip_extracto     := NULL;
      v_cod_ofi_cliente  := NULL;
      v_cli_confidencial := NULL;
      v_cat_riesgo       := NULL;
      v_fec_ult_clasif   := NULL;
      v_cod_usu_oficial  := NULL;
      v_nom_cliente      := NULL;
      v_cod_seg_cliente  := NULL;
  END lp_obtener_datos_del_cliente;

  PROCEDURE lp_dir_envio IS
  BEGIN
    v_lugar := 'lp_dir_envio';
    ---0. limpio los valores a leer ------------------------------------
    v_dir_cliente := NULL;
    v_pri_obs_dir := NULL;
    v_seg_obs_dir := NULL;
    v_cod_pais    := NULL;
    v_cod_ciudad  := NULL;
    v_des_barrio  := NULL;
    v_tel_cliente := NULL;
    v_tip_envio   := NULL;
    v_direccion   := NULL;
    ---1. Leo la vista de acuerdo a los datos que me pasa --------------
    SELECT substr(gv.dir_envio, 1, 89),
           gv.prim_observacion,
           gv.seg_observacion,
           gv.cod_pais,
           gv.cod_ciudad,
           gv.des_barrio,
           gv.tel_principal,
           gv.tip_envio,
           
           gv.piso,
           gv.departamento,
           gv.edificio
    INTO v_dir_cliente,
         v_pri_obs_dir,
         v_seg_obs_dir,
         v_cod_pais,
         v_cod_ciudad,
         v_des_barrio,
         v_tel_cliente,
         v_tip_envio,
         
         v_piso,
         v_departamento,
         v_edificio
    --FROM gv_dir_envios gv
    FROM ge_arq_dir_envios gv
    WHERE
    --Cliente gen. Individual (direccion personalizada por cuenta)
     ((gv.nro_cuenta = v_nro_cuenta AND nvl(v_tip_gen_extracto, 'C') = 'I' AND
     gv.COD_PERSONA = v_cod_persona AND nvl(v_es_nomina, 'N') = 'N') OR
     --Cliente gen. Consolidada (direccion personalizada por direccion de envio)
     (gv.nro_cuenta IS NULL AND nvl(v_tip_gen_extracto, 'C') = 'C' AND
     gv.COD_PERSONA = v_cod_persona AND nvl(v_es_nomina, 'N') = 'N') OR
     --Cliente NOMINA gen. Consolidada/individual (se tiene que traer la direccion principal del ente.)
     (gv.nro_cuenta IS NULL AND nvl(v_es_nomina, 'N') = 'S' AND
     gv.cod_persona = v_cod_per_ente AND gv.nro_cuenta IS NULL));
    --se obtiene el piso-edificio-dpto si es que no se retiene el extracto
    IF instr(v_dir_cliente, 'RETENER EN ') = 0 THEN
      IF v_piso IS NOT NULL THEN
        v_direccion := ' Piso: ' || v_piso;
      END IF;
      IF v_departamento IS NOT NULL THEN
        v_direccion := v_direccion || ' Dpto.: ' || v_departamento;
      END IF;
    
      IF v_edificio IS NOT NULL THEN
        v_direccion := v_direccion || ' Edificio: ' || v_edificio;
      END IF;
      v_dir_cliente := substr(v_dir_cliente || v_direccion, 1, 89);
    END IF;
    ---------------------------------------------------------------------
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN TOO_MANY_ROWS THEN
      NULL;
    WHEN OTHERS THEN
      v_lugar := substr(v_cod_persona || '-' || v_dir_cliente, 1, 2000);
  END lp_dir_envio;

  PROCEDURE lp_generar_ctacte IS
  
    --Variables--
    v_sal_ult_extracto  NUMBER(18, 2) DEFAULT 0;
    v_mto_debito        NUMBER(18, 2);
    v_mto_credito       NUMBER(18, 2);
    v_EXISTE            VARCHAR2(01) := 'N';
    v_imprime_extracto  VARCHAR2(1);
    v_SAL_PROMEDIO      cc_sal_mensuales.sal_acu_deudor%TYPE;
    v_nro_cta_combinada cc_cta_combinadas.nro_cta_ahorro%TYPE;
    v_val_tasa          ge_tas_fechas.val_tasa%TYPE;
    v_val_tae           ge_tas_fechas.val_tasa%TYPE;
    v_tipo              GE_ARQ_cli_cuentas.tip_cuenta%TYPE;
    ----------------------------------
    -- CURSOR DEL ARCHIVO PRINCIPAL --
    ----------------------------------
    CURSOR MAE_CUE IS
      SELECT GE_CTA_CLIENTES.COD_MODULO,
             GE_CTA_CLIENTES.COD_MODALIDAD,
             GE_CTA_CLIENTES.COD_OFICINA,
             GE_CTA_CLIENTES.NRO_CUENTA,
             CC_CTA_CORRIENTES.COD_MONEDA,
             CC_CTA_CORRIENTES.SAL_ULT_EXTRACTO,
             nvl(CC_CTA_CORRIENTES.NRO_FOLIO, 0) + 1 NRO_FOLIO,
             CC_CTA_CORRIENTES.DENOMINACION,
             CC_CTA_CORRIENTES.SAL_RET_BATCH,
             NVL(CC_CTA_CORRIENTES.FEC_ULT_EXTRACTO, CC_CTA_CORRIENTES.FEC_APERTURA - 1) FEC_ULT_EXTRACTO,
             nvl(bpd.val_parametro, 'C') SEPARADO,
             CC_CTA_CORRIENTES.ROWID REGISTRO,
             cc_cta_corrientes.cta_combinada,
             cc_cta_corrientes.sal_total - cc_cta_corrientes.sal_retenido saldo,
             cc_cta_corrientes.tas_personalizada,
             cc_cta_corrientes.sal_bloqueado,
             cc_cta_corrientes.cod_ente,
             decode(cc_cta_corrientes.cod_ente, NULL, 'N', 'S') es_nomina, --se obtiene si es nomina
             NVL(GE_PAQ_CUENTAS.COD_PAQUETE, 0) COD_PAQUETE,
             Z.COD_PERSONA cod_per_ente,
             h.mto_bloqueo,
             f.sal_blo_anterior /*, x.mto_linea, x.fec_vto_linea*/
      FROM GE_DIR_ENVIOS,
           CC_CTA_CORRIENTES,
           GE_CTA_CLIENTES,
           GE_PAQ_CUENTAS,
           ba_per_dat_adicionales bpd,
           GE_ENTES Z,
           (SELECT h.nro_cuenta, SUM(nvl(h.monto, 0)) mto_bloqueo
            FROM ge_bloqueos h
            WHERE EXISTS (SELECT 1
                   FROM ge_par_causales y
                   WHERE y.cod_causa = h.cod_causa
                   AND y.parametro = 'COD_CAU_BLO_EXT'
                   AND y.val_parametro = 'S')
            GROUP BY h.nro_cuenta) h,
           (SELECT f.NRO_CUENTA,
                   FEC_EXTRACTO,
                   SUM(Nvl(f.sal_bloqueado, 0)) sal_blo_anterior
            FROM GE_ext_cli_cuentas f, cc_cta_corrientes g
            WHERE g.nro_cuenta = f.nro_cuenta
            AND f.fec_extracto = g.fec_ult_extracto
            GROUP BY f.NRO_CUENTA, FEC_EXTRACTO) f
      WHERE GE_DIR_ENVIOS.COD_PERSONA(+) = GE_CTA_CLIENTES.COD_PERSONA --CROGENEXT-13 Sergio Servin 06/08/2014,
      AND GE_DIR_ENVIOS.NRO_CUENTA(+) = GE_CTA_CLIENTES.NRO_CUENTA --CROGENEXT-13 Sergio Servin 06/08/2014,
      AND GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
      AND GE_CTA_CLIENTES.RELACION = 'P'
      AND CC_CTA_CORRIENTES.COD_MODULO = GE_CTA_CLIENTES.COD_MODULO
      AND CC_CTA_CORRIENTES.COD_MODALIDAD = GE_CTA_CLIENTES.COD_MODALIDAD
      AND CC_CTA_CORRIENTES.COD_OFICINA = GE_CTA_CLIENTES.COD_OFICINA
      AND CC_CTA_CORRIENTES.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
      AND CC_CTA_CORRIENTES.FRE_EXTRACTO = v_frecuencia --CROGENEXT-13 Sergio Servin 06/08/2014
      AND bpd.cod_persona(+) = GE_CTA_CLIENTES.COD_PERSONA
      AND bpd.parametro(+) = 'TIP_GEN_EXTRACTOS'
      AND ((CC_CTA_CORRIENTES.ESTADO NOT IN ('C', 'P')) OR
             (CC_CTA_CORRIENTES.ESTADO IN ('C', 'P') AND
             CC_CTA_CORRIENTES.FEC_ULT_MOVIMIENTO >= v_pri_dia_mes_habil AND
             CC_CTA_CORRIENTES.FEC_ULT_MOVIMIENTO >
             NVL(CC_CTA_CORRIENTES.FEC_ULT_EXTRACTO, CC_CTA_CORRIENTES.FEC_APERTURA - 1)))
      AND GE_PAQ_CUENTAS.NRO_CUENTA(+) = GE_CTA_CLIENTES.NRO_CUENTA
      AND GE_PAQ_CUENTAS.COD_PERSONA(+) = GE_CTA_CLIENTES.COD_PERSONA
           --Obtiene persona de ente relacionado--
      AND Z.COD_ENTE(+) = cc_cta_corrientes.cod_ente
           --Obtiene Monto de Bloqueo--
      AND H.NRO_CUENTA(+) = cc_cta_corrientes.nro_cuenta
           --Ultimo Saldo Bloqueado--
      AND f.NRO_CUENTA(+) = cc_cta_corrientes.nro_cuenta
      AND f.FEC_EXTRACTO(+) = cc_cta_corrientes.fec_ult_extracto
      ORDER BY GE_PAQ_CUENTAS.COD_MODULO,
               GE_PAQ_CUENTAS.COD_MODALIDAD,
               GE_PAQ_CUENTAS.COD_SUB_MODALIDAD,
               GE_PAQ_CUENTAS.NRO_CUENTA;
  
  BEGIN
    v_lugar := 'lp_generar_ctacte';
    FOR AV IN MAE_CUE
    LOOP
      --limpio variables
      v_SAL_PROMEDIO      := NULL;
      v_nro_cta_combinada := NULL;
      v_val_tasa          := NULL;
      v_val_tae           := NULL;
      v_cod_per_ente      := av.cod_per_ente;
      --- asigno el codigo de extracto unico -----------------
      v_nro_cuenta       := av.nro_cuenta;
      v_sal_ult_extracto := nvl(AV.SAL_ULT_EXTRACTO, 0);
      v_mto_bloqueo      := av.mto_bloqueo;
      v_fec_movimiento   := AV.FEC_ULT_EXTRACTO;
      v_tip_gen_extracto := AV.SEPARADO; --se obtiene si es individual o consolidado
      v_es_nomina        := AV.ES_NOMINA;
    
      --DYDMR-9148 - Incidencia SAU - ITGF - Generación de Base de Datos para Envio
      --Obtener valor parametrizado del ente, en caso de no recuperar valor por defecto si se debe utilizar su dirección
      IF v_es_nomina = 'S'
         AND av.cod_per_ente IS NOT NULL THEN
        v_uti_dir_ente := nvl(fug_obt_parentes(av.cod_ente, 'UTI_DIR_ENTE_EXTRACTO'), 'S');
      END IF;
    
      --Si el cliente es nómina pero el ente tiene parametrizado no utilizar su dirección se debe asignar es_Nomina = N
      IF v_es_nomina = 'S'
         AND v_uti_dir_ente = 'N' THEN
        v_es_nomina    := 'N';
        v_cod_per_ente := NULL;
      END IF;
    
      V_EXISTE := 'N';
      IF AV.SEPARADO = 'I'
         OR AV.COD_PAQUETE > 0 THEN
        -- es una direccion especifica, no enviar en ext.unico --
        v_cod_ext_separado := v_cod_ext_separado + 1;
        v_cod_extracto     := v_cod_ext_separado;
        ---------------------------------------------------------
      ELSE
        v_cod_extracto := 1;
        --- verifico si ya existe una cabecera del extracto unico
        BEGIN
          SELECT 'S'
          INTO V_EXISTE
          FROM GE_ARQ_CLIENTES
          WHERE GE_ARQ_CLIENTES.COD_PERSONA = v_cod_persona
          AND GE_ARQ_CLIENTES.FEC_EXTRACTO = v_fec_actual
          AND GE_ARQ_CLIENTES.FRE_EXTRACTO = v_frecuencia
          AND GE_ARQ_CLIENTES.COD_EXTRACTO = v_cod_extracto;
          V_EXISTE := 'S';
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            V_EXISTE := 'N';
          WHEN TOO_MANY_ROWS THEN
            V_EXISTE := 'S';
          WHEN OTHERS THEN
            dbms_output.put_line('ERROR al Buscar el Extr.del Cliente.CONTINUO.' ||
                                 SQLERRM);
            V_EXISTE := 'N';
        END;
      END IF;
      IF V_EXISTE = 'N' THEN
        -- busco los datos del cliente ---------------------------
        lp_obtener_datos_del_cliente;
        lp_dir_envio;
        v_imprime_extracto := v_tip_extracto;
        v_lugar            := '1-insert GE_ARQ_CLIENTES ' || v_cod_persona || '-' ||
                              v_dir_cliente;
        INSERT INTO GE_ARQ_CLIENTES
          (COD_PERSONA,
           FEC_EXTRACTO,
           FRE_EXTRACTO,
           FUNCIONARIO,
           NOM_CLIENTE,
           DIRECCION,
           TELEFONO,
           COD_USU_OFICIAL,
           COD_PAIS,
           COD_CIUDAD,
           TEL_OFICIAL,
           NRO_INTERNO,
           COD_EXTRACTO,
           DET_DIRECCION,
           OBSERVACION,
           BARRIO,
           COD_MENSAJE,
           tip_impresion,
           CLI_CONFIDENCIAL,
           COD_OFICINA,
           Cat_Riesgo,
           Fec_Ult_Clasif,
           Cod_Per_Empresa,
           tip_direccion)
        VALUES
          (v_cod_persona,
           v_fec_actual,
           v_frecuencia,
           'N',
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
           decode(AV.SEPARADO, 'I', av.cod_oficina, v_cod_ofi_cliente),
           v_cat_riesgo,
           v_fec_ult_clasif,
           v_cod_per_ente,
           v_tip_envio);
        v_INSERTA := 'S';
      END IF;
    
      v_sal_blo_anterior := av.sal_blo_anterior;
      INSERT INTO GE_ARQ_CLI_CUENTAS
        (GE_ARQ_CLI_CUENTAS.COD_PERSONA,
         GE_ARQ_CLI_CUENTAS.FEC_EXTRACTO,
         GE_ARQ_CLI_CUENTAS.TIP_CUENTA,
         GE_ARQ_CLI_CUENTAS.COD_OFICINA,
         GE_ARQ_CLI_CUENTAS.COD_MODALIDAD,
         GE_ARQ_CLI_CUENTAS.NRO_CUENTA,
         GE_ARQ_CLI_CUENTAS.COD_MONEDA,
         GE_ARQ_CLI_CUENTAS.SAL_ANTERIOR,
         GE_ARQ_CLI_CUENTAS.SAL_ACTUAL,
         GE_ARQ_CLI_CUENTAS.NRO_FOLIO,
         GE_ARQ_CLI_CUENTAS.SAL_A_CONFIRMAR,
         GE_ARQ_CLI_CUENTAS.COD_EXTRACTO,
         GE_ARQ_CLI_CUENTAS.FRE_EXTRACTO,
         Sal_Promedio,
         nro_cta_combinada,
         Tas_Nominal,
         Tas_Efectiva,
         GE_ARQ_CLI_CUENTAS.SAL_BLOQUEADO,
         GE_ARQ_CLI_CUENTAS.COD_PER_EMPRESA,
         SAL_BLO_ANTERIOR)
      VALUES
        (v_cod_persona,
         v_fec_actual,
         v_tipo, --'A',
         AV.COD_OFICINA,
         AV.COD_MODALIDAD,
         AV.NRO_CUENTA,
         AV.COD_MONEDA,
         v_sal_ult_extracto,
         NVL(v_sal_ult_extracto, 0) + NVL(v_mto_credito, 0) -
         NVL(v_mto_debito, 0),
         AV.NRO_FOLIO,
         AV.SAL_RET_BATCH,
         v_cod_extracto,
         v_frecuencia,
         v_sal_promedio,
         v_nro_cta_combinada,
         v_val_tasa,
         v_val_tae,
         v_mto_bloqueo,
         v_cod_per_ente,
         v_sal_blo_anterior);
    END LOOP;
  END lp_generar_ctacte;

  PROCEDURE lp_generar_ctaban IS
    v_sal_ult_extracto NUMBER(18, 2) DEFAULT 0;
    v_mto_debito       NUMBER(18, 2);
    v_mto_credito      NUMBER(18, 2);
    v_existe           VARCHAR2(1) := 'N';
    v_imprime_extracto VARCHAR2(1);
    ----------------------------------
    -- CURSOR DEL ARCHIVO PRINCIPAL --
    ----------------------------------
    CURSOR cuentas IS
      SELECT t.cod_modulo,
             t.cod_modalidad,
             t.cod_oficina,
             t.nro_cuenta,
             c.cod_moneda,
             c.sal_ult_extracto,
             nvl(c.nro_folio, 0) + 1 nro_folio,
             c.denominacion,
             c.sal_ret_batch,
             nvl(c.fec_ult_extracto, c.fec_apertura - 1) fec_ult_extracto,
             nvl(bpd.val_parametro, 'C') SEPARADO,
             c.rowid registro,
             c.sal_bloqueado
      FROM ge_dir_envios          d,
           cc_cta_bancarias       c,
           ge_cta_clientes        t,
           ba_per_dat_adicionales bpd
      WHERE d.cod_persona(+) = t.cod_persona --CROGENEXT-13 Sergio Servin 06/08/2014
      AND d.nro_cuenta(+) = t.nro_cuenta --CROGENEXT-13 Sergio Servin 06/08/2014
      AND t.cod_persona = v_cod_persona
      AND t.relacion = 'P'
      AND c.cod_modulo = t.cod_modulo
      AND c.cod_modalidad = t.cod_modalidad
      AND c.cod_oficina = t.cod_oficina
      AND c.nro_cuenta = t.nro_cuenta
      AND c.fre_extracto = v_frecuencia --CROGENEXT-13 Sergio Servin 06/08/2014
      AND bpd.cod_persona(+) = T.COD_PERSONA
      AND bpd.parametro(+) = 'TIP_GEN_EXTRACTOS'
      AND ((c.estado NOT IN ('C', 'P')) OR
             (c.estado IN ('C', 'P') AND
             c.fec_ult_movimiento >= v_pri_dia_mes_habil AND
             c.fec_ult_movimiento >
             nvl(c.fec_ult_extracto, c.fec_apertura - 1)));
  
  BEGIN
    v_lugar := 'lp_generar_ctaban';
    FOR b IN cuentas
    LOOP
      --- asigno el codigo de extracto unico -----------------
      v_nro_cuenta := b.nro_cuenta;
      --WA:08/08/2014 Se agrega 49 para financiera Pais
      IF b.cod_modalidad IN (42, 48, 49) THEN
        -- BANCOS DEL PAIS
        v_sal_ult_extracto := nvl(b.sal_ult_extracto, 0) * -1;
      ELSE
        v_sal_ult_extracto := nvl(b.sal_ult_extracto, 0);
      END IF;
      v_mto_bloqueo := lf_obt_mto_bloqueado(b.nro_cuenta);
      v_existe      := 'N';
    
      IF b.separado = 'I' THEN
        -- es una direccion especifica, no enviar en ext.unico --
        v_cod_ext_separado := v_cod_ext_separado + 1;
        v_cod_extracto     := v_cod_ext_separado;
        ---------------------------------------------------------
      ELSE
        v_cod_extracto := 1;
        --- verifico si ya existe una cabecera del extracto unico
        BEGIN
          SELECT 'S'
          INTO v_existe
          FROM GE_ARQ_clientes
          WHERE cod_persona = v_cod_persona
          AND cod_extracto = v_cod_extracto
          AND fec_extracto = v_fec_actual
          AND fre_extracto = v_frecuencia;
          v_existe := 'S';
        EXCEPTION
          WHEN no_data_found THEN
            v_existe := 'N';
          WHEN too_many_rows THEN
            v_existe := 'S';
          WHEN OTHERS THEN
            dbms_output.put_line('ERROR al Buscar el Extr.del Cliente. CONTINUO. ' ||
                                 SQLERRM);
            v_existe := 'N';
        END;
      END IF;
      IF v_existe = 'N' THEN
        -- busco los datos del cliente ---------------------------
        lp_obtener_datos_del_cliente;
        lp_dir_envio;
        v_imprime_extracto := v_tip_extracto;
        v_lugar            := '1-insert GE_ARQ_CLIENTES ' || v_cod_persona || '-' ||
                              v_dir_cliente;
        BEGIN
          INSERT INTO GE_ARQ_clientes
            (cod_persona,
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
             tip_direccion)
          VALUES
            (v_cod_persona,
             v_fec_actual,
             v_frecuencia,
             'N',
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
             decode(b.SEPARADO, 'I', b.cod_oficina, v_cod_ofi_cliente),
             v_cat_riesgo,
             v_fec_ult_clasif,
             v_tip_envio);
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
        v_inserta := 'S';
      END IF;
      ----------------------------------------------------
      -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
      ----------------------------------------------------
      BEGIN
        --WA:08/08/2014 Se agrega 49 para financiera Pais
        IF b.cod_modalidad IN (42, 48, 49) THEN
          -- bancos del pais
          v_sal_actual := nvl(v_sal_ult_extracto, 0) -
                          nvl(v_mto_credito, 0) + nvl(v_mto_debito, 0);
        ELSE
          v_sal_actual := nvl(v_sal_ult_extracto, 0) - nvl(v_mto_debito, 0) +
                          nvl(v_mto_credito, 0);
        END IF;
        INSERT INTO GE_ARQ_cli_cuentas
          (cod_persona,
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
           sal_bloqueado)
        VALUES
          (v_cod_persona,
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
           v_mto_bloqueo);
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END LOOP;
  END lp_generar_ctaban;

  PROCEDURE lp_generar_vistas IS
  
    --Variables--
    v_sal_ult_extracto  NUMBER(18, 2) DEFAULT 0;
    v_mto_debito        NUMBER(18, 2);
    v_mto_credito       NUMBER(18, 2);
    v_EXISTE            VARCHAR2(01) := 'N';
    v_imprime_extracto  VARCHAR2(1);
    v_SAL_PROMEDIO      cc_sal_mensuales.sal_acu_deudor%TYPE;
    v_nro_cta_combinada cc_cta_combinadas.nro_cta_ahorro%TYPE;
    v_val_tasa          ge_tas_fechas.val_tasa%TYPE;
    v_val_tae           ge_tas_fechas.val_tasa%TYPE;
    ----------------------------------
    -- CURSOR DEL ARCHIVO PRINCIPAL --
    ----------------------------------
    CURSOR MAE_CUE IS
      SELECT GE_CTA_CLIENTES.COD_MODULO,
             GE_CTA_CLIENTES.COD_MODALIDAD,
             GE_CTA_CLIENTES.COD_OFICINA,
             GE_CTA_CLIENTES.NRO_CUENTA,
             AH_CTA_VISTAS.COD_MONEDA,
             AH_CTA_VISTAS.SAL_ULT_EXTRACTO,
             nvl(AH_CTA_VISTAS.NRO_FOLIO, 0) + 1 NRO_FOLIO,
             AH_CTA_VISTAS.DENOMINACION,
             AH_CTA_VISTAS.SAL_RET_BATCH,
             NVL(AH_CTA_VISTAS.FEC_ULT_EXTRACTO, AH_CTA_VISTAS.FEC_APERTURA - 1) FEC_ULT_EXTRACTO,
             nvl(bpd.val_parametro, 'C') SEPARADO,
             --
             AH_CTA_VISTAS.ROWID REGISTRO,
             ah_cta_vistas.cta_combinada,
             ah_cta_vistas.tas_personalizada,
             ah_cta_vistas.cod_tasa,
             AH_CTA_VISTAS.SAL_BLOQUEADO,
             AH_CTA_VISTAS.COD_ENTE,
             decode(AH_CTA_VISTAS.cod_ente, NULL, 'N', 'S') es_nomina, --se obtiene si es nomina
             NVL(GE_PAQ_CUENTAS.COD_PAQUETE, 0) COD_PAQUETE,
             Z.COD_PERSONA cod_per_ente,
             h.mto_bloqueo,
             f.sal_blo_anterior
      FROM GE_DIR_ENVIOS,
           AH_CTA_VISTAS,
           GE_CTA_CLIENTES,
           GE_PAQ_CUENTAS,
           ba_per_dat_adicionales bpd, --/*,
           GE_ENTES Z,
           (SELECT h.nro_cuenta, SUM(nvl(h.monto, 0)) mto_bloqueo
            FROM ge_bloqueos h
            WHERE EXISTS (SELECT 1
                   FROM ge_par_causales y
                   WHERE y.cod_causa = h.cod_causa
                   AND y.parametro = 'COD_CAU_BLO_EXT'
                   AND y.val_parametro = 'S')
            GROUP BY h.nro_cuenta) h,
           -----
           (SELECT f.NRO_CUENTA,
                   FEC_EXTRACTO,
                   SUM(Nvl(f.sal_bloqueado, 0)) sal_blo_anterior
            FROM GE_ext_cli_cuentas f, ah_cta_vistas g
            WHERE g.nro_cuenta = f.nro_cuenta
            AND f.fec_extracto = g.fec_ult_extracto
            GROUP BY f.NRO_CUENTA, FEC_EXTRACTO) f
      WHERE GE_DIR_ENVIOS.COD_PERSONA(+) = GE_CTA_CLIENTES.COD_PERSONA --CROGENEXT-13 Sergio Servin 06/08/2014
      AND GE_DIR_ENVIOS.NRO_CUENTA(+) = GE_CTA_CLIENTES.NRO_CUENTA --CROGENEXT-13 Sergio Servin 06/08/2014
      AND GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
      AND GE_CTA_CLIENTES.RELACION = 'P'
      AND AH_CTA_VISTAS.COD_MODULO = GE_CTA_CLIENTES.COD_MODULO
      AND AH_CTA_VISTAS.COD_MODALIDAD = GE_CTA_CLIENTES.COD_MODALIDAD
      AND AH_CTA_VISTAS.COD_OFICINA = GE_CTA_CLIENTES.COD_OFICINA
      AND AH_CTA_VISTAS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
      AND AH_CTA_VISTAS.FRE_EXTRACTO = v_frecuencia --CROGENEXT-13 Sergio Servin 06/08/2014
      AND bpd.cod_persona(+) = GE_CTA_CLIENTES.COD_PERSONA
      AND bpd.parametro(+) = 'TIP_GEN_EXTRACTOS'
      AND ((AH_CTA_VISTAS.ESTADO NOT IN ('C', 'P')) OR
             (AH_CTA_VISTAS.ESTADO IN ('C', 'P') AND
             AH_CTA_VISTAS.FEC_ULT_MOVIMIENTO >= v_pri_dia_mes_habil AND
             AH_CTA_VISTAS.FEC_ULT_MOVIMIENTO >
             NVL(AH_CTA_VISTAS.FEC_ULT_EXTRACTO, AH_CTA_VISTAS.FEC_APERTURA - 1)))
      AND GE_PAQ_CUENTAS.NRO_CUENTA(+) = GE_CTA_CLIENTES.NRO_CUENTA
      AND GE_PAQ_CUENTAS.COD_PERSONA(+) = GE_CTA_CLIENTES.COD_PERSONA
           --Obtiene persona de ente relacionado--
      AND Z.COD_ENTE(+) = ah_cta_vistas.cod_ente
           --Obtiene Monto de Bloqueo--
      AND H.NRO_CUENTA(+) = ah_cta_vistas.nro_cuenta
           --Ultimo Saldo Bloqueado--
      AND f.NRO_CUENTA(+) = ah_cta_vistas.nro_cuenta
      AND f.FEC_EXTRACTO(+) = ah_cta_vistas.fec_ult_extracto
      ORDER BY GE_PAQ_CUENTAS.COD_MODULO,
               GE_PAQ_CUENTAS.COD_MODALIDAD,
               GE_PAQ_CUENTAS.COD_SUB_MODALIDAD,
               GE_PAQ_CUENTAS.NRO_CUENTA;
  
  BEGIN
    v_lugar := 'lp_generar_vistas';
    FOR AV IN MAE_CUE
    LOOP
      --limpio variables
      v_SAL_PROMEDIO      := NULL;
      v_nro_cta_combinada := NULL;
      v_val_tasa          := NULL;
      v_val_tae           := NULL;
      --- asigno el codigo de extracto unico -----------------
      v_nro_cuenta       := av.nro_cuenta;
      v_sal_ult_extracto := nvl(AV.SAL_ULT_EXTRACTO, 0);
      v_mto_bloqueo      := av.mto_bloqueo;
      v_cod_per_ente     := av.cod_per_ente;
      v_fec_movimiento   := AV.FEC_ULT_EXTRACTO;
      v_tip_gen_extracto := AV.SEPARADO; --se obtiene si es individual o consolidado
      --se obtiene si es nómina o no--
      v_es_nomina := AV.ES_NOMINA;
    
      --DYDMR-9148 - Incidencia SAU - ITGF - Generación de Base de Datos para Envio
      --Obtener valor parametrizado del ente, en caso de no recuperar valor por defecto si se debe utilizar su dirección
      IF v_es_nomina = 'S'
         AND av.cod_per_ente IS NOT NULL THEN
        v_uti_dir_ente := nvl(fug_obt_parentes(av.cod_ente, 'UTI_DIR_ENTE_EXTRACTO'), 'S');
      END IF;
      --Si el cliente es nómina pero el ente tiene parametrizado no utilizar su dirección se debe asignar es_Nomina = N
      IF v_es_nomina = 'S'
         AND v_uti_dir_ente = 'N' THEN
        v_es_nomina    := 'N';
        v_cod_per_ente := NULL;
      END IF;
    
      V_EXISTE := 'N';
      IF AV.SEPARADO = 'I'
         OR AV.COD_PAQUETE > 0 THEN
        -- es una direccion especifica, no enviar en ext.unico --
        v_cod_ext_separado := v_cod_ext_separado + 1;
        v_cod_extracto     := v_cod_ext_separado;
        ---------------------------------------------------------
      ELSE
        v_cod_extracto := 1;
        --- verifico si ya existe una cabecera del extracto unico
        BEGIN
          SELECT 'S'
          INTO V_EXISTE
          FROM GE_ARQ_CLIENTES
          WHERE GE_ARQ_CLIENTES.COD_PERSONA = v_cod_persona
          AND GE_ARQ_CLIENTES.COD_EXTRACTO = v_cod_extracto
          AND GE_ARQ_CLIENTES.FEC_EXTRACTO = v_fec_actual
          AND GE_ARQ_CLIENTES.FRE_EXTRACTO = v_frecuencia;
          V_EXISTE := 'S';
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            V_EXISTE := 'N';
          WHEN TOO_MANY_ROWS THEN
            V_EXISTE := 'S';
          WHEN OTHERS THEN
            dbms_output.put_line('ERROR al Buscar el Extr.del Cliente.CONTINUO.' ||
                                 SQLERRM);
            V_EXISTE := 'N';
        END;
      END IF;
      IF V_EXISTE = 'N' THEN
        -- busco los datos del cliente ---------------------------
        LP_OBTENER_DATOS_DEL_CLIENTE;
        lp_dir_envio;
        v_imprime_extracto := v_tip_extracto;
        v_lugar            := '1-insert GE_ARQ_CLIENTES ' || v_cod_persona || '-' ||
                              v_dir_cliente;
        INSERT INTO GE_ARQ_CLIENTES
          (COD_PERSONA,
           FEC_EXTRACTO,
           FRE_EXTRACTO,
           FUNCIONARIO,
           NOM_CLIENTE,
           DIRECCION,
           TELEFONO,
           COD_USU_OFICIAL,
           COD_PAIS,
           COD_CIUDAD,
           TEL_OFICIAL,
           NRO_INTERNO,
           COD_EXTRACTO,
           DET_DIRECCION,
           OBSERVACION,
           BARRIO,
           COD_MENSAJE,
           tip_impresion,
           CLI_CONFIDENCIAL,
           COD_OFICINA,
           cat_riesgo,
           Fec_Ult_Clasif,
           Cod_Per_Empresa,
           tip_direccion)
        VALUES
          (v_cod_persona,
           v_fec_actual,
           v_frecuencia,
           'N',
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
           decode(AV.SEPARADO, 'I', av.cod_oficina, v_cod_ofi_cliente),
           v_cat_riesgo,
           v_fec_ult_clasif,
           v_cod_per_ente,
           v_tip_envio);
        v_INSERTA := 'S';
      END IF;
      v_sal_blo_anterior := av.sal_blo_anterior;
      INSERT INTO GE_ARQ_CLI_CUENTAS
        (GE_ARQ_CLI_CUENTAS.COD_PERSONA,
         GE_ARQ_CLI_CUENTAS.FEC_EXTRACTO,
         GE_ARQ_CLI_CUENTAS.TIP_CUENTA,
         GE_ARQ_CLI_CUENTAS.COD_OFICINA,
         GE_ARQ_CLI_CUENTAS.COD_MODALIDAD,
         GE_ARQ_CLI_CUENTAS.NRO_CUENTA,
         GE_ARQ_CLI_CUENTAS.COD_MONEDA,
         GE_ARQ_CLI_CUENTAS.SAL_ANTERIOR,
         GE_ARQ_CLI_CUENTAS.SAL_ACTUAL,
         GE_ARQ_CLI_CUENTAS.NRO_FOLIO,
         GE_ARQ_CLI_CUENTAS.SAL_A_CONFIRMAR,
         GE_ARQ_CLI_CUENTAS.COD_EXTRACTO,
         GE_ARQ_CLI_CUENTAS.FRE_EXTRACTO,
         Sal_Promedio,
         Nro_Cta_Combinada,
         Tas_Nominal,
         tas_efectiva,
         GE_ARQ_CLI_CUENTAS.SAL_BLOQUEADO,
         GE_ARQ_CLI_CUENTAS.Cod_Per_Empresa,
         sal_blo_anterior)
      VALUES
        (v_cod_persona,
         v_fec_actual,
         'A',
         AV.COD_OFICINA,
         AV.COD_MODALIDAD,
         AV.NRO_CUENTA,
         AV.COD_MONEDA,
         v_sal_ult_extracto,
         NVL(v_sal_ult_extracto, 0) + NVL(v_mto_credito, 0) -
         NVL(v_mto_debito, 0),
         AV.NRO_FOLIO,
         AV.SAL_RET_BATCH,
         v_cod_extracto,
         v_frecuencia,
         v_SAL_PROMEDIO,
         v_nro_cta_combinada,
         v_val_tasa,
         v_val_tae,
         v_mto_bloqueo,
         v_cod_per_ente,
         v_sal_blo_anterior);
    END LOOP;
  END lp_generar_vistas;

  PROCEDURE lp_generar_certificados IS
  
    --Variables--
    v_val_tasa        ge_tas_fechas.val_tasa%TYPE;
    v_val_tae         ge_tas_fechas.val_tasa%TYPE;
    v_fec_vencimiento ah_cupones.fec_vencimiento%TYPE;
    v_mto_interes     ah_cupones.mto_interes%TYPE;
  
    ----------------------------------
    -- CURSOR DEL ARCHIVO PRINCIPAL --
    ----------------------------------
    CURSOR MAE_CUE IS
      SELECT GE_CTA_CLIENTES.COD_MODULO,
             GE_CTA_CLIENTES.COD_MODALIDAD,
             GE_CTA_CLIENTES.COD_OFICINA,
             GE_CTA_CLIENTES.NRO_CUENTA,
             AH_CTA_CERTIFICADOS.COD_MONEDA,
             AH_CTA_CERTIFICADOS.TAS_PERSONALIZADA,
             AH_CTA_CERTIFICADOS.COD_TASA,
             AH_CTA_CERTIFICADOS.CAPITAL,
             AH_CTA_CERTIFICADOS.FEC_VENCIMIENTO,
             AH_CTA_CERTIFICADOS.SAL_RET_BATCH,
             AH_CTA_CERTIFICADOS.SAL_TOT_BATCH,
             AH_CTA_CERTIFICADOS.FEC_APERTURA,
             fue_obt_titulo(AH_CTA_CERTIFICADOS.BENEFICIARIO) DENOMINACION,
             ah_cta_certificados.tip_capitalizacion,
             ah_cta_certificados.est_cer_batch,
             AH_CTA_CERTIFICADOS.SAL_BLOQUEADO,
             GE_CTA_CLIENTES.cod_persona,
             h.mto_bloqueo
      FROM AH_CTA_CERTIFICADOS,
           GE_CTA_CLIENTES,
           (SELECT h.nro_cuenta, SUM(nvl(h.monto, 0)) mto_bloqueo
            FROM ge_bloqueos h
            WHERE EXISTS (SELECT 1
                   FROM ge_par_causales y
                   WHERE y.cod_causa = h.cod_causa
                   AND y.parametro = 'COD_CAU_BLO_EXT'
                   AND y.val_parametro = 'S')
            GROUP BY h.nro_cuenta) h
      WHERE GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
      AND GE_CTA_CLIENTES.COD_MODALIDAD = v_cod_modalidad
      AND GE_CTA_CLIENTES.RELACION = 'P'
      AND AH_CTA_CERTIFICADOS.COD_MODULO = GE_CTA_CLIENTES.COD_MODULO
      AND AH_CTA_CERTIFICADOS.COD_MODALIDAD = GE_CTA_CLIENTES.COD_MODALIDAD
      AND AH_CTA_CERTIFICADOS.COD_OFICINA = GE_CTA_CLIENTES.COD_OFICINA
      AND AH_CTA_CERTIFICADOS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
      AND AH_CTA_CERTIFICADOS.EST_BATCH NOT IN ('C', 'T')
      AND NVL(AH_CTA_CERTIFICADOS.SAL_TOT_BATCH, 0) > 0
      AND H.NRO_CUENTA(+) = AH_CTA_CERTIFICADOS.NRO_CUENTA;
  
  BEGIN
    FOR CD IN MAE_CUE
    LOOP
      --limpio variables
      v_mto_interes     := NULL;
      v_fec_vencimiento := NULL;
      v_mto_bloqueo     := cd.mto_bloqueo;
      ----------------------------------------------------
      -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
      ----------------------------------------------------
      INSERT INTO GE_ARQ_CLI_CUENTAS
        (GE_ARQ_CLI_CUENTAS.COD_PERSONA,
         GE_ARQ_CLI_CUENTAS.FEC_EXTRACTO,
         GE_ARQ_CLI_CUENTAS.TIP_CUENTA,
         GE_ARQ_CLI_CUENTAS.COD_OFICINA,
         GE_ARQ_CLI_CUENTAS.COD_MODALIDAD,
         GE_ARQ_CLI_CUENTAS.NRO_CUENTA,
         GE_ARQ_CLI_CUENTAS.COD_MONEDA,
         GE_ARQ_CLI_CUENTAS.SAL_ACTUAL,
         GE_ARQ_CLI_CUENTAS.SAL_A_CONFIRMAR,
         GE_ARQ_CLI_CUENTAS.COD_EXTRACTO,
         GE_ARQ_CLI_CUENTAS.FRE_EXTRACTO,
         Tas_Nominal,
         tas_efectiva,
         GE_ARQ_CLI_CUENTAS.SAL_BLOQUEADO)
      VALUES
        (v_cod_persona,
         v_fec_actual,
         'A',
         CD.COD_OFICINA,
         CD.COD_MODALIDAD,
         CD.NRO_CUENTA,
         CD.COD_MONEDA,
         CD.SAL_TOT_BATCH,
         CD.SAL_RET_BATCH,
         1,
         v_frecuencia,
         v_val_tasa,
         v_val_tae,
         v_mto_bloqueo);
    
      -------------------------------------------------------
      -- CALCULA interes del sgte cupon --
      -------------------------------------------------------
      BEGIN
        SELECT A.FEC_VENCIMIENTO, NVL(A.MTO_INTERES, 0)
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
          NULL;
      END;
      ------------------------------------------------------------------
      -- INSERTA REGISTRO EN EL ARCHIVO RESUMEN DE AHORRO CERTIFICADO --
      ------------------------------------------------------------------
      INSERT INTO GE_ARQ_RESUMENES
        (GE_ARQ_RESUMENES.COD_PERSONA,
         GE_ARQ_RESUMENES.FEC_EXTRACTO,
         GE_ARQ_RESUMENES.TIPO,
         GE_ARQ_RESUMENES.NRO_CUENTA,
         GE_ARQ_RESUMENES.MTO_CAPITAL,
         GE_ARQ_RESUMENES.MTO_INTERES,
         GE_ARQ_RESUMENES.FEC_VENCIMIENTO,
         GE_ARQ_RESUMENES.COD_EXTRACTO,
         GE_ARQ_RESUMENES.FRE_EXTRACTO,
         GE_ARQ_RESUMENES.FEC_INICIO,
         GE_ARQ_RESUMENES.BENEFICIARIO,
         Cod_Modalidad,
         cod_moneda)
      VALUES
        (v_cod_persona,
         v_fec_actual,
         DECODE(CD.COD_MODALIDAD, 33, '2', '6'),
         CD.NRO_CUENTA,
         decode(cd.est_cer_batch, 'P', 0, CD.CAPITAL),
         v_mto_interes,
         v_fec_vencimiento,
         1,
         v_frecuencia,
         CD.FEC_APERTURA,
         CD.DENOMINACION,
         cd.cod_modalidad,
         cd.cod_moneda);
      --END IF;
    END LOOP;
  END lp_generar_certificados;
  --
  PROCEDURE lp_generar_prestamos IS
  
    --Variables--
    v_fec_vencimiento DATE;
    v_sal_capital     NUMBER(16, 2);
    V_INSERTAR        VARCHAR2(01);
    v_val_tasa        ge_tas_fechas.val_tasa%TYPE;
    v_val_tae         ge_tas_fechas.val_tasa%TYPE;
    ----------------------------------
    -- CURSOR DEL ARCHIVO PRINCIPAL --
    ----------------------------------
    CURSOR MAE_CUE IS
      SELECT GE_CTA_CLIENTES.COD_MODULO,
             GE_CTA_CLIENTES.COD_MODALIDAD,
             GE_CTA_CLIENTES.COD_OFICINA,
             GE_CTA_CLIENTES.NRO_CUENTA,
             PR_CTA_PRESTAMOS.MTO_CAPITAL TOT_PRESTAMO,
             PR_CTA_PRESTAMOS.COD_MONEDA,
             NVL(PR_CTA_PRESTAMOS.SAL_CAPITAL, 0) +
             NVL(PR_CTA_PRESTAMOS.SAL_INT_ADELANTADO, 0) +
             NVL(SAL_INTERES, 0) saldo_capital,
             GE_CTA_CLIENTES.COD_PERSONA
      FROM PR_CTA_PRESTAMOS, GE_CTA_CLIENTES
      WHERE GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
      AND GE_CTA_CLIENTES.RELACION = 'P'
      AND PR_CTA_PRESTAMOS.COD_MODULO = GE_CTA_CLIENTES.COD_MODULO
      AND PR_CTA_PRESTAMOS.COD_MODALIDAD = GE_CTA_CLIENTES.COD_MODALIDAD
      AND PR_CTA_PRESTAMOS.COD_OFICINA = GE_CTA_CLIENTES.COD_OFICINA
      AND PR_CTA_PRESTAMOS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
      AND PR_CTA_PRESTAMOS.ESTADO <> 'N'
      AND PR_CTA_PRESTAMOS.COD_MODALIDAD <> 699
      AND EXISTS (SELECT 1
             FROM pr_cuotas x
             WHERE x.nro_cuenta = PR_CTA_PRESTAMOS.NRO_CUENTA
             AND x.NRO_CUOTA > 0
             AND x.ESTADO NOT IN ('N'));
  
  BEGIN
    FOR PR IN MAE_CUE
    LOOP
      --limpio variables
      v_val_tasa := NULL;
      v_val_tae  := NULL;
      v_insertar := 'S';
      IF v_insertar = 'S' THEN
        --obtener tasas
        BEGIN
          pas_bcp.PR_OBT_TAS_PRESTAMO(NULL, pr.nro_cuenta, v_val_tae, v_val_tasa);
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
      
        BEGIN
          SELECT A.FEC_VENCIMIENTO,
                 NVL(A.SAL_CAPITAL, 0) + NVL(A.SAL_INT_DOCUMENTADO, 0) +
                 NVL(A.SAL_INTERES, 0)
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
        ----------------------------------------------------
        -- INSERTA REGISTRO EN EL ARCHIVO CABECERA PASIVO --
        ----------------------------------------------------
        INSERT INTO GE_ARQ_CLI_CUENTAS
          (GE_ARQ_CLI_CUENTAS.COD_PERSONA,
           GE_ARQ_CLI_CUENTAS.FEC_EXTRACTO,
           GE_ARQ_CLI_CUENTAS.TIP_CUENTA,
           GE_ARQ_CLI_CUENTAS.COD_OFICINA,
           GE_ARQ_CLI_CUENTAS.COD_MODALIDAD,
           GE_ARQ_CLI_CUENTAS.NRO_CUENTA,
           GE_ARQ_CLI_CUENTAS.COD_MONEDA,
           GE_ARQ_CLI_CUENTAS.SAL_ACTUAL,
           GE_ARQ_CLI_CUENTAS.COD_EXTRACTO,
           GE_ARQ_CLI_CUENTAS.FRE_EXTRACTO,
           Tas_Nominal,
           Tas_Efectiva,
           GE_ARQ_CLI_CUENTAS.SAL_BLOQUEADO)
        VALUES
          (v_cod_persona,
           v_fec_actual,
           'P',
           PR.COD_OFICINA,
           PR.COD_MODALIDAD,
           PR.NRO_CUENTA,
           PR.COD_MONEDA,
           PR.saldo_capital,
           1,
           v_frecuencia,
           v_val_tasa,
           v_val_tae,
           0);
        ---------------------------------------------------------
        -- INSERTA REGISTRO EN EL ARCHIVO RESUMEN DE PRESTAMOS --
        ---------------------------------------------------------
        INSERT INTO GE_ARQ_RESUMENES
          (GE_ARQ_RESUMENES.COD_PERSONA,
           GE_ARQ_RESUMENES.FEC_EXTRACTO,
           GE_ARQ_RESUMENES.TIPO,
           GE_ARQ_RESUMENES.NRO_CUENTA,
           GE_ARQ_RESUMENES.MTO_CAPITAL,
           GE_ARQ_RESUMENES.MTO_INTERES,
           GE_ARQ_RESUMENES.FEC_VENCIMIENTO,
           GE_ARQ_RESUMENES.COD_EXTRACTO,
           GE_ARQ_RESUMENES.FRE_EXTRACTO,
           GE_ARQ_RESUMENES.SAL_DISPONIBLE,
           Cod_Modalidad,
           cod_moneda)
        VALUES
          (v_cod_persona,
           v_fec_actual,
           '3',
           PR.NRO_CUENTA,
           PR.TOT_PRESTAMO,
           v_sal_capital,
           v_fec_vencimiento,
           1,
           v_frecuencia,
           pr.saldo_capital,
           pr.cod_modalidad,
           pr.cod_moneda);
      END IF;
    END LOOP;
  END lp_generar_prestamos;

  PROCEDURE lp_act_nro_control IS
    CURSOR c1 IS
      SELECT GE_ARQ_CLIENTES.FRE_EXTRACTO    FRECUENCIA,
             GE_ARQ_CLIENTES.COD_USU_OFICIAL OFICIAL,
             ROWID                           registro
      FROM GE_ARQ_CLIENTES
      WHERE GE_ARQ_CLIENTES.FEC_EXTRACTO = v_fec_actual
      AND INSTR(V_FRE_GENERAR, ',' || UPPER(GE_ARQ_CLIENTES.FRE_EXTRACTO) || ',') > 0
      AND GE_ARQ_CLIENTES.TIP_IMPRESION IN ('C', 'S', 'X')
      ORDER BY GE_ARQ_CLIENTES.FRE_EXTRACTO,
               GE_ARQ_CLIENTES.COD_USU_OFICIAL,
               GE_ARQ_CLIENTES.COD_PAIS,
               GE_ARQ_CLIENTES.COD_CIUDAD,
               upper(GE_ARQ_CLIENTES.BARRIO),
               ltrim(upper(GE_ARQ_CLIENTES.DIRECCION));
    v_Oficial      ba_usuarios.cod_usuario%TYPE;
    v_Cantidad     NUMBER(10) := 0;
    v_fre_extracto ge_arq_clientes.fre_extracto%TYPE;
    r1             c1%ROWTYPE;
  BEGIN
    v_lugar := 'lp_act_nro_control';
    IF c1%ISOPEN THEN
      CLOSE c1;
    END IF;
    OPEN c1;
    LOOP
      FETCH c1
        INTO r1;
      EXIT WHEN c1%NOTFOUND;
      IF R1.FRECUENCIA != v_fre_extracto
         OR v_fre_extracto IS NULL THEN
        v_fre_extracto := R1.FRECUENCIA;
        v_Cantidad     := 0;
        v_Oficial      := r1.Oficial;
      ELSE
        IF r1.Oficial != v_Oficial
           OR v_Oficial IS NULL THEN
          v_Cantidad := 0;
          v_Oficial  := r1.Oficial;
        END IF;
      END IF;
      v_Cantidad := v_Cantidad + 1;
      UPDATE GE_ARQ_CLIENTES
      SET NRO_CONTROL = v_Cantidad
      WHERE ROWID = r1.registro;
    END LOOP;
  END;

  PROCEDURE lp_act_deb_cre_negativos IS
  BEGIN
    v_lugar := 'lp_act_deb_cre_negativos';
    --Actualiza Debitos Negativos a Creditos--
    UPDATE GE_ARQ_CLI_MOVIMIENTOS
    SET GE_ARQ_CLI_MOVIMIENTOS.MTO_CREDITO = ABS(GE_ARQ_CLI_MOVIMIENTOS.MTO_DEBITO),
        GE_ARQ_CLI_MOVIMIENTOS.MTO_DEBITO  = 0
    WHERE GE_ARQ_CLI_MOVIMIENTOS.FEC_EXTRACTO = v_fec_actual
    AND INSTR(V_FRE_GENERAR, ',' || GE_ARQ_CLI_MOVIMIENTOS.FRE_EXTRACTO || ',') > 0
    AND GE_ARQ_CLI_MOVIMIENTOS.MTO_DEBITO < 0;
  
    --Actualiza Creditos Negativos a Debitos--
    UPDATE GE_ARQ_CLI_MOVIMIENTOS
    SET GE_ARQ_CLI_MOVIMIENTOS.MTO_DEBITO  = ABS(GE_ARQ_CLI_MOVIMIENTOS.MTO_CREDITO),
        GE_ARQ_CLI_MOVIMIENTOS.MTO_CREDITO = 0
    WHERE GE_ARQ_CLI_MOVIMIENTOS.FEC_EXTRACTO = v_fec_actual
    AND INSTR(V_FRE_GENERAR, ',' || GE_ARQ_CLI_MOVIMIENTOS.FRE_EXTRACTO || ',') > 0
    AND GE_ARQ_CLI_MOVIMIENTOS.MTO_CREDITO < 0;
  
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20003, 'Error al actualizar creditos negativos ' ||
                               SQLERRM);
  END;

  PROCEDURE lp_mar_ext_con_diferencia IS
  BEGIN
    BEGIN
      v_lugar := 'lp_mar_ext_con_dif_ah';
      --- actualiza con lower (minuscula las cuentas que tuvieron dif. ---
      --- para que no imprima con los demas extractos --------------------
      UPDATE GE_ARQ_CLIENTES
      SET GE_ARQ_CLIENTES.FRE_EXTRACTO = LOWER(GE_ARQ_CLIENTES.FRE_EXTRACTO)
      WHERE GE_ARQ_CLIENTES.FEC_EXTRACTO = v_fec_actual
      AND INSTR(V_FRE_GENERAR, ',' || GE_ARQ_CLIENTES.FRE_EXTRACTO || ',') > 0
      AND EXISTS
       (SELECT 0
             FROM GE_ARQ_CLI_CUENTAS, AH_CTA_VISTAS
             WHERE GE_ARQ_CLI_CUENTAS.COD_PERSONA =
                   GE_ARQ_CLIENTES.COD_PERSONA
             AND GE_ARQ_CLI_CUENTAS.COD_EXTRACTO =
                   GE_ARQ_CLIENTES.COD_EXTRACTO
             AND GE_ARQ_CLI_CUENTAS.FEC_EXTRACTO =
                   GE_ARQ_CLIENTES.FEC_EXTRACTO
             AND GE_ARQ_CLI_CUENTAS.FRE_EXTRACTO =
                   GE_ARQ_CLIENTES.FRE_EXTRACTO
             AND AH_CTA_VISTAS.COD_MODULO = 3
             AND AH_CTA_VISTAS.COD_MODALIDAD =
                   GE_ARQ_CLI_CUENTAS.COD_MODALIDAD
             AND AH_CTA_VISTAS.COD_OFICINA = GE_ARQ_CLI_CUENTAS.COD_OFICINA
             AND AH_CTA_VISTAS.NRO_CUENTA = GE_ARQ_CLI_CUENTAS.NRO_CUENTA
             AND AH_CTA_VISTAS.FEC_ULT_EXTRACTO = v_fec_actual
             AND (NVL(AH_CTA_VISTAS.SAL_ULT_EXTRACTO, 0) <>
                   NVL(AH_CTA_VISTAS.SAL_TOTAL, 0) -
                   NVL(AH_CTA_VISTAS.SAL_RETENIDO, 0) OR
                   NVL(AH_CTA_VISTAS.SAL_ULT_EXTRACTO, 0) <>
                   NVL(AH_CTA_VISTAS.SAL_TOT_BATCH, 0) -
                   NVL(AH_CTA_VISTAS.SAL_RET_BATCH, 0)));
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003, 'Error al marcar diferencias ah.' ||
                                 SQLERRM);
    END;
    --
    BEGIN
      v_lugar := 'lp_mar_ext_con_dif_cc';
      --- actualiza con lower (minuscula las cuentas que tuvieron dif. ---
      --- para que no imprima con los demás extractos --------------------
      UPDATE GE_ARQ_CLIENTES
      SET GE_ARQ_CLIENTES.FRE_EXTRACTO = LOWER(GE_ARQ_CLIENTES.FRE_EXTRACTO)
      WHERE GE_ARQ_CLIENTES.FEC_EXTRACTO = v_fec_actual
      AND INSTR(V_FRE_GENERAR, ',' || GE_ARQ_CLIENTES.FRE_EXTRACTO || ',') > 0
      AND EXISTS
       (SELECT 0
             FROM GE_ARQ_CLI_CUENTAS, CC_CTA_CORRIENTES
             WHERE GE_ARQ_CLI_CUENTAS.COD_PERSONA =
                   GE_ARQ_CLIENTES.COD_PERSONA
             AND GE_ARQ_CLI_CUENTAS.COD_EXTRACTO =
                   GE_ARQ_CLIENTES.COD_EXTRACTO
             AND GE_ARQ_CLI_CUENTAS.FEC_EXTRACTO =
                   GE_ARQ_CLIENTES.FEC_EXTRACTO
             AND GE_ARQ_CLI_CUENTAS.FRE_EXTRACTO =
                   GE_ARQ_CLIENTES.FRE_EXTRACTO
             AND CC_CTA_CORRIENTES.COD_MODULO = 4
             AND CC_CTA_CORRIENTES.COD_MODALIDAD =
                   GE_ARQ_CLI_CUENTAS.COD_MODALIDAD
             AND CC_CTA_CORRIENTES.COD_OFICINA =
                   GE_ARQ_CLI_CUENTAS.COD_OFICINA
             AND CC_CTA_CORRIENTES.NRO_CUENTA = GE_ARQ_CLI_CUENTAS.NRO_CUENTA
             AND CC_CTA_CORRIENTES.FEC_ULT_EXTRACTO = v_fec_actual
             AND (NVL(CC_CTA_CORRIENTES.SAL_ULT_EXTRACTO, 0) <>
                   NVL(CC_CTA_CORRIENTES.SAL_TOTAL, 0) -
                   NVL(CC_CTA_CORRIENTES.SAL_RETENIDO, 0) OR
                   NVL(CC_CTA_CORRIENTES.SAL_ULT_EXTRACTO, 0) <>
                   NVL(CC_CTA_CORRIENTES.SAL_TOT_BATCH, 0) -
                   NVL(CC_CTA_CORRIENTES.SAL_RET_BATCH, 0)));
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003, 'Error al marcar diferencias cc.' ||
                                 SQLERRM);
    END;
  END;
  PROCEDURE lp_mar_ext_con_dif_detalle IS
    CURSOR DIFEREN IS
      SELECT GE_ARQ_CLI_CUENTAS.COD_PERSONA,
             GE_ARQ_CLI_CUENTAS.COD_EXTRACTO,
             GE_ARQ_CLI_CUENTAS.FRE_EXTRACTO
      FROM GE_TRANSACCIONES, GE_ARQ_CLI_MOVIMIENTOS, GE_ARQ_CLI_CUENTAS
      WHERE GE_TRANSACCIONES.COD_MODULO = GE_ARQ_CLI_MOVIMIENTOS.COD_MODULO
      AND GE_TRANSACCIONES.COD_MODALIDAD =
            GE_ARQ_CLI_MOVIMIENTOS.COD_MODALIDAD
      AND GE_TRANSACCIONES.COD_TRANSACCION =
            GE_ARQ_CLI_MOVIMIENTOS.COD_TRA_PADRE
      AND GE_ARQ_CLI_MOVIMIENTOS.COD_PERSONA =
            GE_ARQ_CLI_CUENTAS.COD_PERSONA
      AND GE_ARQ_CLI_MOVIMIENTOS.COD_EXTRACTO =
            GE_ARQ_CLI_CUENTAS.COD_EXTRACTO
      AND GE_ARQ_CLI_MOVIMIENTOS.FEC_EXTRACTO =
            GE_ARQ_CLI_CUENTAS.FEC_EXTRACTO
      AND GE_ARQ_CLI_MOVIMIENTOS.NRO_CUENTA = GE_ARQ_CLI_CUENTAS.NRO_CUENTA
      AND GE_ARQ_CLI_MOVIMIENTOS.FRE_EXTRACTO =
            GE_ARQ_CLI_CUENTAS.FRE_EXTRACTO
      AND GE_ARQ_CLI_CUENTAS.FEC_EXTRACTO = v_fec_actual
      AND INSTR(V_FRE_GENERAR, ',' || GE_ARQ_CLI_CUENTAS.FRE_EXTRACTO || ',') > 0
      AND GE_ARQ_CLI_CUENTAS.TIP_CUENTA = 'A'
           --WA:08/08/2014 Se agrega 49 para financiera Pais
      AND GE_ARQ_CLI_CUENTAS.COD_MODALIDAD IN (31, 41, 42, 48, 49)
      AND NVL(GE_ARQ_CLI_MOVIMIENTOS.IND_BLOQUEO, 'N') = 'N'
      --WA:08/08/2014 Se agrega 49 para financiera Pais
      GROUP BY GE_ARQ_CLI_CUENTAS.COD_PERSONA,
               GE_ARQ_CLI_CUENTAS.COD_EXTRACTO,
               GE_ARQ_CLI_CUENTAS.FRE_EXTRACTO,
               GE_ARQ_CLI_CUENTAS.FEC_EXTRACTO,
               GE_ARQ_CLI_CUENTAS.NRO_CUENTA,
               GE_ARQ_CLI_CUENTAS.COD_MODALIDAD,
               GE_ARQ_CLI_CUENTAS.SAL_ANTERIOR,
               GE_ARQ_CLI_CUENTAS.SAL_ACTUAL
      HAVING DECODE(GE_ARQ_CLI_CUENTAS.COD_MODALIDAD, 42, GE_ARQ_CLI_CUENTAS.SAL_ANTERIOR * -1, 48, GE_ARQ_CLI_CUENTAS.SAL_ANTERIOR * -1, 49, GE_ARQ_CLI_CUENTAS.SAL_ANTERIOR * -1, GE_ARQ_CLI_CUENTAS.SAL_ANTERIOR) + (SUM(GE_ARQ_CLI_MOVIMIENTOS.MTO_CREDITO) - SUM(GE_ARQ_CLI_MOVIMIENTOS.MTO_DEBITO)) != DECODE(GE_ARQ_CLI_CUENTAS.COD_MODALIDAD, 42, GE_ARQ_CLI_CUENTAS.SAL_ACTUAL * -1, 48, GE_ARQ_CLI_CUENTAS.SAL_ACTUAL * -1, 49, GE_ARQ_CLI_CUENTAS.SAL_ACTUAL * -1, GE_ARQ_CLI_CUENTAS.SAL_ACTUAL);
  BEGIN
    v_lugar := 'lp_mar_ext_con_dif_detalle';
    FOR CA IN DIFEREN
    LOOP
      UPDATE GE_ARQ_CLIENTES
      SET GE_ARQ_CLIENTES.FRE_EXTRACTO = LOWER(GE_ARQ_CLIENTES.FRE_EXTRACTO)
      WHERE GE_ARQ_CLIENTES.COD_PERSONA = CA.COD_PERSONA
      AND GE_ARQ_CLIENTES.COD_EXTRACTO = CA.COD_EXTRACTO
      AND GE_ARQ_CLIENTES.FEC_EXTRACTO = v_fec_actual
      AND GE_ARQ_CLIENTES.FRE_EXTRACTO = CA.FRE_EXTRACTO;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20004, 'Error al marcar dif. detalle ' ||
                               SQLERRM);
  END lp_mar_ext_con_dif_detalle;

  PROCEDURE lp_act_cod_mensaje IS
    CURSOR mensajes IS
      SELECT a.cod_mensaje, det_sql
      FROM ge_msj_extractos b, ge_mensajes a
      WHERE b.cod_mensaje = a.cod_mensaje
      AND b.fec_extracto = v_fec_actual
      AND b.mensaje IS NOT NULL
      AND a.cod_mensaje <> '1'
      ORDER BY b.prioridad;
    v_sentencia LONG;
    v_error     VARCHAR2(4000);
    v_fre_aux   VARCHAR2(50);
    v_len_aux   NUMBER(2);
    v_ind_aux   NUMBER(2);
    v_fre_act   VARCHAR2(1);
  BEGIN
    SELECT REPLACE(v_fre_generar, ',', NULL)
    INTO v_fre_aux
    FROM dual;
  
    v_len_aux := length(v_fre_aux);
  
    FOR v_ind_aux IN 1 .. v_len_aux
    LOOP
      v_fre_act := substr(v_fre_aux, v_ind_aux, 1);
      FOR msj IN mensajes
      LOOP
        v_sentencia := 'update ge_arq_clientes set cod_mensaje = ' ||
                       msj.cod_mensaje || ' where cod_mensaje = 1 ' ||
                       '   and fec_extracto = to_date(''' ||
                       to_char(v_fec_actual, 'ddmmyyyy') ||
                       ''',''ddmmyyyy'')' || '   and fre_extracto = ''' ||
                       v_fre_act || '''' || '   and cod_persona in (' ||
                       msj.det_sql || ')';
        sql_util.ejecute_dml(v_sentencia, v_error);
        IF v_error IS NOT NULL THEN
          raise_application_error(-20000, 'Error en ' || v_sentencia || '-' ||
                                   v_error);
        ELSE
          --commit;
          NULL;
        END IF;
      END LOOP;
    END LOOP;
  END;

  PROCEDURE lp_act_tip_impresion IS
  BEGIN
    v_lugar := 'LP_ACT_TIP_IMPRESION';
    ----------------------------------------------
    -- BORRA CABECERA ACTIVO PASIVO DEL CLIENTE --
    ----------------------------------------------
    UPDATE GE_ARQ_CLIENTES A
    SET A.TIP_IMPRESION = 'N'
    WHERE NOT EXISTS (SELECT 1
           FROM GE_ARQ_CLI_MOVIMIENTOS B, GE_ARQ_CLI_CUENTAS C
           WHERE B.COD_PERSONA = A.COD_PERSONA
           AND B.COD_EXTRACTO = A.COD_EXTRACTO
           AND B.FEC_EXTRACTO = A.FEC_EXTRACTO
           AND B.FRE_EXTRACTO = A.FRE_EXTRACTO
           AND C.COD_PERSONA = B.COD_PERSONA
           AND C.COD_EXTRACTO = B.COD_EXTRACTO
           AND C.FEC_EXTRACTO = B.FEC_EXTRACTO
           AND C.FRE_EXTRACTO = A.FRE_EXTRACTO
           AND C.NRO_CUENTA = B.NRO_CUENTA)
    AND NOT EXISTS (SELECT 0
           FROM GE_ARQ_CLI_MOV_PENDIENTES X
           WHERE X.COD_PERSONA = A.COD_PERSONA
           AND X.FEC_EXTRACTO = A.FEC_EXTRACTO
           AND X.FRE_EXTRACTO = A.FRE_EXTRACTO
           AND X.COD_EXTRACTO = A.COD_EXTRACTO)
    AND A.FEC_EXTRACTO = v_fec_actual
    AND INSTR(V_FRE_GENERAR, ',' || UPPER(A.FRE_EXTRACTO) || ',') > 0
    AND a.tip_impresion <> 'N';
  
  END;

  PROCEDURE lp_ins_dat_ext_generados IS
  BEGIN
  
    v_lugar := 'inserta ge_ext_clientes';
    INSERT INTO ge_ext_clientes
      SELECT a.*
      FROM ge_arq_clientes a;
  
    v_lugar := 'inserta ge_ext_cli_cuentas';
    INSERT INTO ge_ext_cli_cuentas
      SELECT a.*
      FROM ge_arq_cli_cuentas a;
  
    v_lugar := 'inserta ge_ext_cli_movimientos';
    INSERT INTO ge_ext_cli_movimientos
      SELECT a.*
      FROM ge_arq_cli_movimientos a;
  
    v_lugar := 'inserta ge_cta_extractos_tmp';
    INSERT INTO GE_CTA_EXTRACTOS_TMP
      SELECT a.*
      FROM ge_arq_extractos a;
  
    v_lugar := 'inserta ge_ext_cli_mov_pendientes';
    INSERT INTO GE_EXT_CLI_MOV_PENDIENTES
      SELECT a.*
      FROM ge_arq_cli_mov_pendientes a;
  
    v_lugar := 'inserta ge_ext_cli_mov_retenidos';
    INSERT INTO GE_EXT_CLI_MOV_RETENIDOS
      SELECT a.*
      FROM ge_arq_cli_mov_retenidos a;
  
    v_lugar := 'inserta ge_ext_resumenes';
    INSERT INTO GE_EXT_RESUMENES
      SELECT a.*
      FROM ge_arq_resumenes a;
  
  END;

  PROCEDURE lp_act_folio_ahorros IS
    CURSOR CABECERA IS
      SELECT GE_ARQ_CLI_CUENTAS.COD_MODALIDAD,
             GE_ARQ_CLI_CUENTAS.COD_OFICINA,
             GE_ARQ_CLI_CUENTAS.NRO_CUENTA,
             GE_ARQ_CLI_CUENTAS.COD_PERSONA,
             GE_ARQ_CLI_CUENTAS.COD_EXTRACTO,
             GE_ARQ_CLI_CUENTAS.NRO_FOLIO,
             GE_ARQ_CLI_CUENTAS.SAL_ACTUAL
      FROM GE_ARQ_CLI_CUENTAS
      WHERE GE_ARQ_CLI_CUENTAS.FEC_EXTRACTO = v_fec_actual
      AND INSTR(V_FRE_GENERAR, ',' || GE_ARQ_CLI_CUENTAS.FRE_EXTRACTO || ',') > 0
      AND GE_ARQ_CLI_CUENTAS.TIP_CUENTA = 'A'
      AND GE_ARQ_CLI_CUENTAS.COD_MODALIDAD = 31;
  BEGIN
    v_lugar := 'lp_act_folio_ahorros';
    FOR CA IN CABECERA
    LOOP
      -- actualizo los datos de la cuenta ---------------------------
      UPDATE AH_MOVIMIENTOS_HIS
      SET NRO_FOLIO = NVL(CA.NRO_FOLIO, 0)
      WHERE AH_MOVIMIENTOS_HIS.COD_MODULO = 3
      AND AH_MOVIMIENTOS_HIS.COD_MODALIDAD = CA.COD_MODALIDAD
      AND AH_MOVIMIENTOS_HIS.COD_OFICINA = CA.COD_OFICINA
      AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = CA.NRO_CUENTA
      AND AH_MOVIMIENTOS_HIS.FECHA >= v_pri_dia_mes_habil
      AND AH_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
      AND (AH_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
            (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
            FEC_VALOR < v_pri_dia_mes_habil AND EXISTS
             (SELECT 1
              FROM GE_ARQ_CLI_MOV_GENERAR REV -- CB. 25/09/2013.
              WHERE AH_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
              AND AH_MOVIMIENTOS_HIS.HOR_REVERSION = REV.HORA
              AND AH_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
              AND AH_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                   -- DYDMR-5672 NAF 01/2017
              AND AH_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
              AND abs(AH_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO))) OR
            (AH_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
            AH_MOVIMIENTOS_HIS.COD_TRA_PADRE IN (303, 302) AND
            AH_MOVIMIENTOS_HIS.Cod_Mad_Padre = 455))
      AND AH_MOVIMIENTOS_HIS.ESTADO = 'N'
      AND AH_MOVIMIENTOS_HIS.NRO_FOLIO IS NULL;
    END LOOP;
  END lp_act_folio_ahorros;
  ---
  PROCEDURE lp_act_folio_ctactes IS
    CURSOR CABECERA IS
      SELECT GE_ARQ_CLI_CUENTAS.COD_MODALIDAD,
             GE_ARQ_CLI_CUENTAS.COD_OFICINA,
             GE_ARQ_CLI_CUENTAS.NRO_CUENTA,
             GE_ARQ_CLI_CUENTAS.COD_PERSONA,
             GE_ARQ_CLI_CUENTAS.COD_EXTRACTO,
             GE_ARQ_CLI_CUENTAS.NRO_FOLIO,
             GE_ARQ_CLI_CUENTAS.SAL_ACTUAL
      FROM GE_ARQ_CLI_CUENTAS
      WHERE GE_ARQ_CLI_CUENTAS.FEC_EXTRACTO = v_fec_actual
      AND INSTR(V_FRE_GENERAR, ',' || GE_ARQ_CLI_CUENTAS.FRE_EXTRACTO || ',') > 0
      AND GE_ARQ_CLI_CUENTAS.TIP_CUENTA IN ('A', 'P') --para q tome sobregiradas
      AND GE_ARQ_CLI_CUENTAS.COD_MODALIDAD BETWEEN 41 AND 49;
  BEGIN
    v_lugar := 'lp_act_folio_ctactes';
    FOR CA IN CABECERA
    LOOP
      -- actualizo los datos de la cuenta ---------------------------
      UPDATE CC_MOVIMIENTOS_HIS
      SET NRO_FOLIO = NVL(CA.NRO_FOLIO, 0)
      WHERE CC_MOVIMIENTOS_HIS.COD_MODULO = 4
      AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = CA.COD_MODALIDAD
      AND CC_MOVIMIENTOS_HIS.COD_OFICINA = CA.COD_OFICINA
      AND CC_MOVIMIENTOS_HIS.NRO_CUENTA = CA.NRO_CUENTA
      AND CC_MOVIMIENTOS_HIS.FECHA >= v_pri_dia_mes_habil
      AND CC_MOVIMIENTOS_HIS.FECHA <= v_fec_actual
      AND (CC_MOVIMIENTOS_HIS.REVERSADO = 'N' OR
            (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
            CC_MOVIMIENTOS_HIS.FEC_VALOR < v_pri_dia_mes_habil AND EXISTS
             (SELECT 1
              FROM GE_ARQ_CLI_MOV_GENERAR REV -- CB. 25/09/2013.
              WHERE CC_MOVIMIENTOS_HIS.FEC_VALOR = REV.FECHA
              AND CC_MOVIMIENTOS_HIS.HOR_REVERSION = REV.HORA
              AND CC_MOVIMIENTOS_HIS.COD_USU_REVERSION = REV.COD_USUARIO
              AND CC_MOVIMIENTOS_HIS.NRO_SECUENCIA = REV.NRO_SECUENCIA
                   -- DYDMR-5672 NAF 01/2017
              AND CC_MOVIMIENTOS_HIS.NRO_CUENTA = REV.NRO_CUENTA
              AND abs(CC_MOVIMIENTOS_HIS.MONTO) = abs(REV.MONTO))) OR
            (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' AND
            CC_MOVIMIENTOS_HIS.COD_TRA_PADRE IN (303, 302) AND
            CC_MOVIMIENTOS_HIS.COD_MAD_PADRE = 455))
      AND CC_MOVIMIENTOS_HIS.ESTADO = 'N'
      AND CC_MOVIMIENTOS_HIS.NRO_FOLIO IS NULL;
    END LOOP;
  END lp_act_folio_ctactes;
  ---
  PROCEDURE lp_gen_extracto IS
  
    --- Defincion de Cursores--
    CURSOR MAE_CLI IS
      SELECT DISTINCT GE_CTA_CLIENTES.COD_PERSONA, GE_CUENTAS.fre_extracto
      FROM GE_CUENTAS, GE_CTA_CLIENTES
      WHERE GE_CUENTAS.COD_MODULO = GE_CTA_CLIENTES.COD_MODULO
      AND GE_CUENTAS.COD_MODALIDAD = GE_CTA_CLIENTES.COD_MODALIDAD
      AND GE_CUENTAS.COD_OFICINA = GE_CTA_CLIENTES.COD_OFICINA
      AND GE_CUENTAS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
      AND INSTR(v_fre_generar, ',' || GE_CUENTAS.fre_extracto || ',') > 0
      AND GE_CTA_CLIENTES.RELACION = 'P'
      AND GE_CUENTAS.COD_MODULO != 5
      AND ((GE_CUENTAS.ESTADO NOT IN ('X', 'A', 'C', 'P')) OR
            (GE_CUENTAS.ESTADO IN ('C', 'P') AND
            GE_CUENTAS.FEC_MODIFICACION >= v_pri_dia_mes_habil));
  
    CURSOR CTAS IS
      SELECT DISTINCT GE_CTA_CLIENTES.COD_MODULO,
                      DECODE(GE_CTA_CLIENTES.COD_MODULO, 3, GE_CTA_CLIENTES.COD_MODALIDAD, 4, decode(GE_CTA_CLIENTES.COD_MODALIDAD, 41, 41, 43), GE_CTA_CLIENTES.COD_MODULO) COD_MODALIDAD
      FROM GE_CTA_CLIENTES, GE_CUENTAS
      WHERE GE_CTA_CLIENTES.COD_PERSONA = v_cod_persona
      AND GE_CTA_CLIENTES.RELACION = 'P'
      AND GE_CUENTAS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
      AND GE_CUENTAS.fre_extracto = v_frecuencia
      AND GE_CTA_CLIENTES.COD_MODULO >= 3
      AND GE_CTA_CLIENTES.COD_MODULO <= 6
      ORDER BY decode(GE_CTA_CLIENTES.COD_MODULO, 4, 1, 3, DECODE(GE_CTA_CLIENTES.COD_MODULO, 3, GE_CTA_CLIENTES.COD_MODALIDAD, 4, decode(GE_CTA_CLIENTES.COD_MODALIDAD, 41, 41, 43), GE_CTA_CLIENTES.COD_MODULO));
  BEGIN
    v_lugar := 'lp_gen_extracto';
    FOR CL IN MAE_CLI
    LOOP
      -- Inicializo la variable que separa los extractos especificos-
      v_frecuencia       := cl.fre_extracto;
      v_cod_extracto     := 1;
      v_cod_ext_separado := 1;
      -- CUENTAS CORRIENTE Y AHORRO A LA VISTA del CLIENTE ----------
      v_inserta     := 'N';
      v_cod_persona := CL.COD_PERSONA;
      FOR RCTA IN CTAS
      LOOP
        IF rcta.COD_MODULO = 4 THEN
          IF rcta.cod_modalidad = 41 THEN
            lp_generar_ctacte;
          ELSE
            lp_generar_ctaban;
          END IF;
        ELSIF rcta.COD_MODULO = 3
              AND rcta.COD_MODALIDAD = 31 THEN
          lp_generar_vistas;
        ELSIF rcta.COD_MODULO = 3
              AND rcta.COD_MODALIDAD IN (33, 34, 35) THEN
          v_cod_modalidad := rcta.cod_modalidad;
          lp_generar_certificados;
        ELSIF rcta.COD_MODULO = 6 THEN
          lp_generar_prestamos;
        END IF;
      END LOOP;
    END LOOP;
    BEGIN
      dbms_stats.gather_table_stats('IT', 'GE_ARQ_CLIENTES');
    END;
    BEGIN
      dbms_stats.gather_table_stats('IT', 'GE_ARQ_CLI_CUENTAS');
    END;
  END lp_gen_extracto;

  PROCEDURE lp_act_maestro IS
  BEGIN
    --Actualizar Cta Cte--
    UPDATE cc_cta_corrientes e
    SET (e.nro_folio, e.fec_ult_extracto, e.sal_ult_extracto) =
        (SELECT t.nro_folio, t.fec_ult_extracto, t.sal_ult_extracto
         FROM GE_ARQ_EXTRACTOS t
         WHERE t.nro_cuenta = e.nro_cuenta
         AND t.nom_tabla = 'CC_CTA_CORRIENTES')
    WHERE EXISTS (SELECT 1
           FROM GE_ARQ_EXTRACTOS t
           WHERE t.nro_cuenta = e.nro_cuenta
           AND t.nom_tabla = 'CC_CTA_CORRIENTES');
  
    --Actualizar Cta Bancarias--
    UPDATE cc_cta_bancarias e
    SET (e.nro_folio, e.fec_ult_extracto, e.sal_ult_extracto) =
        (SELECT t.nro_folio, t.fec_ult_extracto, t.sal_ult_extracto
         FROM GE_ARQ_EXTRACTOS t
         WHERE t.nro_cuenta = e.nro_cuenta
         AND t.nom_tabla = 'CC_CTA_BANCARIAS')
    WHERE EXISTS (SELECT 1
           FROM GE_ARQ_EXTRACTOS t
           WHERE t.nro_cuenta = e.nro_cuenta
           AND t.nom_tabla = 'CC_CTA_BANCARIAS');
  
    --Actualizar Vistas--
    UPDATE ah_cta_vistas e
    SET (e.nro_folio, e.fec_ult_extracto, e.sal_ult_extracto) =
        (SELECT t.nro_folio, t.fec_ult_extracto, t.sal_ult_extracto
         FROM GE_ARQ_EXTRACTOS t
         WHERE t.nro_cuenta = e.nro_cuenta
         AND t.nom_tabla = 'AH_CTA_VISTAS')
    WHERE EXISTS (SELECT 1
           FROM GE_ARQ_EXTRACTOS t
           WHERE t.nro_cuenta = e.nro_cuenta
           AND t.nom_tabla = 'AH_CTA_VISTAS');
  END lp_act_maestro;

  PROCEDURE lp_act_dat_adicionales IS
    v_ind_trimestre VARCHAR2(1);
  BEGIN
    --Carga Indicador de Trimestre--
    IF v_fec_actual IN
       (pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/03/' ||
                                                  to_char(v_fec_actual, 'YYYY'), 'DD/MM/YYYY')), -1, 2), pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/06/' ||
                                                   to_char(v_fec_actual, 'YYYY'), 'DD/MM/YYYY')), -1, 2), pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/09/' ||
                                                   to_char(v_fec_actual, 'YYYY'), 'DD/MM/YYYY')), -1, 2), pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/12/' ||
                                                   to_char(v_fec_actual, 'YYYY'), 'DD/MM/YYYY')), -1, 2)) THEN
      v_ind_trimestre := 'S';
    ELSE
      v_ind_trimestre := 'N';
    END IF;
  
    --Actualiza si existe parametro de fecha y es M-Mensual--
    UPDATE BA_PER_DAT_ADICIONALES B
    SET B.VAL_PARAMETRO = to_char(v_fec_actual, 'dd/mm/yyyy')
    WHERE B.PARAMETRO = 'FEC_ULT_EXTRACTOS'
    AND EXISTS (SELECT 1
           FROM GE_ARQ_EXTRACTOS X
           WHERE X.COD_PERSONA = B.COD_PERSONA)
    AND EXISTS (SELECT 1
           FROM BA_PER_DAT_ADICIONALES T
           WHERE T.PARAMETRO = 'FRE_EXTRACTOS'
           AND T.COD_PERSONA = B.COD_PERSONA
           AND T.VAL_PARAMETRO = 'M')
    AND V_IND_TRIMESTRE = 'N';
  
    --Actualiza si existe parametro de fecha y es T-Trimestral--
    UPDATE BA_PER_DAT_ADICIONALES B
    SET B.VAL_PARAMETRO = to_char(v_fec_actual, 'dd/mm/yyyy')
    WHERE B.PARAMETRO = 'FEC_ULT_EXTRACTOS'
    AND EXISTS (SELECT 1
           FROM GE_ARQ_EXTRACTOS X
           WHERE X.COD_PERSONA = B.COD_PERSONA)
    AND EXISTS (SELECT 1
           FROM BA_PER_DAT_ADICIONALES T
           WHERE T.PARAMETRO = 'FRE_EXTRACTOS'
           AND T.COD_PERSONA = B.COD_PERSONA
           AND T.VAL_PARAMETRO = 'T')
    AND V_IND_TRIMESTRE = 'S';
  
    --Inserta fecha de ultimo Extracto Mensual si existe frecuencia y no existe fecha--
    INSERT INTO BA_PER_DAT_ADICIONALES
      (COD_PERSONA, PARAMETRO, VAL_PARAMETRO)
      SELECT DISTINCT x.cod_persona,
                      'FEC_ULT_EXTRACTOS',
                      to_char(x.fec_ult_extracto, 'dd/mm/yyyy')
      FROM GE_ARQ_EXTRACTOS X
      WHERE NOT EXISTS (SELECT 1
             FROM BA_PER_DAT_ADICIONALES y
             WHERE y.cod_persona = x.cod_persona
             AND y.parametro = 'FEC_ULT_EXTRACTOS')
      AND EXISTS (SELECT 1
             FROM BA_PER_DAT_ADICIONALES y
             WHERE y.cod_persona = x.cod_persona
             AND y.parametro = 'FRE_EXTRACTOS'
             AND y.val_parametro = 'M')
      AND v_ind_trimestre = 'N';
  
    --Inserta fecha de ultimo Extracto Trimestral si existe frecuencia y no existe fecha--
    INSERT INTO BA_PER_DAT_ADICIONALES
      (COD_PERSONA, PARAMETRO, VAL_PARAMETRO)
      SELECT DISTINCT x.cod_persona,
                      'FEC_ULT_EXTRACTOS',
                      to_char(x.fec_ult_extracto, 'dd/mm/yyyy')
      FROM GE_ARQ_EXTRACTOS X
      WHERE NOT EXISTS (SELECT 1
             FROM BA_PER_DAT_ADICIONALES y
             WHERE y.cod_persona = x.cod_persona
             AND y.parametro = 'FEC_ULT_EXTRACTOS')
      AND EXISTS (SELECT 1
             FROM BA_PER_DAT_ADICIONALES y
             WHERE y.cod_persona = x.cod_persona
             AND y.parametro = 'FRE_EXTRACTOS'
             AND y.val_parametro = 'T')
      AND v_ind_trimestre = 'S';
  
    --Inserta fecha de ultimo Extracto si no existe fecha ni frecuencia--
    INSERT INTO BA_PER_DAT_ADICIONALES
      (COD_PERSONA, PARAMETRO, VAL_PARAMETRO)
      SELECT DISTINCT x.cod_persona,
                      'FEC_ULT_EXTRACTOS',
                      to_char(x.fec_ult_extracto, 'dd/mm/yyyy')
      FROM GE_ARQ_EXTRACTOS X
      WHERE NOT EXISTS (SELECT 1
             FROM BA_PER_DAT_ADICIONALES y
             WHERE y.cod_persona = x.cod_persona
             AND y.parametro = 'FEC_ULT_EXTRACTOS')
      AND NOT EXISTS (SELECT 1
             FROM BA_PER_DAT_ADICIONALES y
             WHERE y.cod_persona = x.cod_persona
             AND y.parametro = 'FRE_EXTRACTOS');
  
    --Inserta Frecuencia de Extracto si existe fecha y no existe frecuencia--
    INSERT INTO BA_PER_DAT_ADICIONALES
      (COD_PERSONA, PARAMETRO, VAL_PARAMETRO)
      SELECT DISTINCT x.cod_persona, 'FRE_EXTRACTOS', 'M'
      FROM GE_ARQ_EXTRACTOS X
      WHERE EXISTS (SELECT 1
             FROM BA_PER_DAT_ADICIONALES y
             WHERE y.cod_persona = x.cod_persona
             AND y.parametro = 'FEC_ULT_EXTRACTOS')
      AND NOT EXISTS (SELECT 1
             FROM BA_PER_DAT_ADICIONALES y
             WHERE y.cod_persona = x.cod_persona
             AND y.parametro = 'FRE_EXTRACTOS');
  
  END lp_act_dat_adicionales;

  PROCEDURE lp_gen_est_tab_arq(p_tabla IN VARCHAR2) IS
  
  BEGIN
    BEGIN
      dbms_stats.gather_table_stats('IT', p_tabla);
    END;
  END lp_gen_est_tab_arq;

BEGIN

  -- Carga los valores de fecha que va a utilizar en el proceso --
  BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
  END;
  v_cod_programa := 'PRG_GEN_EXT_CLIENTES';
  pag_cal.pr_obt_dat_calendar(3);
  v_fec_actual        := pag_cal.G_FEC_ACTUAL;
  v_fec_sig_habil     := pag_cal.G_FEC_PROXIMA;
  v_fec_quincena      := lf_obt_fec_hab_quincena;
  v_pri_dia_mes_habil := pag_cal.G_PRI_DIA_MES_HABIL;
  v_ult_dia_mes_habil := pag_cal.G_ULT_DIA_MES_HABIL;
  v_cod_seg_fun       := fug_obt_pardinamico('SEG_FUNCIONARIOS');
  v_mes               := to_number(TRIM(to_char(v_fec_actual, 'mm')));
  v_ano               := to_number(TRIM(to_char(v_fec_actual, 'yyyy')));

  --Obs: La frecuencia se carga en lp_gen_extracto x cliente--
  --Calculo de las Frecuencias a Generar--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  pr_cal_fre_ext_generar;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'pr_cal_fre_ext_generar', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Truncar Tablas Temporales--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_tru_tab_temporales;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_tru_tab_temporales', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Insertar Tablas Temporales--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_car_tab_temporales;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_car_tab_temporales', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Generacion de Datos de Cuentas--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_gen_extracto;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_gen_extracto', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Insercion Mov. Ctacte en Tabla Auxiliar--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_ins_mov_tmp_cte;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_ins_mov_tmp_cte', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Insercion Mov. Ctaban en Tabla Auxiliar--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_ins_mov_tmp_ban;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_ins_mov_tmp_ban', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Insercion Mov. Vista en Tabla Auxiliar--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_ins_mov_tmp_vis;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_ins_mov_tmp_vis', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Insercion Mov. Rever en Tabla Auxiliar--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_ins_mov_tmp_rev;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_ins_mov_tmp_rev', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Generar Estadisticas Mov.Temporal--
  v_hor_inicio      := to_char(SYSDATE, 'hh24:mi:ss');
  v_tab_estadistica := 'GE_ARQ_CLI_MOV_GENERAR';
  lp_gen_est_tab_arq(v_tab_estadistica);
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_gen_est_tab_arq', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Insercion Mov. CtaCte en Mov.Extractos--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_ins_ge_arq_cli_mov_cte;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_ins_ge_arq_cli_mov_cte', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Insercion Mov. Ctaban en Mov.Extractos--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_ins_ge_arq_cli_mov_ban;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_ins_ge_arq_cli_mov_ban', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Insercion Mov. Vista en Mov.Extractos--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_ins_ge_arq_cli_mov_vis;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_ins_ge_arq_cli_mov_vis', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Insercion Movimientos Retenidos--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_ins_ge_arq_cli_cue_mov_ret;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_ins_ge_arq_cli_cue_mov_ret', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Insercion Movimientos Pendientes--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_ins_ge_arq_cli_cue_mov_pen;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_ins_ge_arq_cli_cue_mov_pen', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Generar Estadisticas Mov.Extracto--
  v_hor_inicio      := to_char(SYSDATE, 'hh24:mi:ss');
  v_tab_estadistica := 'GE_ARQ_CLI_MOVIMIENTOS';
  lp_gen_est_tab_arq(v_tab_estadistica);
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_gen_est_tab_arq', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Actualizar Saldo Actual--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_act_ge_arq_cli_cue_sal_act;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_act_ge_arq_cli_cue_sal_act', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Actualizar Saldo Promedio--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_act_ge_arq_cli_cue_sal_pro;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_act_ge_arq_cli_cue_sal_pro', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Actualiza Tipo de Cuenta--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_act_ge_arq_cli_cue_tip_cta;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_act_ge_arq_cli_cue_tip_cta', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Actualizar Datos de Tasas CtaCte--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_act_ge_arq_cli_cue_tasas;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_act_ge_arq_cli_cue_tasas', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Actualizar Cuentas Combinadas--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_act_ge_arq_cli_cue_tie_com;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_act_ge_arq_cli_cue_tie_com', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Actualizar si es Empleado--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_act_ge_arq_cli_dat_fun_bco;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_act_ge_arq_cli_dat_fun_bco', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Actualizar Datos Extractos--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_ins_ge_arq_extractos;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_ins_ge_arq_extractos', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Actualizar Datos Resumenes Ctacte--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_ins_ge_arq_resumenes;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_ins_ge_arq_resumenes', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Actuaizaciones Tabla Extractos--
  --Actializar Tipo de Impresion--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_act_tip_impresion;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_act_tip_impresion', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Actualiza Nro. de Control--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_act_nro_control;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_act_nro_control', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Actualiza Creditos y Debitos Negativos--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_act_deb_cre_negativos;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_act_deb_cre_negativos', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Actualizacion de Maestros--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_act_maestro;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_act_maestro', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Marca Extractos con Diferencia Saldo--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_mar_ext_con_diferencia;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_mar_ext_con_diferencia', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Marca Extractos con Diferencia Detalle--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_mar_ext_con_dif_detalle;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_mar_ext_con_dif_detalle', v_fec_actual, v_hor_inicio, v_hor_fin);

  --Actualiza Codigo de Mensaje--
  v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
  lp_act_cod_mensaje;
  v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos(v_cod_programa, 'lp_act_cod_mensaje', v_fec_actual, v_hor_inicio, v_hor_fin);

  -------------------------------------------------------
  --Para confirmar toda la parte de generacion de datos--
  COMMIT;
  -------------------------------------------------------

  v_ind_act_dat_extractos := nvl(fug_obt_pardinamico('IND_ACT_DAT_EXTRACTOS'), 'N');
  IF v_ind_act_dat_extractos = 'S' THEN
    --Actuaizaciones Tabla Extractos Produccion--
    --Verificar y Eliminar si existen Datos Anteriores--
    v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
    IF lf_ver_ext_generado > 0 THEN
      lp_eli_ext_generado;
    END IF;
    v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
    prg_act_log_procesos(v_cod_programa, 'lf_ver_ext_generado', v_fec_actual, v_hor_inicio, v_hor_fin);
  
    --Insertar Tablas de Extractos--
    --insertar de GE_ARQ a GE_EXT--
    v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
    lp_ins_dat_ext_generados;
    v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
    prg_act_log_procesos(v_cod_programa, 'lp_ins_dat_generados', v_fec_actual, v_hor_inicio, v_hor_fin);
  
    --Actualizar Saldos Mensuales--
    v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
    lp_act_ge_arq_cli_cue_sal_men;
    v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
    prg_act_log_procesos(v_cod_programa, 'lp_act_ge_arq_cli_cue_sal_men', v_fec_actual, v_hor_inicio, v_hor_fin);
  
    --Actualizacion de Hist. Ahorros--
    v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
    lp_act_folio_ahorros;
    v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
    prg_act_log_procesos(v_cod_programa, 'lp_act_folio_ahorros', v_fec_actual, v_hor_inicio, v_hor_fin);
  
    --Actualizacion de Hist. Ctactes--
    v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
    lp_act_folio_ctactes;
    v_hor_fin := to_char(SYSDATE, 'hh24:mi:ss');
    prg_act_log_procesos(v_cod_programa, 'lp_act_folio_ctactes', v_fec_actual, v_hor_inicio, v_hor_fin);
  
    --Actualizacion Dat Adicionales--
    lp_act_dat_adicionales;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE <= -20000 THEN
      RAISE;
    ELSE
      raise_application_error(-20000, v_lugar || '-' || SQLERRM);
    END IF;
END PRG_GEN_EXT_CLIENTES;
/

