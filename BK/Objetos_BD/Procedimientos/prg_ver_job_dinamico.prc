CREATE OR REPLACE PROCEDURE IT.prg_ver_job_dinamico (
  p_pref_job     IN VARCHAR2,
  p_err_out      OUT VARCHAR2 
) AS
v_status         user_scheduler_job_run_details.status%TYPE;
v_job_encontrado user_scheduler_job_run_details.job_name%TYPE;
v_err_msg        VARCHAR2(4000);
v_dur_raw        INTERVAL DAY(3) TO SECOND(2);
v_dur_fmt        VARCHAR2(100);
v_fec_actual     date := pag_cal.FU_OBT_FEC_ACTUAL(1);
v_job_activo     NUMBER;

BEGIN
  p_err_out := NULL;
  
  -- 1. Verificación de ejecución activa
  SELECT COUNT(1) INTO v_job_activo
    FROM dba_scheduler_running_jobs
   WHERE job_name LIKE TRIM(p_pref_job) || '%'
     AND ROWNUM = 1;

  IF v_job_activo > 0 THEN
    p_err_out := 'El Job ' || p_pref_job || ' todavía se encuentra en EJECUCIÓN.';
    pag_cie.PR_INS_LOG(p_err_out, pag_cie.c_log_INFO, 'AUTONOMOUS_TRANSACTION');
    RETURN; --Si se encuentra activo, lo registra y sale
  END IF;

  -- 2. Búsqueda en históricos (Independiente de si el Job existe o no)
  BEGIN
    SELECT status, additional_info, (log_date - actual_start_date), job_name
      INTO v_status, v_err_msg, v_dur_raw, v_job_encontrado
      FROM (
          SELECT status, additional_info, log_date, actual_start_date, job_name
            FROM user_scheduler_job_run_details
           WHERE job_name LIKE TRIM(p_pref_job) || '%'
             AND session_id IS NOT NULL
             AND CAST(log_date AS DATE) >= v_fec_actual
           ORDER BY log_date DESC 
      )
     WHERE ROWNUM = 1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_err_out := 'No se halló ejecución para ' || p_pref_job;
      pag_cie.PR_INS_LOG('ERROR: ' || p_err_out, pag_cie.c_log_ERROR, 'AUTONOMOUS_TRANSACTION');
      RETURN;
  END;

  -- 3. Formateo de duración (HH:MI:SS)
  v_dur_fmt := LPAD(EXTRACT(HOUR FROM v_dur_raw), 2, '0')   || ':' || 
               LPAD(EXTRACT(MINUTE FROM v_dur_raw), 2, '0') || ':' || 
               LPAD(ROUND(EXTRACT(SECOND FROM v_dur_raw)), 2, '0');

  -- 4. Registro de resultados
  IF v_status = 'SUCCEEDED' THEN
    pag_cie.PR_INS_LOG('Job ' || v_job_encontrado || ' finalizó OK. Tiempo: ' || v_dur_fmt, pag_cie.c_log_INFO, 'AUTONOMOUS_TRANSACTION');
  ELSIF v_status = 'FAILED' THEN
    p_err_out := 'Job ' || v_job_encontrado || ' falló. Tiempo: ' || v_dur_fmt || '. Detalle: ' || SUBSTR(v_err_msg, 1, 150);
    pag_cie.PR_INS_LOG(p_err_out, pag_cie.c_log_ERROR, 'AUTONOMOUS_TRANSACTION');
  ELSE
    p_err_out := 'Job ' || v_job_encontrado || ' con estado inesperado: ' || v_status || ' (' || v_dur_fmt || ')';
    pag_cie.PR_INS_LOG(p_err_out, pag_cie.c_log_WARN, 'AUTONOMOUS_TRANSACTION');
  END IF;

EXCEPTION
    WHEN OTHERS THEN
      p_err_out := 'Error sistémico en ' || p_pref_job || ': ' || SQLERRM;
      pag_cie.PR_INS_LOG(p_err_out, pag_cie.c_log_FATAL, 'AUTONOMOUS_TRANSACTION');
END prg_ver_job_dinamico;
/
