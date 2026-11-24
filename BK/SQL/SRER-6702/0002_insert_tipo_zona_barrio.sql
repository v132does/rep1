-- =============================================================================
-- Script  : 0002_insert_tipo_zona_barrio.sql
-- Ticket  : FIELDESK-164963 / Barrios BCP
-- Objeto  : IT.BA_COD_REFERENCIAS - dominio TIPO_ZONA_BARRIO
-- Autor   : Generado 2026-07-20
-- Descripcion:
--   Crea el dominio parametrizado para los tres tipos de zona que trae el
--   archivo BCP de barrios. BA_BARRIOS.COD_TIPO_ZONA (VARCHAR2(1)) almacena
--   el VAL_MINIMO; el procedimiento PRS_ACT_REF_BARRIOS resuelve el codigo
--   haciendo lookup por DOMINIO + UPPER(SIGNIFICADO).
--   Distribucion en muestra: Rural 5.666 / Urbana 2.230 / Sub Urbana 99.
-- Prerequisito: ejecutar despues de 0001_alter_ba_barrios.sql.
-- =============================================================================

BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:= 1; END;
/

-- ---------------------------------------------------------------------------
-- Dominio: TIPO_ZONA_BARRIO
-- PK: (DOMINIO, VAL_MINIMO)
-- ---------------------------------------------------------------------------
INSERT INTO IT.BA_COD_REFERENCIAS
  (DOMINIO, VAL_MINIMO, SIGNIFICADO, ABREVIATURA, ACTIVO)
VALUES
  ('TIPO_ZONA_BARRIO', 'U', 'Urbana', 'URB', 'S');

INSERT INTO IT.BA_COD_REFERENCIAS
  (DOMINIO, VAL_MINIMO, SIGNIFICADO, ABREVIATURA, ACTIVO)
VALUES
  ('TIPO_ZONA_BARRIO', 'R', 'Rural', 'RUR', 'S');

INSERT INTO IT.BA_COD_REFERENCIAS
  (DOMINIO, VAL_MINIMO, SIGNIFICADO, ABREVIATURA, ACTIVO)
VALUES
  ('TIPO_ZONA_BARRIO', 'S', 'Sub Urbana', 'SUB', 'S');

COMMIT;
