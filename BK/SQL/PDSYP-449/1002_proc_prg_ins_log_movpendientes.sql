-- Grants y Sinonimos para Procedimiento PRG_INS_LOG_MOVPENDIENTES
-- PDSYP-449: Log de movimientos pendientes
-- Create synonym for procedure
CREATE PUBLIC SYNONYM PRG_INS_LOG_MOVPENDIENTES FOR IT.PRG_INS_LOG_MOVPENDIENTES;

-- Grant procedure privileges
GRANT EXECUTE ON IT.PRG_INS_LOG_MOVPENDIENTES TO IT_TEMPORAL;

