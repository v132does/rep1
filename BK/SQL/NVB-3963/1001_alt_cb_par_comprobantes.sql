
-- Create/Recreate indexes 
create index IT.IN_CB_TIM_OFI_TIP on IT.CB_PAR_COMPROBANTES (NRO_TIMBRADO, COD_OFICINA, TIPO)
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
