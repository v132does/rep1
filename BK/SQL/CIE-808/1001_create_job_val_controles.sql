BEGIN
  sys.dbms_scheduler.create_job(
    job_name        => 'IT.JOB_VAL_CONTROLES',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'begin
                          if NVL(fug_obt_pardinamico(''PRG_VAL_CONTROLES''), ''N'') = ''S'' 
                             and pag_cal.fu_obt_fec_actual(1) = pag_cal.fu_obt_fec_habil(trunc(sysdate), 1, fug_obt_ofi_matriz) 
                             and pae_cnf.fu_obt_est_modulo(1) != 4 then                              
                             
                             begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
                             it.PRG_VAL_CONTROLES;
                             
                          end if;
                        end;',
    repeat_interval => 'Freq=Daily;Interval=1;ByHour=18;ByMinute=00',
    end_date        => to_date(null),
    job_class       => 'DEFAULT_JOB_CLASS',
    enabled         => true,
    auto_drop       => false,
    comments        => 'Controles previos al cierre operativo.'
  );
END;
