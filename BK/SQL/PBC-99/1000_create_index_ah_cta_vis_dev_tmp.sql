create index IT.IN_NRO_CUENTA_PROCESO_AH on AH_CTA_VIS_DEV_TMP (NRO_CUENTA, COD_PARALELO)
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
create index IT.IN_NRO_CUENTA_VISTA on AH_CTA_VIS_DEV_TMP (NRO_CUENTA)
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
