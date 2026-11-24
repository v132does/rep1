BEGIN
  sys.dbms_scheduler.create_job(job_name            => 'IT.PASE_A_HISTORICO',
                                job_type            => 'PLSQL_BLOCK',
                                job_action          => 'BEGIN IT.prg_ins_ge_log_errores_his; END;',
                                start_date          => to_date('10-04-2024 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),
                                repeat_interval     => 'FREQ=DAILY; BYHOUR=18; BYMINUTE=30',
                                end_date            => to_date(null),
                                job_class           => 'DEFAULT_JOB_CLASS',
                                enabled             => true,
                                auto_drop           => false,
                                comments            => 'Pase a histórico de ge_log_errores, registros mayores a un mes de antigüedad.');
END;
/