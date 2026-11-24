-- Create/Recreate indexes 
CREATE INDEX IT.IN_PCUOT_NRO_CUENTA ON IT.PR_CUOTAS (NRO_CUENTA, NRO_CUOTA, ESTADO) online
 tablespace IT_IND
 pctfree 10
 initrans 2
 maxtrans 255
 storage
 (
  initial 64K
  next 1M
  minextents 1
  maxextents unlimited
 );


