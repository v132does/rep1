begin
  sys.dbms_scheduler.create_job(job_name            => 'IT.LIBERACION_EFECTIVO_TED',
                                job_type            => 'PLSQL_BLOCK',
                                job_action          => 'declare
      v_fec_inicial date := to_date(IT.FUE_OBT_FEC_CALENDAR(1));
      v_fec_final date := to_date(IT.FUE_OBT_FEC_CALENDAR(1));
    begin
      begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
      IT.PRA_LIB_RET_EFE;
      commit;
    end;',
                                start_date          => to_date('15-07-2026 15:00:00', 'dd-mm-yyyy hh24:mi:ss'),
                                repeat_interval     => 'Freq=DAILY;Interval=1',
                                end_date            => to_date(null),
                                job_class           => 'DEFAULT_JOB_CLASS',
                                enabled             => false,
                                auto_drop           => false,
                                comments            => '');
end;
/
