BEGIN
  DBMS_SCHEDULER.create_job (
    job_name        => 'IT.LCR_JOB_DIARIO',
    job_type        => 'STORED_PROCEDURE',
    job_action      => 'PAS_LCR.PR_PRO_GEN_LCR',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY; BYHOUR=7; BYMINUTE=0; BYSECOND=0',
    enabled         => TRUE,
    comments        => 'Job que ejecuta el procedimiento de LCR cada día'
  );
END;
/
