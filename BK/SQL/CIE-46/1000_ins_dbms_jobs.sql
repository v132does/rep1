BEGIN
  SYS.DBMS_SCHEDULER.create_job(
    job_name            => 'IT."GENERA_DATOS_TARJETAS"',
    job_type            => 'PLSQL_BLOCK',
    job_action          => '
      declare
		  v_ind_cierre varchar2(1) := it.fuc_obt_est_env_fac_ele;
	  begin
		if v_ind_cierre = "N" then
		  BEGIN
			 PRE_INI_APLICACION;
			 PAE_CNF.G_COD_MODULO := 1;
		  END;
		  IT.PRG_PRO_DAT_TARJETAS;
		  COMMIT;
		end if;
	  end;
    ',
    start_date          => TO_DATE('22-11-2024 18:00:00', 'DD-MM-YYYY HH24:MI:SS'), -- Fecha de inicio
    repeat_interval     => 'FREQ=DAILY;BYHOUR=18;BYMINUTE=0;BYSECOND=0;BYDAY=MON,TUE,WED,THU,FRI',
    end_date            => NULL,
    job_class           => 'DEFAULT_JOB_CLASS',
    enabled             => TRUE,
    auto_drop           => FALSE,
    comments            => 'Inserta datos a ge_cla_operaciones_tmp de las operaciones de Tarjetas'
  );
END;
