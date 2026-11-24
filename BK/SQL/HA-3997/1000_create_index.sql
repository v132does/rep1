create index IT.IN_GSTRA_COD_MONEDA on IT.GE_SNP_TRANSFERENCIAS (COD_MONEDA) ONLINE
  tablespace IT_IND
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 8K
    minextents 1
    maxextents unlimited
  );

create index IT.IN_PSCAR_COD_MONEDA on IT.PR_SOL_CARGOS (COD_MONEDA) ONLINE
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
create index IT.IN_BWPEN_COD_MONEDA on IT.BW_MOV_PENDIENTES (COD_MONEDA) ONLINE
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

create index IT.IN_PGARA_COD_MONEDA on IT.PR_GARANTIAS (COD_MONEDA) ONLINE
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

create index IT.IN_PGARA_COD_MON_TAS on IT.PR_GARANTIAS (COD_MON_TASACION ) ONLINE
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
   
