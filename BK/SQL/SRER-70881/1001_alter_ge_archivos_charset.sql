-- =============================================================================
-- Script      : 1001_alter_ge_archivos_charset.sql
-- Ticket      : SRER-7088
-- Objeto      : IT.GE_ARCHIVOS
-- Descripcion : Agrega el charset configurable para archivos importados.
-- Nota        : Los valores se cargan en 7001_upd_ge_archivos_charset.sql.
-- =============================================================================

ALTER TABLE IT.GE_ARCHIVOS ADD CHARSET_ARCHIVO VARCHAR2(30);

COMMENT ON COLUMN IT.GE_ARCHIVOS.CHARSET_ARCHIVO
  IS 'Charset del archivo de entrada para sqlldr (ej: WE8MSWIN1252). Null = sin especificar (usa NLS_LANG del cliente).';

SELECT COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
  FROM ALL_TAB_COLUMNS
 WHERE OWNER = 'IT'
   AND TABLE_NAME = 'GE_ARCHIVOS'
   AND COLUMN_NAME = 'CHARSET_ARCHIVO';
