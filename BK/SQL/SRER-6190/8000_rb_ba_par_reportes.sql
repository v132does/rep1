-- ============================================================
-- Script: 8000-RB_BA_PAR_REPORTES.sql
-- Objetivo: Rollback de 7004-BA_PAR_REPORTES.sql
--           - DELETE filas insertadas: BLANPLSO/ANEXO, BLPLASOL/FEC, BLREPAEF/FEC
--           - UPDATE VAL_DEFECTO de BLANPLSO/FEC y BLMTOCON/FEC a valores previos
-- ADVERTENCIA: Los valores restaurados por los UPDATEs corresponden a los valores
--              previos al deploy. Si el valor fue modificado manualmente
--              en algún ambiente antes del rollback, este script lo sobreescribirá.
--              Verificar manualmente el valor actual antes de ejecutar.
-- ============================================================

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  COMMIT;
END;
/

-- Deshacer INSERTs
DELETE FROM ba_par_reportes
WHERE cod_programa = 'BLANPLSO' AND cod_campo = 'ANEXO';

DELETE FROM ba_par_reportes
WHERE cod_programa = 'BLPLASOL' AND cod_campo = 'FEC';

DELETE FROM ba_par_reportes
WHERE cod_programa = 'BLREPAEF' AND cod_campo = 'FEC';

-- Deshacer UPDATEs (restaurar función de fecha anterior)
UPDATE ba_par_reportes
SET val_defecto = 'select ''Igual_a ''||chr(39)||to_char(pag_cal.fu_obt_fec_actual(2),''dd/mm/yyyy'')||chr(39) from dual'
WHERE cod_programa = 'BLANPLSO'
  AND cod_campo    = 'FEC';

UPDATE ba_par_reportes
SET val_defecto = 'select ''Igual_a ''||chr(39)||to_char(pag_cal.fu_obt_fec_actual(2),''dd/mm/yyyy'')||chr(39) from dual'
WHERE cod_programa = 'BLMTOCON'
  AND cod_campo    = 'FEC';

COMMIT;
