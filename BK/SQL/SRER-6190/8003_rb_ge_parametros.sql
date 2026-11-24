-- ============================================================
-- Script: 8003-RB_GE_PARAMETROS_PATH_XLSX_SOLVENCIA.sql
-- Objetivo: Rollback de 7001-GE_PARAMETROS_PATH_XLSX_SOLVENCIA.sql
--           - DELETE parametro PATH_XLSX_SOLVENCIA de GE_PARAMETROS
-- ============================================================

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  COMMIT;
END;
/

DELETE FROM ge_parametros
WHERE parametro = 'PATH_XLSX_SOLVENCIA';

COMMIT;
