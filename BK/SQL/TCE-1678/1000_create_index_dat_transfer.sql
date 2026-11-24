create index IT.IN_GDTRA_NRO_REFERENCIA on IT.GE_DAT_TRANSFERENCIAS (NRO_REFERENCIA)
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