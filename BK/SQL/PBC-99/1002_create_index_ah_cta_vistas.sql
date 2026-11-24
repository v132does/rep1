create index IT.IN_FEC_ESTADO on AH_CTA_VISTAS (FEC_APERTURA, ESTADO)
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
