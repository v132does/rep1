create index IT.IN_WMOVI_DATO on IT.BW_MOVIMIENTOS (DATO, DATO3)
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