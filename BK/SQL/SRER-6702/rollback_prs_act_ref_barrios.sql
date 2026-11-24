-- =============================================================================
-- Script  : rollback_prs_act_ref_barrios.sql
-- Ticket  : FIELDESK-164963 / Barrios BCP
-- Revierte: prs_act_ref_barrios.prc (el objeto compilado en la BD)
--
-- NOTA: Este script solo elimina el OBJETO del procedimiento.
--       Para revertir los DATOS que insertó/actualizó en BA_BARRIOS,
--       ejecutar restore_ba_barrios_from_bkp.sql.
-- =============================================================================

DROP PROCEDURE IT.PRS_ACT_REF_BARRIOS;

-- Verificacion: debe retornar 0
SELECT COUNT(*) AS proc_existe
FROM   all_objects
WHERE  owner = 'IT'
  AND  object_name = 'PRS_ACT_REF_BARRIOS'
  AND  object_type = 'PROCEDURE';
