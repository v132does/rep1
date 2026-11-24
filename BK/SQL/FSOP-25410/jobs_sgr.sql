begin
  sys.dbms_scheduler.create_job(
    job_name            => 'IT."GENERAR_MOV_SGR"',
    job_type            => 'PLSQL_BLOCK',
    job_action          => 'begin PRG_GEN_MOV_SGR(null, null); end;',
    start_date          => to_date('04-03-2024 03:00:00', 'dd-mm-yyyy hh24:mi:ss'),
    repeat_interval     => 'Freq=Daily; BYDAY=MON,TUE,WED,THU,FRI',
    end_date            => to_date(null),
    job_class           => 'DEFAULT_JOB_CLASS',
    enabled             => true,
    auto_drop           => false,
    comments            => 'Genera registros en la tabla LD_INT_MOVIMIENTOS en un intervalo de Lunes a Viernes');
end;