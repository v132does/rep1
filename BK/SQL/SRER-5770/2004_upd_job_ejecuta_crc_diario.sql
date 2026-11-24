-- SRER-5770 | JOB_EJECUTA_CRC_DIARIO
-- Cambios: solo configuracion - JOB_PRIORITY=1
-- No se modifica el job_action (wrapper ya correcto desde SRER-2221)
-- Ref: NOR-655
BEGIN
  DBMS_SCHEDULER.DISABLE(
    name  => 'IT.JOB_EJECUTA_CRC_DIARIO',
    force => FALSE
  );
END;
/

BEGIN
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'IT.JOB_EJECUTA_CRC_DIARIO',
    attribute => 'job_priority',
    value     => 1
  );

  DBMS_SCHEDULER.ENABLE(
    name => 'IT.JOB_EJECUTA_CRC_DIARIO'
  );
END;
/
