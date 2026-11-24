------------------------------
-- 2-- insert ge_tas_fechas --
------------------------------

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 10;
END;
/


INSERT INTO ge_tas_fechas (
  COD_TASA,
  FEC_VIGENCIA,
  COD_MODULO,
  COD_MODALIDAD,
  VAL_BASE,
  VAL_TASA,
  APLICAR)
VALUES (
  343,                    -- misma tasa que 117 y 150 (IVA s/ intereses)
  '01/01/2026',           -- ej. TRUNC(SYSDATE)
  10,                     -- módulo préstamos
  155,                    -- código nueva modalidad
  0,                      -- VAL_BASE 
  10,                     -- VAL_TASA = 10%
  'IN'                    -- APLICAR
);
COMMIT;