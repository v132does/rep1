BEGIN
	DBMS_SCHEDULER.create_job (
		job_name        => 'IT.JOB_EJE_PRO_FIN_DIA_CONTABLE',
        start_date      => NULL,
        repeat_interval => NULL,
		auto_drop       => FALSE,
		job_type        => 'STORED_PROCEDURE',
		enabled         => FALSE,
		comments		=> 'EJECUTA EL PROCESO DE FIN DE DIA CONTABLE (320)',
		job_action      => 'PRB_EJE_PRO_320_AUTOMATICO'
	);
    
END;