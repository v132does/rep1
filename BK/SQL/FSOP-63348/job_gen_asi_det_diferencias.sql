BEGIN
	DBMS_SCHEDULER.create_job (
		job_name        => 'IT.JOB_GEN_ASI_DET_DIFERENCIAS',
		start_date 		=> SYSTIMESTAMP, 
		repeat_interval => 'FREQ=DAILY; BYDAY=TUE,WED,THU,FRI,SAT; BYHOUR=7; BYMINUTE=0; BYSECOND=0',
		auto_drop       => FALSE,
		job_type        => 'PLSQL_BLOCK',
		enabled         => TRUE,
		comments		=> 'GENERA ARCHIVOS DE DETALLE DE ASIENTOS CON DIFERENCIAS DIARIO',
		job_action      => 
			q'[	BEGIN
					pre_ini_aplicacion; 
                    pae_cnf.G_COD_MODULO:=1;
					it.PRB_GEN_ASI_DET_DIFERENCIAS(FUG_OBT_FEC_HABIL_ANT(TRUNC(SYSDATE)));
				END;]'
	);
END;