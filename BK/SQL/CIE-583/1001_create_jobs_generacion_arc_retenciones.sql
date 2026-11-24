begin
  sys.dbms_scheduler.create_job(job_name            => 'IT.GENERACION_ARC_RETENCIONES',
                                job_type            => 'PLSQL_BLOCK',
                                job_action          => 'begin
              IF pag_cal.fu_obt_fec_actual(1) = pag_cal.FU_OBT_FEC_HABIL(trunc(sysdate), 1,FUG_OBT_OFI_MATRIZ) and pae_cnf.fu_obt_est_modulo(1) != 4 then                              
              begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end;
              it.prg_gen_arc_retenciones;
              END IF;
              end;',
                                start_date          => to_date('02-01-2026 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),
                                repeat_interval     => 'Freq=Daily;Interval=1;ByHour=7;ByMinute=00',
                                end_date            => to_date(null),
                                job_class           => 'DEFAULT_JOB_CLASS',
                                enabled             => false,
                                auto_drop           => false,
                                comments            => 'Generación de Archivos de Retenciones del día anterior. Intenta generar una vez por día a las 07:00 hs.');
end;

