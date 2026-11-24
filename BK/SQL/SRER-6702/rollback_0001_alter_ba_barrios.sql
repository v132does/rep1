-- =============================================================================
-- Script  : rollback_0001_alter_ba_barrios.sql
-- Ticket  : FIELDESK-164963 / Barrios BCP
-- Revierte: 0001_alter_ba_barrios.sql
--
-- PREREQUISITO: ejecutar restore_ba_barrios_from_bkp.sql ANTES de este script.
--   El MODIFY de DESCRIPCION a VARCHAR2(40) falla si hay filas > 40 chars.
--   El BKP fue tomado cuando DESCRIPCION era VARCHAR2(40), por lo que restaurarlo
--   primero garantiza que todas las descripciones existentes sean <= 40 chars.
-- =============================================================================

-- Drop index antes de tocar la tabla
DROP INDEX IT.IN_BARR_REF_EXTERNA;

-- Drop columnas nuevas (el orden de DROP no importa)
ALTER TABLE IT.BA_BARRIOS
  DROP (ref_externa, des_bco_central, cod_tipo_zona);

-- Revertir ampliacion de DESCRIPCION
ALTER TABLE IT.BA_BARRIOS
  MODIFY (descripcion VARCHAR2(40));

-- Verificacion
SELECT column_name, data_type, data_length
FROM   all_tab_columns
WHERE  owner = 'IT' AND table_name = 'BA_BARRIOS'
  AND  column_name IN ('DESCRIPCION','REF_EXTERNA','DES_BCO_CENTRAL','COD_TIPO_ZONA')
ORDER  BY column_id;
-- Debe retornar solo DESCRIPCION con DATA_LENGTH=40; las otras tres no deben aparecer.
