BEGIN
  DBMS_SCHEDULER.create_job (
    job_name        => 'JOB_ARC_PRE_CIERRE',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN
                            begin pre_ini_aplicacion; 
                            pae_cnf.G_COD_MODULO:=1; end; 
                            IT.PRB_GEN_PRE_CIERRE; 
                        END;',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY; BYHOUR=07; BYMINUTE=00; BYSECOND=0; BYDAY=MON,TUE,WED,THU,FRI',
    end_date            => to_date(null),
    job_class           => 'DEFAULT_JOB_CLASS',
    enabled             => TRUE,
    auto_drop           => false,
    comments            => 'GENERA ARCHIVOS DEL PRE  CIERRE');
END;
/
