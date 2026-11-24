-- =============================================================================
-- FIELDESK-164963: Actualizar COMMENT ON TABLE IT.SB_CF_PRO_LOG
--                  para registrar el nuevo TIPO_PROCESO 'ACT_BARRIOS'
-- =============================================================================
COMMENT ON TABLE IT.SB_CF_PRO_LOG IS
  'Log de ejecuciones BCP: CF_ALTA (Circ. SB.SG 00586/2010), CAR_PERSONAS (PRS_CAR_PERSONAS_REF), ACT_CIUDADES (PRS_ACT_REF_CIUDADES), ACT_BARRIOS (PRS_ACT_REF_BARRIOS)';
