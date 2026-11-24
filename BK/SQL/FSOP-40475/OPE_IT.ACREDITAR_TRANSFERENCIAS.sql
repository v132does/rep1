begin
  sys.dbms_scheduler.create_job(job_name            => 'OPE_IT.ACREDITAR_TRANSFERENCIAS',
                                job_type            => 'PLSQL_BLOCK',
                                job_action          => 'begin
          begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
          it.prs_spi_acre_transferencias;
        end;',
                               start_date          => to_date('14-10-2024 09:00:00', 'dd-mm-yyyy hh24:mi:ss'),
                                repeat_interval     => 'Freq=DAILY;ByDay=Mon, Tue, Wed, Thu, Fri, Sat;ByHour=6',
                                end_date            => to_date(null),
                                job_class           => 'DEFAULT_JOB_CLASS',
                                enabled             => true,
                                auto_drop           => false,
                                comments            => 'Ejecuta procedimiento que se encarga de acreditrar transferencias recibidas, que quedan en RA, se tienen pacs.002 de respuesta AUTH, y también confirmacion ACSP, por parte de BCP');
end;
