create index IT.IN_CCMOVI_HIS_FEC_REFERENCIA on  it.CC_MOVIMIENTOS_HIS (FEC_VALOR, REFERENCIA)
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
