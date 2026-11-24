-- =============================================================================
-- Script  : rollback_0005_update_comment_sb_cf_pro_log.sql
-- Ticket  : FIELDESK-164963 / Barrios BCP
-- Revierte: 0005_update_comment_sb_cf_pro_log.sql
-- =============================================================================

-- Revertir al comment previo (sin 'ACT_BARRIOS')
COMMENT ON TABLE IT.SB_CF_PRO_LOG IS
  'Log de ejecuciones BCP: CF_ALTA (Circ. SB.SG 00586/2010), CAR_PERSONAS (PRS_CAR_PERSONAS_REF), ACT_CIUDADES (PRS_ACT_REF_CIUDADES)';
