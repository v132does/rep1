-- ============================================================
-- Script: 8001-RB_GE_FILTROS_ANEXO.sql
-- Objetivo: Rollback de 7003-GE_FILTROS_ANEXO.sql
--           - DELETE filtro ANEXO de GE_FILTROS
-- ============================================================

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  COMMIT;
END;
/

DELETE FROM ge_filtros
WHERE cod_campo = 'ANEXO';

COMMIT;
