-- =============================================================================
-- Script      : 1000_alter_ba_barrios_cod_departamento.sql
-- Ticket      : SRER-7088
-- Objeto      : IT.BA_BARRIOS
-- Descripcion : Agrega los datos de relacion BCP necesarios en BA_BARRIOS:
--               - COD_DEPARTAMENTO
--               - COD_CIUDAD_BCP
--               - DESC_CIUDAD_BCP
--
-- COD_DEPARTAMENTO conserva la codificacion utilizada actualmente por
-- BA_CIUDADES para Paraguay. Caso especial: Capital BCP 00 -> 18.
-- EXTERIOR no posee departamento y queda NULL.
-- =============================================================================

ALTER TABLE IT.BA_BARRIOS
  ADD ( COD_DEPARTAMENTO NUMBER(3),
        COD_CIUDAD_BCP   VARCHAR2(4),
        DESC_CIUDAD_BCP  VARCHAR2(60) );

COMMENT ON COLUMN IT.BA_BARRIOS.COD_DEPARTAMENTO
  IS 'Codigo de departamento asociado al dato BCP segun codificacion usada por BA_CIUDADES. Capital BCP 00 se persiste como 18; Exterior queda nulo.';

COMMENT ON COLUMN IT.BA_BARRIOS.COD_CIUDAD_BCP
  IS 'Codigo de ciudad BCP zero-padded (ej: 0101), informado en BARRIOS_BCP.CSV.';

COMMENT ON COLUMN IT.BA_BARRIOS.DESC_CIUDAD_BCP
  IS 'Descripcion de ciudad segun catalogo BCP informada en BARRIOS_BCP.CSV.';

SELECT COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
  FROM ALL_TAB_COLUMNS
 WHERE OWNER = 'IT'
   AND TABLE_NAME = 'BA_BARRIOS'
   AND COLUMN_NAME IN ('COD_DEPARTAMENTO', 'COD_CIUDAD_BCP', 'DESC_CIUDAD_BCP')
 ORDER BY COLUMN_ID;
