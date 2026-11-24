-- Grants y Sinonimos para Tabla BW_NOT_PAG_SUELDOS
-- PDSYP-452: Notificaciones de pagos Homebanking
-- Create synonym for table
CREATE PUBLIC SYNONYM BW_NOT_PAG_SUELDOS FOR IT.BW_NOT_PAG_SUELDOS;

-- Grant table privileges
GRANT SELECT, INSERT, UPDATE, DELETE ON IT.BW_NOT_PAG_SUELDOS TO IT_TEMPORAL;