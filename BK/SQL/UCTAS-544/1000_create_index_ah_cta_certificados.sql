create index IT.IN_AHCER_SER_TITULO on IT.AH_CTA_CERTIFICADOS (SER_TITULO, NRO_TITULO) ONLINE
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

create index IT.IN_AHCER_NRO_CTA_CREDITO on IT.AH_CTA_CERTIFICADOS (NRO_CTA_CREDITO) ONLINE
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

create index IT.IN_AHCER_NRO_CTA_RENOVADA on IT.AH_CTA_CERTIFICADOS (NRO_CTA_RENOVADA) ONLINE
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

create index IT.IN_AHCER_COD_MONEDA on IT.AH_CTA_CERTIFICADOS (COD_MONEDA) ONLINE
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

create index IT.IN_AHCER_COD_OFICINA on IT.AH_CTA_CERTIFICADOS (COD_OFICINA) ONLINE
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

create index IT.IN_AHCER_COD_USU_PROMOTOR on IT.AH_CTA_CERTIFICADOS (COD_USU_PROMOTOR) ONLINE
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

create index IT.IN_AHCER_COD_CANAL on IT.AH_CTA_CERTIFICADOS (COD_CANAL) ONLINE
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

create index IT.IN_AHCER_COD_CAU_CANCELACION on IT.AH_CTA_CERTIFICADOS (COD_CAU_CANCELACION) ONLINE
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

create index IT.IN_AHCER_COD_MODULO_01 on IT.AH_CTA_CERTIFICADOS (COD_MODULO, COD_MODALIDAD, ESTADO) ONLINE
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
  
create index IT.IN_AHCER_COD_MODULO_02 on IT.AH_CTA_CERTIFICADOS (COD_MODULO, COD_MODALIDAD, EST_BATCH) ONLINE
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

create index IT.IN_AHCER_COD_TASA on IT.AH_CTA_CERTIFICADOS (COD_TASA) ONLINE
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
