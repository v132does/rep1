-- SRER-5770 | JOB_EJECUTA_SIMULACION
-- Cambios: wrapper con EXCEPTION + LOGGING_LEVEL=FULL
-- Ref: NOR-655
BEGIN
  DBMS_SCHEDULER.DISABLE(
    name  => 'IT.JOB_EJECUTA_SIMULACION',
    force => FALSE
  );
END;
/

BEGIN
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'IT.JOB_EJECUTA_SIMULACION',
    attribute => 'job_action',
    value     => q'[
      BEGIN
        IT.PAG_SIM.PR_EJE_SIM();
      EXCEPTION
        WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(
            -20099,
            'SIMULACION FAILED | ' || SQLERRM || ' | ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
          );
      END;
    ]'
  );

  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'IT.JOB_EJECUTA_SIMULACION',
    attribute => 'logging_level',
    value     => DBMS_SCHEDULER.LOGGING_FULL
  );

  DBMS_SCHEDULER.ENABLE(
    name => 'IT.JOB_EJECUTA_SIMULACION'
  );
END;
/
