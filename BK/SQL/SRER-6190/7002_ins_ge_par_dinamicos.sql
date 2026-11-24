-- ============================================================
-- Script: findia_GE_PAR_DINAMICOS_PATH_XLSX_SOLVENCIA.sql
-- Objetivo: INSERT de parametro PATH_XLSX_SOLVENCIA en FINDIA
-- Tabla:    GE_PAR_DINAMICOS
-- ============================================================

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  COMMIT;
END;
/

INSERT INTO ge_par_dinamicos
(
    parametro,
    val_parametro,
    cod_modulo,
    cod_modalidad,
    cod_oficina,
    cod_moneda,
    cod_sub_modalidad,
    usu_insercion,
    fec_insercion,
    usu_modificacion,
    fec_modificacion
)
SELECT
    'PATH_XLSX_SOLVENCIA',
    -- NOTA: Esta ruta es local del usuario.
    'C:\Reportes\Solvencia',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    'IT',
    SYSDATE,
    'IT',
    SYSDATE
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1
    FROM ge_par_dinamicos
    WHERE parametro = 'PATH_XLSX_SOLVENCIA'
);

COMMIT;
