create index IT.IN_SSMEN_DOC_SITUACION on IT.SB_SNP_FLI (NRO_DOCUMENTO, SITUACION) ONLINE
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