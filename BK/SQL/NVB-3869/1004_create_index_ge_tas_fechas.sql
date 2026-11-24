
create index IT.IN_GTFEC_COD_MODALIDAD on IT.GE_TAS_FECHAS (COD_MODULO, COD_MODALIDAD) ONLINE
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
create index IT.IN_GTFEC_COD_MONEDA on IT.GE_TAS_FECHAS (COD_MONEDA) ONLINE
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
create index IT.IN_GTFEC_COD_OFICINA on IT.GE_TAS_FECHAS (COD_OFICINA) ONLINE
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
create index IT.IN_GTFEC_COD_PERSONA on IT.GE_TAS_FECHAS (COD_PERSONA) ONLINE
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
create index IT.IN_GTFEC_COD_TASA on IT.GE_TAS_FECHAS (COD_TASA) ONLINE
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
