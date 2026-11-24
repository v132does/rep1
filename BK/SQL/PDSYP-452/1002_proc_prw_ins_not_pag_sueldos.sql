-- Grants y Sinonimos para Procedimiento PRW_INS_NOT_PAG_SUELDOS
-- PDSYP-452: Notificaciones de pagos
-- Create synonym for procedure
CREATE PUBLIC SYNONYM PRW_INS_NOT_PAG_SUELDOS FOR IT.PRW_INS_NOT_PAG_SUELDOS;

-- Grant procedure privileges
GRANT EXECUTE ON IT.PRW_INS_NOT_PAG_SUELDOS TO IT_TEMPORAL;