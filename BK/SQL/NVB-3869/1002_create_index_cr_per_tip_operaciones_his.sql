
create index IT.IN_RPTOH_COD_PERSONA on IT.CR_PER_TIP_OPERACIONES_HIS (COD_PERSONA) ONLINE
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
