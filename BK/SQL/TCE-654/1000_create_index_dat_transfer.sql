create index IT.IND_GE_DAT_TR_DOC_BEN on IT.GE_DAT_TRANSFERENCIAS (NRO_DOC_BENEFICIARIO)
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
  
create index IT.IND_GE_DAT_TR_DOC_SOL on IT.GE_DAT_TRANSFERENCIAS (NRO_DOC_SOLICITANTE)
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
  

create index IT.IN_GDTRA_SWI_PTE_BENEFICIARIO on IT.GE_DAT_TRANSFERENCIAS (COD_SWI_PTE_SOLICITANTE, COD_SWI_PTE_BENEFICIARIO)
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