BEGIN
   DBMS_SCHEDULER.CREATE_JOB (
      job_name => '"IT"."JOB_EXT_MENSUAL"',
      job_type => 'PLSQL_BLOCK',
      job_action =>
q'~
DECLARE
   v_cant               NUMBER;
   v_pri_dia_mes_habil  DATE;
BEGIN
   IT.PAG_EXT.PR_SET_PARAMETROS;
   v_pri_dia_mes_habil := IT.PAG_EXT.vg_ult_pri_dia_mes_habil;

   PRG_INS_LOG_PROGRAMAS('JOB_EXT_MENSUAL', 'Inicio...');

   SELECT count(1)
   INTO v_cant
   FROM ge_ext_intervalos
   WHERE pri_dia_mes_habil = v_pri_dia_mes_habil
     AND ROWNUM <= 1;

   IF v_cant = 0 THEN
      IT.PAG_EXT.PR_INT_GENERAR(v_pri_dia_mes_habil);
   END IF;

   IT.PAG_EXT.GEN_EXT_MONITOR('IT.PAG_EXT.PR_INT_PROCESAR');

   PRG_INS_LOG_PROGRAMAS('JOB_EXT_MENSUAL', 'Fin Ok');
EXCEPTION
   WHEN OTHERS THEN
      PRG_INS_LOG_PROGRAMAS('JOB_EXT_MENSUAL', 'EXCEPTION | '||SQLERRM);
      RAISE;
END;
~',
      number_of_arguments => 0,
      start_date => NULL,
      repeat_interval => NULL,
      end_date => NULL,
      enabled => FALSE,
      auto_drop => FALSE,
      comments => 'GENERACIÓN DE EXTRACTOS MENSUAL'
   );

   DBMS_SCHEDULER.SET_ATTRIBUTE (
      name      => '"IT"."JOB_EXT_MENSUAL"',
      attribute => 'store_output',
      value     => TRUE
   );
   DBMS_SCHEDULER.SET_ATTRIBUTE (
      name      => '"IT"."JOB_EXT_MENSUAL"',
      attribute => 'logging_level',
      value     => DBMS_SCHEDULER.LOGGING_OFF
   );
   DBMS_SCHEDULER.SET_ATTRIBUTE (
      name      => '"IT"."JOB_EXT_MENSUAL"', 
      attribute => 'raise_events',
      value     => '1'
   );
   DBMS_SCHEDULER.SET_ATTRIBUTE ( 
      name      => '"IT"."JOB_EXT_MENSUAL"', 
      attribute => 'max_run_duration',
      value     => to_dsinterval('+01 00:00:00.000000')
   );
END;