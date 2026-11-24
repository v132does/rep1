BEGIN
    DBMS_SCHEDULER.create_job (
        job_name        => 'IT.JOB_GEN_INVENTARIOS',
        start_date      => SYSTIMESTAMP, 
        repeat_interval => 'FREQ=DAILY; BYDAY=MON,TUE,WED,THU,FRI,SAT,SUN; BYHOUR=7; BYMINUTE=0; BYSECOND=0',
        auto_drop       => FALSE,
        job_type        => 'PLSQL_BLOCK',
        enabled         => TRUE,
        comments        => 'GENERA INVENTARIOS',
        job_action      => 
            q'[BEGIN
                    IT.PRG_GEN_INVENTARIOS;
              END;]'
    );
END;
/

