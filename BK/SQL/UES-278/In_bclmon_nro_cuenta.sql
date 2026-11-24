create index IT.IN_BCLMON_NRO_CUENTA on IT.BW_CLA_LIM_MONTOS (NRO_CUENTA) online
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