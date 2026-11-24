CREATE OR REPLACE PACKAGE IT.PAS_CF AS

  -- p_fecha_cierre: si se pasa, usa esa fecha en lugar de GE_CALENDARIOS.fec_anterior.
  -- Util para re-generar o forzar un lote de una fecha especifica sin tocar el calendario.
  -- Ejemplo: EXEC IT.PAS_CF.PR_GENERAR(DATE '2026-07-01');
  PROCEDURE PR_GENERAR(p_fecha_cierre IN DATE DEFAULT NULL);

  PROCEDURE PR_LIMPIAR_LOGS(p_dias_retener IN NUMBER DEFAULT 90);

END PAS_CF;
/
