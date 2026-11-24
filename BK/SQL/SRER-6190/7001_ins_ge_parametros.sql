-- ============================================================
-- Script: findia_GE_PARAMETROS_PATH_XLSX_SOLVENCIA.sql
-- Objetivo: INSERT de parametro PATH_XLSX_SOLVENCIA en FINDIA
-- Tabla:    GE_PARAMETROS
-- ============================================================

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  COMMIT;
END;
/

INSERT INTO ge_parametros
(
    parametro,
    descripcion,
    tab_relacion,
    referencia,
    observacion,
    pro_verificacion,
    permiso,
    modificable,
    val_defecto,
    usu_insercion,
    fec_insercion,
    usu_modificacion,
    fec_modificacion
)
SELECT
    'PATH_XLSX_SOLVENCIA',
    'Path XLSX de rep de solvencia',
    'GE_PAR_DINAMICOS',
    NULL,
    'Path base sugerido para la descarga de archivos XLSX de solvencia. Se concatena con el nombre del archivo.',
    NULL,
    NULL,
    'S',
    NULL,
    'IT',
    SYSDATE,
    'IT',
    SYSDATE
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1
    FROM ge_parametros
    WHERE parametro = 'PATH_XLSX_SOLVENCIA'
);

COMMIT;
