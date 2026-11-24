-- ============================================================
-- Script: 8004-RB_BA_PROGRAMAS_nuevos_reportes.sql
-- Objetivo: Rollback de 7000-BA_PROGRAMAS_nuevos_reportes.sql
--           - DELETE 10 programas nuevos de BA_PROGRAMAS
-- ============================================================

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  COMMIT;
END;
/

DELETE FROM ba_programas
WHERE cod_programa IN (
    'BLBANEXT',
    'BLBANPAI',
    'BLRESGAR',
    'BLCASHCO',
    'BLHIPOTE',
    'BLPRENDA',
    'BLFOGAPY',
    'BLFOGAMU',
    'BLFOGAVI',
    'BLBONSUB'
);

COMMIT;
