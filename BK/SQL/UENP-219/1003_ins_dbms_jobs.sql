begin
  sys.dbms_scheduler.create_job(job_name        => 'IT.JOB_UPD_DAT_OFE_CHE_ROG',
                                job_type        => 'PLSQL_BLOCK',
                                job_action      => 'begin
                                                  begin
                                                    pre_ini_aplicacion;
                                                    pae_cnf.g_cod_modulo := 1;
                                                  end;
                                                  if it.pae_cnf.fu_obt_est_modulo(6) = 2 then
                                                   it.prp_act_ofe_che_roga;
                                                  end if;
                                                 end;',
                                start_date      => systimestamp,
                                repeat_interval => 'Freq=Minutely;Interval=5',
                                end_date        => to_date(null),
                                job_class       => 'DEFAULT_JOB_CLASS',
                                enabled         => true,
                                auto_drop       => false,
                                comments        => 'Actualiza Datos de persona en Oferta Che Roga cada 5 minutos');
end;
/
BEGIN
  sys.DBMS_SCHEDULER.set_attribute( name      => 'IT.JOB_UPD_DAT_OFE_CHE_ROG',
                                    attribute => 'logging_level',
                                    value     => DBMS_SCHEDULER.logging_runs);

END;
