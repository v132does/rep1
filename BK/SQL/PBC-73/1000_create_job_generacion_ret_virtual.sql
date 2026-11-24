begin
  sys.dbms_scheduler.create_job(job_name            => 'IT.GENERACION_RET_VIRTUAL',
                                job_type            => 'PLSQL_BLOCK',
                                job_action          => 'begin
            IF pag_cal.fu_obt_fec_actual(1) = pag_cal.FU_OBT_FEC_HABIL(trunc(sysdate), 1,FUG_OBT_OFI_MATRIZ) and pae_cnf.fu_obt_est_modulo(1) != 4 then                              begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end;
            IT.PRK_GEN_RET_VIRTUAL;
            END IF;
            end;',
     
                                start_date          => to_date('29-05-2024 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),
                                repeat_interval     => 'Freq=Daily;Interval=1;ByDay=Mon, Tue, Wed, Thu, Fri;ByHour=10;BYMINUTE=00',
                                end_date            => to_date(null),
                                job_class           => 'DEFAULT_JOB_CLASS',
                                enabled             => true,
                                auto_drop           => false,
                                comments            => 'Generación de Retención Virtual del día anterior. Intenta generar una vez por día a las 10:00 hs.');
end;

