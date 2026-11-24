create index IT.IN_GECLIE_CATRIES on IT.ge_clientes (COD_PERSONA,  CAT_RIESGO)
 tablespace IT_DATA
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