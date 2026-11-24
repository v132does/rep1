-- Grant/Revoke object privileges 
grant select, insert, update, delete on IT.GE_PROCESOS_DET_HIS to IT_TEMPORAL;
-- Sinonimo publico.
CREATE PUBLIC SYNONYM GE_PROCESOS_DET_HIS FOR IT.GE_PROCESOS_DET_HIS;
