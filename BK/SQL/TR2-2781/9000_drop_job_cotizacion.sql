BEGIN
  DBMS_SCHEDULER.DROP_JOB(
    job_name => 'IT.ALT_GLP_COTIZACION',
    force    => TRUE
  );
END;
