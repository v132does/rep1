create index IN_GSDIA_FECHA on GE_SAL_DIARIOS (FECHA) online
  tablespace IT_IND
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 16K
    next 8K
    minextents 1
    maxextents unlimited
  );
  
