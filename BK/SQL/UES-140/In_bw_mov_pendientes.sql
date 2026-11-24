create index IT.IN_COD_PER_INGRESO on IT.BW_MOV_PENDIENTES (COD_PER_INGRESO) online
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
 create index IT.IN_COD_PER_PRINCIPAL on IT.BW_MOV_PENDIENTES (COD_PER_PRINCIPAL) online
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
 create index IT.IN_COD_TIP_MENSAJE on IT.BW_MOV_PENDIENTES (COD_TIP_MENSAJE) online
 tablespace IT_IND  pctfree 10  initrans 2  maxtrans 255  storage
 (  initial 64K
  next 1M
  minextents 1
  maxextents unlimited
 );