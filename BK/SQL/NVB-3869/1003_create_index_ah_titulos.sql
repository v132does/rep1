
create index IT.IN_ATITU_COD_MONEDA on IT.AH_TITULOS (COD_MONEDA) ONLINE
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
create index IT.IN_ATITU_COD_PER_ENDOSADO on IT.AH_TITULOS (COD_PER_ENDOSADO) ONLINE
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
