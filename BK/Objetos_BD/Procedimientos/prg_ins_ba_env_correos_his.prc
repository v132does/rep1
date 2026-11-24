CREATE OR REPLACE PROCEDURE IT.prg_ins_ba_env_correos_his IS
  v_fec_hor_ini  DATE := SYSDATE;
  v_nro_registro NUMBER(10) := 0;
  v_log          ta_logs%rowtype;
  v_error        boolean := true;
BEGIN
  BEGIN
    -- Insertar datos en la tabla histórica
    INSERT INTO ba_env_correos_his (
      nro_correo,
      cod_persona,
      tip_producto,
      estado,
      fec_registro,
      fec_envio,
      msj_error,
      parametros,
      mai_destinatario,
      fec_historico,
      usu_insercion,
      fec_insercion,
      usu_modificacion,
      fec_modificacion
    )
    SELECT
      a.nro_correo,
      a.cod_persona,
      a.tip_producto,
      a.estado,
      a.fec_registro,
      a.fec_envio,
      a.msj_error,
      TO_LOB(a.parametros),
      a.mai_destinatario,
      SYSDATE,
      a.usu_insercion,
      a.fec_insercion,
      a.usu_modificacion,
      a.fec_modificacion
    FROM
      it.ba_env_correos a
    WHERE a.fec_insercion < pag_cal.fu_obt_fec_actual(1);
    COMMIT;
  -- Manejo de excepciones en caso de error en la inserción
  EXCEPTION
    WHEN OTHERS THEN
      v_error:= false;
      v_log.nom_proceso := 'PRG_INS_BA_ENV_CORREOS_HIS';
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
      DELETE FROM it.ba_env_correos a
      WHERE a.fec_insercion < pag_cal.fu_obt_fec_actual(1);
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        v_log.nom_proceso := 'PRG_INS_BA_ENV_CORREOS_HIS';
        v_log.fec_hor_ini := v_fec_hor_ini;
        v_log.fec_hor_fin := SYSDATE;
        v_log.nro_reg := 1;
        v_log.nro_error := SQLCODE;
        v_log.men_error := SQLERRM;
        v_log.comentario := 'Error al ejecutar el DELETE en la tabla BA_ENV_CORREOS.';
        PRT_INS_LOG(v_log, TRUE);
    END;
  END IF;
END;
