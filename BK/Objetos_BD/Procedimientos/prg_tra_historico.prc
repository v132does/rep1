CREATE OR REPLACE PROCEDURE IT.PRG_TRA_HISTORICO(P_ACCION IN NUMBER DEFAULT NULL)
IS
   v_fecha ge_movimientos.fecha%type := pag_cal.fu_obt_fec_actual(1);

   -- tcasco
   T_REFERENCIAS SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();

   V_COD_SUB_PROGRAMA   GE_PRO_PARALELOS_DET.COD_SUB_PROGRAMA%TYPE;
   V_COD_PROGRAMA       GE_LOG_PROCESOS.COD_PROGRAMA%TYPE:= 'PRG_TRA_HISTORICO';
   V_NRO_ORDEN          GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
   V_INDICE             NUMBER(4);
   V_CAN_JOB_PARALELO   NUMBER(4):= 3;
   V_SENTENCIA          VARCHAR2(4000);
   V_LUGAR              VARCHAR2(250);
   V_HOR_FIN            VARCHAR2(8);
   V_JOBS               NUMBER;
   V_CAN_PRO_ACTIVOS    NUMBER;
   V_CAN_PRO_ERROR      NUMBER;
   V_TIEMPO             DATE;

   FUNCTION LF_VER_REPROCESO RETURN BOOLEAN IS
    v_tiene_error VARCHAR2(4000);
    BEGIN
        SELECT error
          INTO v_tiene_error
          FROM ge_pro_paralelos_det
         WHERE cod_programa = v_cod_programa
           AND cod_sub_programa = v_cod_sub_programa
           AND fecha = v_fecha
           ORDER BY fec_insercion DESC
           FETCH FIRST 1 ROW ONLY;

        -- Si tiene error (no es null), debe relanzarse
        RETURN v_tiene_error IS NOT NULL;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN TRUE; -- No hay ejecución previa: se puede ejecutar
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001, 'Error en LF_VER_REPROCESO - ' || SQLERRM);
    END;
   
   
   PROCEDURE lp_tra_ge_movimientos IS
   BEGIN

      INSERT INTO ge_movimientos_his
      SELECT v_fecha,m.hora,m.cod_usuario, m.nro_secuencia, m.fec_valor,
             m.monto, m.nro_cuenta, m.cod_moneda, m.cod_oficina, m.cod_error,
             m.cod_retencion, m.fec_fin_retencion, m.est_cuenta, m.estado,
             m.cod_causa, m.cod_banco, m.cod_ofi_origen, m.concepto, m.cod_tasa,
             m.val_tasa, m.cod_rubro, m.cod_ref_cambio, m.reversado, m.cod_usu_reversion,
             m.hor_reversion, m.emi_aviso, m.cod_tra_padre, m.cod_mod_padre, m.cod_mad_padre,
             m.cod_transaccion, m.cod_modulo, m.cod_modalidad, m.mto_equ_local, m.nro_caja,
             m.cotizacion, m.cod_bco_central, m.nro_documento, m.nro_documento2, m.nro_documento3,
             m.nro_documento4, m.protegido, m.tip_mov_rubro, m.cod_autorizacion, m.cod_usu_autorizador,
             m.usu_insercion, m.fec_insercion, m.usu_modificacion, m.fec_modificacion,
             m.cod_tip_ope_cambio, NULL nro_folio, NULL cod_tip_operacion, m.referencia
        FROM ge_movimientos m
        LEFT JOIN ge_movimientos_tmp t
          ON t.fecha = v_fecha
         AND t.hora = m.hora
         AND t.nro_secuencia = m.nro_secuencia
         AND t.cod_usuario = m.cod_usuario
       WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
         AND ((m.cod_modulo = 1 AND m.cod_mod_padre = 1) OR (m.cod_modulo = 2 AND m.cod_mod_padre in (1,2,9)))
         AND t.fecha IS NULL;

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR. En lp_tra_ge_movimientos.'||sqlerrm);
   END;

   PROCEDURE lp_tra_ah_movimientos IS
   BEGIN
      EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';
      INSERT /*+ APPEND PARALLEL(ah_movimientos_his, 4) */ 
        INTO ah_movimientos_his
      SELECT /*+ FULL(m) PARALLEL(m, 4) */
             v_fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.fec_valor,
             m.monto, m.nro_cuenta, m.cod_moneda, m.cod_oficina, m.cod_error,
             m.cod_retencion, m.fec_fin_retencion, m.est_cuenta, m.estado,
             m.cod_causa, m.cod_banco, m.cod_ofi_origen, m.concepto, m.cod_tasa,
             m.val_tasa, m.cod_rubro, m.cod_ref_cambio, m.reversado, m.cod_usu_reversion,
             m.hor_reversion, m.emi_aviso, m.cod_tra_padre, m.cod_mod_padre, m.cod_mad_padre,
             m.cod_transaccion, m.cod_modulo, m.cod_modalidad, m.mto_equ_local, m.nro_caja,
             m.cotizacion, m.cod_bco_central, m.nro_documento, m.nro_documento2, m.nro_documento3,
             m.nro_documento4, m.protegido, m.tip_mov_rubro, m.cod_autorizacion, m.cod_usu_autorizador,
             m.usu_insercion, m.fec_insercion, m.usu_modificacion, m.fec_modificacion,
             m.cod_tip_ope_cambio, NULL nro_folio, NULL cod_tip_operacion, m.referencia,
             m.cod_persona, m.cod_sit_contable, m.nro_conciliacion
        FROM ge_movimientos m
       WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
         AND (m.cod_modulo = 3 OR (m.cod_modulo = 9 AND m.cod_mod_padre = 3))
         AND NOT EXISTS (
             SELECT /*+ FULL(t) PARALLEL(t, 4) HASH_AJ SWAP_JOIN_INPUTS(t) PQ_DISTRIBUTE(t BROADCAST NONE) */ 1 
               FROM ge_movimientos_tmp t
              WHERE t.fecha = v_fecha
                AND t.hora = m.hora
                AND t.nro_secuencia = m.nro_secuencia
                AND t.cod_usuario = m.cod_usuario
         );

      COMMIT;
      EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
         raise_application_error(-20000, 'ERROR. En lp_tra_ah_movimientos.'||sqlerrm);
   END;

   PROCEDURE lp_tra_cc_movimientos IS
   BEGIN
      EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';

      INSERT /*+ APPEND PARALLEL(cc_movimientos_his, 4) */
      INTO cc_movimientos_his
      SELECT /*+ FULL(m) PARALLEL(m, 4) */
             v_fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.fec_valor,
             m.monto, m.nro_cuenta, m.cod_moneda, m.cod_oficina, m.cod_error,
             m.cod_retencion, m.fec_fin_retencion, m.est_cuenta, m.estado,
             m.cod_causa, m.cod_banco, m.cod_ofi_origen, m.concepto, m.cod_tasa,
             m.val_tasa, m.cod_rubro, m.cod_ref_cambio, m.reversado, m.cod_usu_reversion,
             m.hor_reversion, m.emi_aviso, m.cod_tra_padre, m.cod_mod_padre, m.cod_mad_padre,
             m.cod_transaccion, m.cod_modulo, m.cod_modalidad, m.mto_equ_local, m.nro_caja,
             m.cotizacion, m.cod_bco_central, m.nro_documento, m.nro_documento2, m.nro_documento3,
             m.nro_documento4, m.protegido, m.cod_autorizacion, m.cod_usu_autorizador,
             m.usu_insercion, m.fec_insercion, m.usu_modificacion, m.fec_modificacion,
             m.tip_mov_rubro, m.cod_tip_ope_cambio, NULL nro_folio, m.referencia,
             m.cod_persona, m.cod_sit_contable, m.nro_conciliacion
        FROM ge_movimientos m
       WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
         AND (m.cod_modulo = 4 OR (m.cod_modulo = 9 AND m.cod_mod_padre = 4))
         AND NOT EXISTS (
             SELECT /*+ FULL(t) PARALLEL(t, 4) HASH_AJ SWAP_JOIN_INPUTS(t) PQ_DISTRIBUTE(t BROADCAST NONE) */ 1 
               FROM ge_movimientos_tmp t
              WHERE t.fecha = v_fecha
                AND t.hora = m.hora
                AND t.nro_secuencia = m.nro_secuencia
                AND t.cod_usuario = m.cod_usuario
         );

      COMMIT;
      EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
   EXCEPTION
      WHEN OTHERS THEN
         EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
         raise_application_error(-20000, 'ERROR. En lp_tra_cc_movimientos.'||sqlerrm);
   END;

   PROCEDURE lp_tra_ta_movimientos IS
   BEGIN
      EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';

      INSERT /*+ APPEND PARALLEL(ta_movimientos_his, 4) */
      INTO ta_movimientos_his
      SELECT /*+ FULL(m) PARALLEL(m, 4) */
             v_fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.fec_valor,
             m.monto, m.nro_cuenta, m.cod_moneda, m.cod_oficina, m.cod_error,
             m.cod_retencion, m.fec_fin_retencion, m.est_cuenta, m.estado,
             m.cod_causa, m.cod_banco, m.cod_ofi_origen, m.concepto, m.cod_tasa,
             m.val_tasa, m.cod_rubro, m.cod_ref_cambio, m.reversado, m.cod_usu_reversion,
             m.hor_reversion, m.emi_aviso, m.cod_tra_padre, m.cod_mod_padre, m.cod_mad_padre,
             m.cod_transaccion, m.cod_modulo, m.cod_modalidad, m.mto_equ_local, m.nro_caja,
             m.cotizacion, m.cod_bco_central, m.nro_documento, m.nro_documento2, m.nro_documento3,
             m.nro_documento4, m.protegido, m.tip_mov_rubro, m.cod_autorizacion, m.cod_usu_autorizador,
             m.cod_tip_ope_cambio, m.usu_insercion, m.fec_insercion, m.usu_modificacion, m.fec_modificacion,
             m.referencia, m.cod_persona, m.cod_sit_contable
        FROM ge_movimientos m
       WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
         AND (m.cod_modulo = 5 OR (m.cod_modulo = 9 AND m.cod_mod_padre = 5))
         AND NOT EXISTS (
             SELECT /*+ FULL(t) PARALLEL(t, 4) HASH_AJ SWAP_JOIN_INPUTS(t) PQ_DISTRIBUTE(t BROADCAST NONE) */ 1 
               FROM ge_movimientos_tmp t
              WHERE t.fecha = v_fecha
                AND t.hora = m.hora
                AND t.nro_secuencia = m.nro_secuencia
                AND t.cod_usuario = m.cod_usuario);

      COMMIT;
      EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
   EXCEPTION
      WHEN OTHERS THEN
         EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
         raise_application_error(-20000, 'ERROR. En lp_tra_ta_movimientos.'||sqlerrm);
   END;

   PROCEDURE lp_tra_pr_movimientos IS
   BEGIN
      EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';

      INSERT /*+ APPEND PARALLEL(pr_movimientos_his, 2) */
      INTO pr_movimientos_his
      SELECT /*+ FULL(m) PARALLEL(m, 2) */
             v_fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.fec_valor,
             m.monto, m.nro_cuenta, m.cod_moneda, m.cod_oficina, m.cod_error,
             m.cod_retencion, m.fec_fin_retencion, m.est_cuenta, m.estado,
             m.cod_causa, m.cod_banco, m.cod_ofi_origen, m.concepto, m.cod_tasa,
             m.val_tasa, m.cod_rubro, m.cod_ref_cambio, m.reversado, m.cod_usu_reversion,
             m.hor_reversion, m.emi_aviso, m.cod_tra_padre, m.cod_mod_padre, m.cod_mad_padre,
             m.cod_transaccion, m.cod_modulo, m.cod_modalidad, m.mto_equ_local, m.nro_caja,
             m.cotizacion, m.cod_bco_central, m.nro_documento, m.nro_documento2, m.nro_documento3,
             m.nro_documento4, m.protegido, m.tip_mov_rubro, m.cod_autorizacion, m.cod_usu_autorizador,
             m.cod_tip_ope_cambio, m.usu_insercion, m.fec_insercion, m.usu_modificacion, m.fec_modificacion,
             m.referencia, m.cod_persona, m.cod_sit_contable
        FROM ge_movimientos m
       WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
         AND (m.cod_modulo = 6 OR (m.cod_modulo = 9 AND m.cod_mod_padre = 6))
         AND NOT EXISTS (
             SELECT /*+ FULL(t) PARALLEL(t, 4) HASH_AJ SWAP_JOIN_INPUTS(t) PQ_DISTRIBUTE(t BROADCAST NONE) */ 1 
               FROM ge_movimientos_tmp t
              WHERE t.fecha = v_fecha
                AND t.hora = m.hora
                AND t.nro_secuencia = m.nro_secuencia
                AND t.cod_usuario = m.cod_usuario);

      COMMIT;
      EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
   EXCEPTION
      WHEN OTHERS THEN
         EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
         raise_application_error(-20000, 'ERROR. En lp_tra_pr_movimientos.'||sqlerrm);
   END;

   PROCEDURE lp_tra_lc_movimientos IS
   BEGIN

      INSERT INTO lc_movimientos_his
      SELECT v_fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.fec_valor,
             m.monto, m.nro_cuenta, m.cod_moneda, m.cod_oficina, m.cod_error,
             m.cod_retencion, m.fec_fin_retencion, m.est_cuenta, m.estado,
             m.cod_causa, m.cod_banco, m.cod_ofi_origen, m.concepto, m.cod_tasa,
             m.val_tasa, m.cod_rubro, m.cod_ref_cambio, m.reversado, m.cod_usu_reversion,
             m.hor_reversion, m.emi_aviso, m.cod_tra_padre, m.cod_mod_padre, m.cod_mad_padre,
             m.cod_transaccion, m.cod_modulo, m.cod_modalidad, m.mto_equ_local, m.nro_caja,
             m.cotizacion, m.cod_bco_central, m.nro_documento, m.nro_documento2, m.nro_documento3,
             m.nro_documento4, m.protegido, m.cod_autorizacion, m.cod_usu_autorizador,
             m.tip_mov_rubro, m.cod_tip_ope_cambio, m.usu_insercion, m.fec_insercion,
             m.usu_modificacion, m.fec_modificacion, m.referencia, m.cod_persona, m.cod_sit_contable
        FROM ge_movimientos m
        LEFT JOIN ge_movimientos_tmp t
          ON t.fecha = v_fecha
         AND t.hora = m.hora
         AND t.nro_secuencia = m.nro_secuencia
         AND t.cod_usuario = m.cod_usuario
       WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
         AND (m.cod_modulo = 7 OR (m.cod_modulo = 9 AND m.cod_mod_padre = 7))
         AND t.fecha IS NULL;

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR. En lp_tra_lc_movimientos.'||sqlerrm);
   END;

   PROCEDURE lp_tra_cx_movimientos IS
   BEGIN

      INSERT INTO cx_movimientos_his
      SELECT v_fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.fec_valor,
             m.monto, m.nro_cuenta, m.cod_moneda, m.cod_oficina, m.cod_error,
             m.cod_retencion, m.fec_fin_retencion, m.est_cuenta, m.estado,
             m.cod_causa, m.cod_banco, m.cod_ofi_origen, m.concepto, m.cod_tasa,
             m.val_tasa, m.cod_rubro, m.cod_ref_cambio, m.reversado, m.cod_usu_reversion,
             m.hor_reversion, m.emi_aviso, m.cod_tra_padre, m.cod_mod_padre, m.cod_mad_padre,
             m.cod_transaccion, m.cod_modulo, m.cod_modalidad, m.mto_equ_local, m.nro_caja,
             m.cotizacion, m.cod_bco_central, m.nro_documento, m.nro_documento2, m.nro_documento3,
             m.nro_documento4, m.protegido, m.cod_autorizacion, m.cod_usu_autorizador,
             m.usu_insercion, m.fec_insercion, m.usu_modificacion, m.fec_modificacion,
             m.tip_mov_rubro, m.cod_tip_ope_cambio, m.referencia, m.cod_persona, m.cod_sit_contable
        FROM ge_movimientos m
        LEFT JOIN ge_movimientos_tmp t
          ON t.fecha = v_fecha
         AND t.hora = m.hora
         AND t.nro_secuencia = m.nro_secuencia
         AND t.cod_usuario = m.cod_usuario
       WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
         AND (m.cod_modulo = 8 OR (m.cod_modulo = 9 AND m.cod_mod_padre = 8))
         AND t.fecha IS NULL;

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR. En lp_tra_cx_movimientos.'||sqlerrm);
   END;

   PROCEDURE lp_tra_md_movimientos IS
   BEGIN

      INSERT INTO md_movimientos_his
      SELECT v_fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.fec_valor,
             m.monto, m.nro_cuenta, m.cod_moneda, m.cod_oficina, m.cod_error,
             m.cod_retencion, m.fec_fin_retencion, m.est_cuenta, m.estado,
             m.cod_causa, m.cod_banco, m.cod_ofi_origen, m.concepto, m.cod_tasa,
             m.val_tasa, m.cod_rubro, m.cod_ref_cambio, m.reversado, m.cod_usu_reversion,
             m.hor_reversion, m.emi_aviso, m.cod_tra_padre, m.cod_mod_padre, m.cod_mad_padre,
             m.cod_transaccion, m.cod_modulo, m.cod_modalidad, m.mto_equ_local, m.nro_caja,
             m.cotizacion, m.cod_bco_central, m.nro_documento, m.nro_documento2, m.nro_documento3,
             m.nro_documento4, m.protegido, m.cod_autorizacion, m.cod_usu_autorizador, m.usu_insercion,
             m.fec_insercion, m.usu_modificacion, m.fec_modificacion, m.tip_mov_rubro,
             m.cod_tip_ope_cambio, m.referencia, m.cod_sit_contable, m.cod_persona
        FROM ge_movimientos m
        LEFT JOIN ge_movimientos_tmp t
          ON t.fecha = v_fecha
         AND t.hora = m.hora
         AND t.nro_secuencia = m.nro_secuencia
         AND t.cod_usuario = m.cod_usuario
       WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
         AND (m.cod_modulo = 10 OR (m.cod_modulo = 9 AND m.cod_mod_padre = 10))
         AND t.fecha IS NULL;

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR. En lp_tra_md_movimientos.'||sqlerrm);
   END;

   PROCEDURE lp_tra_af_movimientos IS
   BEGIN

      INSERT INTO af_movimientos_his
      SELECT v_fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.fec_valor,
             m.monto, m.nro_cuenta, m.cod_moneda, m.cod_oficina, m.cod_error,
             m.cod_retencion, m.fec_fin_retencion, m.est_cuenta, m.estado,
             m.cod_causa, m.cod_banco, m.cod_ofi_origen, m.concepto, m.cod_tasa,
             m.val_tasa, m.cod_rubro, m.cod_ref_cambio, m.reversado, m.cod_usu_reversion,
             m.hor_reversion, m.emi_aviso, m.cod_tra_padre, m.cod_mod_padre, m.cod_mad_padre,
             m.cod_transaccion, m.cod_modulo, m.cod_modalidad, m.mto_equ_local, m.nro_caja,
             m.cotizacion, m.cod_bco_central, m.nro_documento, m.nro_documento2, m.nro_documento3,
             m.nro_documento4, m.protegido, m.tip_mov_rubro, m.cod_autorizacion, m.cod_usu_autorizador,
             m.usu_insercion, m.fec_insercion, m.usu_modificacion, m.fec_modificacion,
             m.cod_tip_ope_cambio, NULL nro_folio, NULL cod_tip_operacion,
             m.referencia, m.cod_persona, m.cod_sit_contable
        FROM ge_movimientos m
        LEFT JOIN ge_movimientos_tmp t
          ON t.fecha = v_fecha
         AND t.hora = m.hora
         AND t.nro_secuencia = m.nro_secuencia
         AND t.cod_usuario = m.cod_usuario
       WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
         AND (m.cod_modulo = 13 OR (m.cod_modulo = 9 AND m.cod_mod_padre = 13))
         AND t.fecha IS NULL;

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR. En lp_tra_af_movimientos.'||sqlerrm);
   END;

   PROCEDURE lp_tra_rh_movimientos IS
   BEGIN

      INSERT INTO rh_movimientos_his
      SELECT v_fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.fec_valor,
             m.monto, m.nro_cuenta, m.cod_moneda, m.cod_oficina, m.cod_error,
             m.cod_retencion, m.fec_fin_retencion, m.est_cuenta, m.estado,
             m.cod_causa, m.cod_banco, m.cod_ofi_origen, m.concepto, m.cod_tasa,
             m.val_tasa, m.cod_rubro, m.cod_ref_cambio, m.reversado, m.cod_usu_reversion,
             m.hor_reversion, m.emi_aviso, m.cod_tra_padre, m.cod_mod_padre, m.cod_mad_padre,
             m.cod_transaccion, m.cod_modulo, m.cod_modalidad, m.mto_equ_local, m.nro_caja,
             m.cotizacion, m.cod_bco_central, m.nro_documento, m.nro_documento2, m.nro_documento3,
             m.nro_documento4, m.protegido, m.tip_mov_rubro, m.cod_autorizacion, m.cod_usu_autorizador,
             m.cod_tip_ope_cambio, m.usu_insercion, m.fec_insercion, m.usu_modificacion,
             m.fec_modificacion, m.referencia, m.cod_sit_contable
        FROM ge_movimientos m
        LEFT JOIN ge_movimientos_tmp t
          ON t.fecha = v_fecha
         AND t.hora = m.hora
         AND t.nro_secuencia = m.nro_secuencia
         AND t.cod_usuario = m.cod_usuario
       WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
         AND (m.cod_modulo = 14 OR (m.cod_modulo = 9 AND m.cod_mod_padre = 14))
         AND t.fecha IS NULL;

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR. En lp_tra_rh_movimientos.'||sqlerrm);
   END;

   PROCEDURE lp_tra_ov_movimientos IS
   BEGIN

      INSERT INTO ov_movimientos_his
      SELECT v_fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.fec_valor,
             m.monto, m.nro_cuenta, m.cod_moneda, m.cod_oficina, m.cod_error,
             m.cod_retencion, m.fec_fin_retencion, m.est_cuenta, m.estado,
             m.cod_causa, m.cod_banco, m.cod_ofi_origen, m.concepto, m.cod_tasa,
             m.val_tasa, m.cod_rubro, m.cod_ref_cambio, m.reversado, m.cod_usu_reversion,
             m.hor_reversion, m.emi_aviso, m.cod_tra_padre, m.cod_mod_padre, m.cod_mad_padre,
             m.cod_transaccion, m.cod_modulo, m.cod_modalidad, m.mto_equ_local, m.nro_caja,
             m.cotizacion, m.cod_bco_central, m.nro_documento, m.nro_documento2, m.nro_documento3,
             m.nro_documento4, m.protegido, m.tip_mov_rubro, m.cod_autorizacion, m.cod_usu_autorizador,
             m.cod_tip_ope_cambio, m.usu_insercion, m.fec_insercion, m.usu_modificacion, m.fec_modificacion,
             m.referencia, m.cod_sit_contable, m.cod_persona
        FROM ge_movimientos m
        LEFT JOIN ge_movimientos_tmp t
          ON t.fecha = v_fecha
         AND t.hora = m.hora
         AND t.nro_secuencia = m.nro_secuencia
         AND t.cod_usuario = m.cod_usuario
       WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
         AND (nvl(m.cod_modulo, 15) IN (15, 16, 28) OR
             (m.cod_modulo = 9 AND m.cod_mod_padre IN (15, 16, 9, 28)))
         AND t.fecha IS NULL;

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR. En lp_tra_ov_movimientos.'||sqlerrm);
   END;

   PROCEDURE lp_tra_bu_movimientos IS
   BEGIN

      INSERT INTO bu_movimientos_his
      SELECT v_fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.fec_valor,
             m.monto, m.nro_cuenta, m.cod_moneda, m.cod_oficina, m.cod_error,
             m.cod_retencion, m.fec_fin_retencion, m.est_cuenta, m.estado,
             m.cod_causa, m.cod_banco, m.cod_ofi_origen, m.concepto, m.cod_tasa,
             m.val_tasa, m.cod_rubro, m.cod_ref_cambio, m.reversado, m.cod_usu_reversion,
             m.hor_reversion, m.emi_aviso, m.cod_tra_padre, m.cod_mod_padre, m.cod_mad_padre,
             m.cod_transaccion, m.cod_modulo, m.cod_modalidad, m.mto_equ_local, m.nro_caja,
             m.cotizacion, m.cod_bco_central, m.nro_documento, m.nro_documento2, m.nro_documento3,
             m.nro_documento4, m.protegido, m.tip_mov_rubro, m.cod_autorizacion, m.cod_usu_autorizador,
             m.cod_tip_ope_cambio, m.usu_insercion, m.fec_insercion, m.usu_modificacion, m.fec_modificacion,
             m.referencia
        FROM ge_movimientos m
        LEFT JOIN ge_movimientos_tmp t
          ON t.fecha = v_fecha
         AND t.hora = m.hora
         AND t.nro_secuencia = m.nro_secuencia
         AND t.cod_usuario = m.cod_usuario
       WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
         AND (m.cod_modulo = 26 OR (m.cod_modulo = 9 AND m.cod_mod_padre = 26))
         AND t.fecha IS NULL;

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR. En lp_tra_bu_movimientos.'||sqlerrm);
   END;

BEGIN
   IF p_accion is null THEN
     BEGIN
       V_COD_SUB_PROGRAMA:= 'Proceso Principal en Paralelo';
       V_LUGAR := V_COD_SUB_PROGRAMA;
       PRG_CON_PRO_PARALELOS(V_COD_PROGRAMA, V_COD_SUB_PROGRAMA, 0, V_FECHA,'I', TO_CHAR(SYSDATE,'HH24:MI:SS'), null);
       V_CAN_PRO_ACTIVOS := V_CAN_JOB_PARALELO;
       --Ciclo para habilitar los hilos de procesos en paralelo--
        FOR V_INDICE IN 1..V_CAN_JOB_PARALELO LOOP
            CASE V_INDICE
                WHEN 1 THEN V_COD_SUB_PROGRAMA := 'JOB_1_LP_TRA_AH_MOVIMIENTOS';
                WHEN 2 THEN V_COD_SUB_PROGRAMA := 'JOB_2_LP_TRA_CC_MOVIMIENTOS';
                WHEN 3 THEN V_COD_SUB_PROGRAMA := 'JOB_3_LP_TRA_MOV_RESTANTES';
                ELSE
                    V_COD_SUB_PROGRAMA := 'JOB_'||V_INDICE;
            END CASE;
            V_SENTENCIA := NULL;
            V_NRO_ORDEN := NVL(V_INDICE,1);
            V_SENTENCIA := 'begin Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; PAE_CNF.G_PROGRAMA:=  ''GPPROFIN'';  end;
            IT.'||V_COD_PROGRAMA||'('||V_NRO_ORDEN||'); end;';
            --Inicia Hilos de Procesos--
            if LF_VER_REPROCESO then
              DBMS_JOB.submit(v_jobs,V_SENTENCIA);
              t_referencias.EXTEND;
              t_referencias(t_referencias.COUNT) := v_jobs;
              --controlado en el while
              PRG_CON_PRO_PARALELOS(V_COD_PROGRAMA, V_COD_SUB_PROGRAMA, V_NRO_ORDEN, V_FECHA,'I', TO_CHAR(SYSDATE,'HH24:MI:SS'), v_jobs);
              COMMIT;
            end if;
        END LOOP;
       -- VALIDAR SI TODOS LOS JOBS TERMINARON
        V_LUGAR := 'Loop de control';
        WHILE V_CAN_PRO_ACTIVOS > 0 LOOP
            -- Contar jobs activos para el programa paralelo y fecha actual
            SELECT NVL(COUNT(*), 0)
              INTO V_CAN_PRO_ACTIVOS
              FROM user_jobs x
             WHERE UPPER(what) LIKE '%' || UPPER(V_COD_PROGRAMA) || '%'
               AND EXISTS (
                    SELECT 1
                      FROM GE_PRO_PARALELOS_DET y
                     WHERE y.nro_referencia = x.job
                       AND y.fecha = v_fecha
               );

            -- Contar jobs que hayan fallado
            SELECT COUNT(*)
             INTO V_CAN_PRO_ERROR
             FROM ge_pro_paralelos_det
            WHERE COD_PROGRAMA = V_COD_PROGRAMA
              AND fecha = v_fecha
              AND error is not null
              AND nro_referencia IN (
                  SELECT COLUMN_VALUE FROM TABLE(t_referencias)
              );

            -- Si hay al menos un error, salir y lanzar error
            IF V_CAN_PRO_ERROR > 0 THEN
                RAISE_APPLICATION_ERROR(-20002, 'Al menos un job hijo falló en el proceso paralelo: ' || V_COD_PROGRAMA);
            END IF;

            -- Si ya no hay activos, salir del bucle
            IF V_CAN_PRO_ACTIVOS = 0 THEN
                EXIT;
            END IF;

            -- Controla cada 30sg
            V_TIEMPO := pai_int.smg_sleep('30');
        END LOOP;
       -- Finalizar
       V_COD_SUB_PROGRAMA:= 'Proceso Principal en Paralelo';
       V_NRO_ORDEN:= 0;
       v_hor_fin := to_char(sysdate,'hh24:mi:ss');
       PRG_CON_PRO_PARALELOS(V_COD_PROGRAMA, V_COD_SUB_PROGRAMA, V_NRO_ORDEN, V_FECHA,'F', V_HOR_FIN);
     EXCEPTION
       WHEN OTHERS THEN
         V_COD_SUB_PROGRAMA:= 'Proceso Principal en Paralelo';
         V_NRO_ORDEN:= 0;
         PRG_CON_PRO_PARALELOS(V_COD_PROGRAMA, V_COD_SUB_PROGRAMA, V_NRO_ORDEN, V_FECHA,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM);
         RAISE_APPLICATION_ERROR(-20000, SQLERRM||' / '||V_LUGAR);
     END;
   ELSIF P_ACCION = 1 THEN
     BEGIN
       V_NRO_ORDEN := P_ACCION;
       V_COD_SUB_PROGRAMA := 'JOB_1_LP_TRA_AH_MOVIMIENTOS';
       V_LUGAR := V_COD_SUB_PROGRAMA;
       lp_tra_ah_movimientos;
       -- Finalizar
       v_hor_fin := to_char(sysdate,'hh24:mi:ss');
       PRG_CON_PRO_PARALELOS(V_COD_PROGRAMA, V_COD_SUB_PROGRAMA, V_NRO_ORDEN, V_FECHA,'F', V_HOR_FIN);
     EXCEPTION
      WHEN OTHERS THEN
         PRG_CON_PRO_PARALELOS(V_COD_PROGRAMA, V_COD_SUB_PROGRAMA, V_NRO_ORDEN, V_FECHA,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM);
         RAISE_APPLICATION_ERROR(-20000, SQLERRM||' / '||V_LUGAR);
     END;
   ELSIF P_ACCION = 2 THEN
     BEGIN
       V_NRO_ORDEN := P_ACCION;
       V_COD_SUB_PROGRAMA := 'JOB_2_LP_TRA_CC_MOVIMIENTOS';
       V_LUGAR := V_COD_SUB_PROGRAMA;

       lp_tra_cc_movimientos;

       -- Finalizar
       v_hor_fin := to_char(sysdate,'hh24:mi:ss');
       PRG_CON_PRO_PARALELOS(V_COD_PROGRAMA, V_COD_SUB_PROGRAMA, V_NRO_ORDEN, V_FECHA,'F', V_HOR_FIN);
     EXCEPTION
         WHEN OTHERS THEN
            PRG_CON_PRO_PARALELOS(V_COD_PROGRAMA, V_COD_SUB_PROGRAMA, V_NRO_ORDEN, V_FECHA, 'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM);
            RAISE_APPLICATION_ERROR(-20000, SQLERRM || ' / ' || V_LUGAR);
     END;

   ELSIF P_ACCION = 3 THEN
     BEGIN
       V_NRO_ORDEN := P_ACCION;
       V_COD_SUB_PROGRAMA := 'JOB_3_LP_TRA_MOV_RESTANTES';
       V_LUGAR := V_COD_SUB_PROGRAMA;

       lp_tra_ge_movimientos;
       lp_tra_ta_movimientos;
       lp_tra_pr_movimientos;
       lp_tra_lc_movimientos;
       lp_tra_cx_movimientos;
       lp_tra_md_movimientos;
       lp_tra_af_movimientos;
       lp_tra_rh_movimientos;
       lp_tra_ov_movimientos;
       lp_tra_bu_movimientos;

       -- Finalizar
       v_hor_fin := to_char(sysdate,'hh24:mi:ss');
       PRG_CON_PRO_PARALELOS(V_COD_PROGRAMA, V_COD_SUB_PROGRAMA, V_NRO_ORDEN, V_FECHA,'F', V_HOR_FIN);
     EXCEPTION
         WHEN OTHERS THEN
            PRG_CON_PRO_PARALELOS(V_COD_PROGRAMA, V_COD_SUB_PROGRAMA, V_NRO_ORDEN, V_FECHA, 'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM);
            RAISE_APPLICATION_ERROR(-20000, SQLERRM || ' / ' || V_LUGAR);
     END;
   END IF;

   COMMIT;
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE <= -20000 THEN
         RAISE;
      ELSE
         raise_application_error(-20000, 'Error en (prg_tra_historico). ' || SQLERRM);
      END IF;
END;
/
