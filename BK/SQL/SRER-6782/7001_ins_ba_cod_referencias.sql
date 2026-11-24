------------------------------
-- 3-- insert ba_cod_referencias --
------------------------------

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
END;
/


INSERT INTO ba_cod_referencias (
  DOMINIO,
  SIGNIFICADO,
  VAL_MINIMO,
  VAL_MAXIMO,
  ABREVIATURA,
  ACTIVO)
VALUES (
  'MES_PRO_MODALIDAD',              -- dominio
  'PRESTAMOS REC. AFD IVA 10%',     -- significado
  '155',                            -- modalidad 155
  '50000000',                       -- val_maximo
  'MMCTAPRE',                       -- abreviatura
  'S'                               -- activo
);
COMMIT;
