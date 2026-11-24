-- ============================================================
-- Script: 8002-RB_GE_PAR_DINAMICOS_PATH_XLSX_SOLVENCIA.sql
-- Objetivo: Rollback de 7002-GE_PAR_DINAMICOS_PATH_XLSX_SOLVENCIA.sql
--           - DELETE valor PATH_XLSX_SOLVENCIA de GE_PAR_DINAMICOS
-- ============================================================

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  COMMIT;
END;
/

DELETE FROM ge_par_dinamicos
WHERE parametro = 'PATH_XLSX_SOLVENCIA';

COMMIT;
