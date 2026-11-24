-- ============================================================
-- Script: update_ba_par_reportes_findia.sql
-- Objetivo: Sincronizar ba_par_reportes en FINDIA
-- Tabla:    BA_PAR_REPORTES
-- Fecha:    2026-07-22
-- ============================================================

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  COMMIT;
END;
/

-- ============================================================
-- UPDATEs: registros que existen en ambos ambientes pero con
--          VAL_DEFECTO diferente
-- ============================================================

-- BLANPLSO / FEC
UPDATE ba_par_reportes
SET val_defecto = 'select ''Igual_a ''||chr(39)||to_char(TRUNC (PAG_CAL.FU_OBT_FEC_ANT_HAB(LAST_DAY(ADD_MONTHS(sysdate, -1)) + 1,2,1)),''dd/mm/yyyy'')||chr(39) FROM DUAL'
WHERE cod_programa = 'BLANPLSO'
  AND cod_campo    = 'FEC'
  AND val_defecto != 'select ''Igual_a ''||chr(39)||to_char(TRUNC (PAG_CAL.FU_OBT_FEC_ANT_HAB(LAST_DAY(ADD_MONTHS(sysdate, -1)) + 1,2,1)),''dd/mm/yyyy'')||chr(39) FROM DUAL';

-- BLMTOCON / FEC
UPDATE ba_par_reportes
SET val_defecto = 'select ''Igual_a ''||chr(39)||to_char(TRUNC (PAG_CAL.FU_OBT_FEC_ANT_HAB(LAST_DAY(ADD_MONTHS(sysdate, -1)) + 1,2,1)),''dd/mm/yyyy'')||chr(39) FROM DUAL'
WHERE cod_programa = 'BLMTOCON'
  AND cod_campo    = 'FEC'
  AND val_defecto != 'select ''Igual_a ''||chr(39)||to_char(TRUNC (PAG_CAL.FU_OBT_FEC_ANT_HAB(LAST_DAY(ADD_MONTHS(sysdate, -1)) + 1,2,1)),''dd/mm/yyyy'')||chr(39) FROM DUAL';

-- ============================================================
-- INSERTs: registros nuevos a insertar en FINDIA
-- ============================================================

-- BLANPLSO / ANEXO
INSERT INTO ba_par_reportes (cod_programa, cod_campo, alias, val_defecto)
SELECT 'BLANPLSO', 'ANEXO', NULL, '0-TODOS'
FROM dual
WHERE NOT EXISTS (
    SELECT 1 FROM ba_par_reportes
    WHERE cod_programa = 'BLANPLSO'
      AND cod_campo    = 'ANEXO'
);

-- BLPLASOL / FEC
INSERT INTO ba_par_reportes (cod_programa, cod_campo, alias, val_defecto)
SELECT 'BLPLASOL', 'FEC', 'C', 'select ''Igual_a ''||chr(39)||to_char(TRUNC (PAG_CAL.FU_OBT_FEC_ANT_HAB(LAST_DAY(ADD_MONTHS(sysdate, -1)) + 1,2,1)),''dd/mm/yyyy'')||chr(39) FROM DUAL'
FROM dual
WHERE NOT EXISTS (
    SELECT 1 FROM ba_par_reportes
    WHERE cod_programa = 'BLPLASOL'
      AND cod_campo    = 'FEC'
);

-- BLREPAEF / FEC
INSERT INTO ba_par_reportes (cod_programa, cod_campo, alias, val_defecto)
SELECT 'BLREPAEF', 'FEC', 'C', 'select ''Igual_a ''||chr(39)||to_char(TRUNC (PAG_CAL.FU_OBT_FEC_ANT_HAB(LAST_DAY(ADD_MONTHS(sysdate, -1)) + 1,2,1)),''dd/mm/yyyy'')||chr(39) FROM DUAL'
FROM dual
WHERE NOT EXISTS (
    SELECT 1 FROM ba_par_reportes
    WHERE cod_programa = 'BLREPAEF'
      AND cod_campo    = 'FEC'
);

COMMIT;
