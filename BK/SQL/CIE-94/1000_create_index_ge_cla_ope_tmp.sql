create index IT.IN_GCOPET_FECHA on IT.GE_CLA_OPERACIONES_TMP (FECHA)
  tablespace IT_IND
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 256K
    next 1M
    minextents 1
    maxextents unlimited
  );
