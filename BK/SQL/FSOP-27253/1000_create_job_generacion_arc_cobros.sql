begin
  sys.dbms_scheduler.create_job(job_name            => 'IT.GENERACION_ARC_COBROS',
                                job_type            => 'PLSQL_BLOCK',
                                job_action          => 'begin
           if pag_cal.fu_obt_fec_actual(1) != trunc(sysdate) and pae_cnf.fu_obt_est_modulo(1) = 4 then
            begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end;
            it.prg_ctr_pro_previos(12);
            it.prg_gen_arc_cobros(pag_cal.fu_obt_fec_actual(1),''N'');
          elsif pag_cal.fu_obt_fec_actual(1) = trunc(sysdate) and pae_cnf.fu_obt_est_modulo(1) != 4 then
            begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end;
            it.prg_gen_arc_cobros;
          end if;
        end;',
                                start_date          => to_date('25-03-2024 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),
                                repeat_interval     => 'Freq=Daily;Interval=1;ByDay=Tue, Wed, Thu, Fri, Sat;ByHour=02,03,04,05,06,07,08,09,10,11,12;ByMinute=40',
                                end_date            => to_date(null),
                                job_class           => 'DEFAULT_JOB_CLASS',
                                enabled             => true,
                                auto_drop           => false,
                                comments            => 'Generación de archivos completos de cobro del día anterior. Intenta generar de Martes a sábado de 2.40 a 12.40hs. Controla generar una vez por día');
end;
