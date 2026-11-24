-- Grants y Sinonimos para Secuencia S_BW_LOG_MOVPENDIENTES
-- PDSYP-449: Log de movimientos pendientes
-- Create synonym for sequence
CREATE PUBLIC SYNONYM S_BW_LOG_MOVPENDIENTES FOR IT.S_BW_LOG_MOVPENDIENTES;

-- Grant sequence privileges
GRANT SELECT ON IT.S_BW_LOG_MOVPENDIENTES TO IT_TEMPORAL;

