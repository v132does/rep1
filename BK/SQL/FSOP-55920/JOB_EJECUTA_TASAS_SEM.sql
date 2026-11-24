BEGIN
  DBMS_SCHEDULER.CREATE_JOB (
    job_name            => '"IT"."JOB_EJECUTA_TASAS_SEM"',
    job_type            => 'PLSQL_BLOCK',
    job_action          => 'BEGIN IT.PAG_TAS.PRC_GEN_TAS_INT; END;',
    number_of_arguments => 0,
    start_date          => TO_TIMESTAMP_TZ('2025-05-15 17:00:33.075697000 -03:00', 'YYYY-MM-DD HH24:MI:SS.FF TZR'),
    repeat_interval     => 'FREQ=MINUTELY;INTERVAL=15;BYHOUR=0,1,2,3,4,5,6',
    end_date            => NULL,
    enabled             => FALSE,
    auto_drop           => FALSE,
    comments            => 'Ejecucion del reporte de tasas semanal cada 15 minutos en el intervalo 0-6am.'
  );

  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => '"IT"."JOB_EJECUTA_TASAS_SEM"', 
    attribute => 'store_output', 
    value     => TRUE
  );

  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => '"IT"."JOB_EJECUTA_TASAS_SEM"', 
    attribute => 'logging_level', 
    value     => DBMS_SCHEDULER.LOGGING_OFF
  );

  DBMS_SCHEDULER.ENABLE(
    name => '"IT"."JOB_EJECUTA_TASAS_SEM"'
  );
END;
/
