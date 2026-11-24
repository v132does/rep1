begin
  sys.dbms_scheduler.create_job(job_name            => 'IT.GENERACION_DATOS_MT940',
                                job_type            => 'PLSQL_BLOCK',
                                job_action          => 'BEGIN IT.PRC_GEN_EXT_MT940; END;',
                                start_date          => to_date('25-09-2024 12:00:00', 'dd-mm-yyyy hh24:mi:ss'),                                
                                repeat_interval     => 'Freq=Daily;Interval=1;ByDay=Mon, Tue, Wed, Thu, Fri;ByHour=20;ByMinute=30',
                                end_date            => to_date(null),
                                job_class           => 'DEFAULT_JOB_CLASS',
                                enabled             => true,
                                auto_drop           => false,
                                comments            => 'Genera datos para informe MT940.');
end;
/
