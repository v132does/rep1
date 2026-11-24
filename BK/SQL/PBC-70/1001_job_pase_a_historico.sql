BEGIN
   DBMS_SCHEDULER.drop_job(job_name => 'IT.PASE_A_HISTORICO');
END;
/
BEGIN
  sys.dbms_scheduler.create_job(job_name            => 'IT.PASE_A_HISTORICO',
                                job_type            => 'PLSQL_BLOCK',
                                job_action          => q'[BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; IT.PRE_EJE_DEPURACION('S'); END;]',
                                start_date          => to_date('10-04-2024 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),
                                repeat_interval     => 'FREQ=DAILY; BYHOUR=04; BYMINUTE=00',
                                end_date            => to_date(null),
                                job_class           => 'DEFAULT_JOB_CLASS',
                                enabled             => true,
                                auto_drop           => false,
                                comments            => 'Pase a histórico de ge_log_errores, pr_auditorias, ah_auditorias, ge_auditorias, bw_auditorias, ge_snp_transferencias, ge_snp_mensajes, ba_log_mensajerias registros mayores a un mes de antigüedad.');
END;
/