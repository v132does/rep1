BEGIN
	DBMS_SCHEDULER.create_job (
		job_name        => 'IT.JOB_GEN_BCP_TRANSFERENCIAS',
		start_date 		=> SYSTIMESTAMP, 
		repeat_interval => 'FREQ=DAILY; BYDAY=MON,TUE,WED,THU,FRI; BYHOUR=8; BYMINUTE=0; BYSECOND=0',
		auto_drop       => FALSE,
		job_type        => 'PLSQL_BLOCK',
		enabled         => FALSE,
		comments		=> 'GENERA ARCHIVOS DE REPORTES DE TRANSFERENCIAS BCP',
		job_action      => 
			q'[	BEGIN
					pre_ini_aplicacion; 
                    pae_cnf.G_COD_MODULO:=1;
					IT.PRB_GEN_BCP_TRANSFERENCIAS;
				END;]'
	);
END;