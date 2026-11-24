
create index IT.IN_GEXOT_COD_MONEDA on IT.GE_EXONERACIONES_TMP (COD_MONEDA) ONLINE
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
create index IT.IN_GEXOT_COD_TASA on IT.GE_EXONERACIONES_TMP (COD_TASA) ONLINE
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
create index IT.IN_GEXOT_COD_TRANSACCION on IT.GE_EXONERACIONES_TMP (COD_TRANSACCION, COD_MODULO, COD_MODALIDAD) ONLINE
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
create index IT.IN_GEXOT_NRO_CUENTA on IT.GE_EXONERACIONES_TMP (NRO_CUENTA) ONLINE
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
