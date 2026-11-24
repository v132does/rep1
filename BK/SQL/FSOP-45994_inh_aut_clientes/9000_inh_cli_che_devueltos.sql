begin
  sys.dbms_scheduler.create_job(job_name            => 'IT.INH_CLI_CHE_DEVUELTOS',
                                job_type            => 'PLSQL_BLOCK',
                                job_action          => 'Begin 
    pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
    prc_inh_cli_che_devueltos;
  end;',
                                start_date          => to_date('14-02-2025 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),
                                repeat_interval     => 'Freq=Daily;Interval=1;ByDay=Mon, Tue, Wed, Thu, Fri;ByHour=08;ByMinute=00;BySecond=00',
                                end_date            => to_date(null),
                                job_class           => 'DEFAULT_JOB_CLASS',
                                enabled             => true,
                                auto_drop           => false,
                                comments            => 'Inhibiciones a clientes que tuvieron X cantidad de cheques devueltos para que no puedan operar en el sistema.');
end;
/
