-- Grants y Sinonimos para Secuencia S_BW_NOT_PAG_SUELDOS
-- PDSYP-452: Notificaciones de pagos Homebanking
-- Create synonym for sequence
CREATE PUBLIC SYNONYM S_BW_NOT_PAG_SUELDOS FOR IT.S_BW_NOT_PAG_SUELDOS;

-- Grant sequence privileges
GRANT SELECT ON IT.S_BW_NOT_PAG_SUELDOS TO IT_TEMPORAL;