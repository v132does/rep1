alter table IT.TA_REF_MOVIMIENTOS_GP
  drop constraint PK_TA_REF_MOVIMIENTOS_GP;
alter table IT.TA_REF_MOVIMIENTOS_GP
  add constraint PK_TA_REF_MOVIMIENTOS_GP primary key (COD_REFERENCIA, REF_ARCHIVO, COD_MODALIDAD)
  using index 
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