begin
  sys.dbms_scheduler.create_job(job_name            => 'IT.BAJ_PRE_APROBADOS',
                                job_type            => 'PLSQL_BLOCK',
                                job_action          => 'declare
                  v_fec_ult_mes     date;
                  BEGIN
                       IT.pag_cal.pr_obt_dat_calendar(3);
                       v_fec_ult_mes := pag_cal.G_ULT_DIA_MES_HABIL;               
                     IF pag_cal.fu_obt_fec_actual(3) = v_fec_ult_mes THEN                       
                       begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end;
                       IT.PRP_BAJ_PRE_APROBADOS;
                    END IF;
                 END;',
     
                                start_date          => to_date('27-05-2024 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),
                                repeat_interval     => 'FREQ=DAILY;BYHOUR=20;BYMINUTE=00',
                                end_date            => to_date(null),
                                job_class           => 'DEFAULT_JOB_CLASS',
                                enabled             => true,
                                auto_drop           => false,
                                comments            => 'BAJA MASIVA DE PRÉSTAMOS PRE-APROBADOS');
end;

