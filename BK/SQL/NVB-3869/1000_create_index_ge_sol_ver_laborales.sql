create index IT.IN_GSVLA_COD_INF_LABORAL on IT.GE_SOL_VER_LABORALES (COD_PERSONA, COD_INF_LABORAL) ONLINE
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
create index IT.IN_GSVLA_COD_PERSONA on IT.GE_SOL_VER_LABORALES (COD_PERSONA) ONLINE
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
create index IT.IN_GSVLA_COD_USU_VERIFICADOR on IT.GE_SOL_VER_LABORALES (COD_USU_VERIFICADOR) ONLINE
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
create index IT.IN_GSVLA_NRO_SOLICITUD on IT.GE_SOL_VER_LABORALES (NRO_SOLICITUD) ONLINE
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
