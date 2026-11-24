BEGIN
  DBMS_SCHEDULER.CREATE_JOB (
    job_name           =>  'IT.JOB_PRA_CON_TRANSACCIONES',
    job_type           =>  'PLSQL_BLOCK',
    job_action         =>  'BEGIN
                              pre_ini_aplicacion;
                              pae_cnf.g_cod_modulo := 1;
                              PAE_CNF.G_PROGRAMA := ''GPPROFIN'';
                              IT.PRA_CON_TRANSACCION(''J'');
                            END;',
    start_date         =>  SYSTIMESTAMP,
    repeat_interval    =>  'FREQ=DAILY; BYHOUR=9,12,15,18; BYMINUTE=0; BYSECOND=0',
    enabled            =>  TRUE,
    comments           =>  'Job que procesa el consolidado de transacciones a las 9, 12, 15 y 18 hs.'
  );
END;
