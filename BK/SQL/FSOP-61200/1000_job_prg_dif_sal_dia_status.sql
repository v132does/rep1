BEGIN
	DBMS_SCHEDULER.create_job (
		job_name        => 'IT.JOB_PRG_DIF_SAL_DIA_STATUS',
		start_date 		=> SYSTIMESTAMP, 
		repeat_interval => 'FREQ=DAILY; BYDAY=MON,TUE,WED,THU,FRI; BYHOUR=12; BYMINUTE=0; BYSECOND=0',
		auto_drop       => FALSE,
		job_type        => 'PLSQL_BLOCK',
		enabled         => TRUE,
		comments		=> 'GENERA INFORMACION DIFERENCIA DE SALDOS DISPONIBLE',
		job_action      => 
			q'[	BEGIN
					IT.prg_dif_sal_dia_status;
				END;]'
	);
END;
/