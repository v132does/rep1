CREATE OR REPLACE PROCEDURE IT.prg_ins_ge_log_errores_his IS
  v_fec_hor_ini  DATE := SYSDATE;
  v_nro_registro NUMBER(10) := 0;
  v_log          ta_logs%ROWTYPE;
  v_error  boolean := true;
BEGIN
  BEGIN
  -- Insertar datos en la tabla histórica
  INSERT INTO ge_log_errores_his (
    cod_programa,
    campo1,
    dato1,
    campo2,
    dato2,
    campo3,
    dato3,
    det_error,
    usu_insercion,
    fec_insercion,
    usu_modificacion,
    fec_modificacion,
    cod_persona,
    nro_cuenta,
    fecha,
    fec_historico
  )
  SELECT
    cod_programa,
    campo1,
    dato1,
    campo2,
    dato2,
    campo3,
    dato3,
    det_error,
    usu_insercion,
    fec_insercion,
    usu_modificacion,
    fec_modificacion,
    cod_persona,
    nro_cuenta,
    fecha,
    SYSDATE
  FROM
    IT.GE_LOG_ERRORES a
  WHERE
    TRUNC(a.fec_insercion) < TRUNC(SYSDATE) - 30;
  COMMIT;
  -- Manejo de excepciones en caso de error en la inserción
  EXCEPTION
    WHEN OTHERS THEN
      v_error:= false;
      v_log.nom_proceso := 'PRG_MIG_GE_LOG_ERRORES_HIS';
      v_log.fec_hor_ini := v_fec_hor_ini;
      v_log.fec_hor_fin := SYSDATE;
      v_log.nro_reg := v_nro_registro;
      v_log.nro_error := SQLCODE;
      v_log.men_error := SQLERRM;
      v_log.comentario := 'Error al insertar datos al Historico.';
      PRT_INS_LOG(v_log, TRUE);
  END;
  -- Eliminar registros de la tabla principal que ya están en la tabla histórica
  IF v_error then
    BEGIN
      DELETE FROM IT.GE_LOG_ERRORES a
      WHERE TRUNC(a.fec_insercion) < TRUNC(SYSDATE) - 30;
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        v_log.nom_proceso := 'PRG_MIG_GE_LOG_ERRORES_HIS';
        v_log.fec_hor_ini := v_fec_hor_ini;
        v_log.fec_hor_fin := SYSDATE;
        v_log.nro_reg := 1;
        v_log.nro_error := SQLCODE;
        v_log.men_error := SQLERRM;
        v_log.comentario := 'Error al ejecutar el DELETE en la tabla GE_LOG_ERRORES.';
        PRT_INS_LOG(v_log, TRUE);
    END;
  END IF;
END;
/
