BEGIN
    DBMS_SCHEDULER.create_job (
        job_name        => 'IT.JOB_PAG_BOL',
        start_date      => SYSTIMESTAMP, 
        repeat_interval => 'FREQ=DAILY; BYDAY=MON,TUE,WED,THU,FRI; BYHOUR=8; BYMINUTE=0; BYSECOND=0',
        auto_drop       => FALSE,
        job_type        => 'PLSQL_BLOCK',
        enabled         => TRUE,
        comments        => 'GENERA DIFERENCIA SALDOS',
        job_action      => 
            q'[BEGIN
                    IT.PAG_BOL.pr_bus_dif_cuentas;
              END;]'
    );
END;
/
