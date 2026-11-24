BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
            job_name => '"IT"."JOB_EXT_MAESTROS"',
            job_type => 'PLSQL_BLOCK',
            job_action => 'BEGIN
                              IT.PAG_EXT.PR_ACT_EXT_MAESTRAS();
                           END;',
            number_of_arguments => 0,
            start_date => NULL,
            repeat_interval => NULL,
            end_date => NULL,
            enabled => FALSE,
            auto_drop => FALSE,
            comments => 'ACTUALIZACION DE TABLAS MAESTRAS CON EXTRACTOS MENSUALES');
 
    DBMS_SCHEDULER.SET_ATTRIBUTE( 
             name => '"IT"."JOB_EXT_MAESTROS"', 
             attribute => 'store_output', value => TRUE);
    DBMS_SCHEDULER.SET_ATTRIBUTE( 
             name => '"IT"."JOB_EXT_MAESTROS"', 
             attribute => 'logging_level', value => DBMS_SCHEDULER.LOGGING_OFF);
    DBMS_SCHEDULER.SET_ATTRIBUTE( 
             name => '"IT"."JOB_EXT_MAESTROS"', 
             attribute => 'raise_events', value => '1');
        
    DBMS_SCHEDULER.SET_ATTRIBUTE( 
             name => '"IT"."JOB_EXT_MAESTROS"', 
             attribute => 'max_run_duration', value => to_dsinterval('+01 00:00:00.000000'));
    
END;