 create index IT.IN_GSTRA_NRO_DOC_BENEFICIARIO on IT.GE_SNP_TRANSFERENCIAS (NRO_DOC_BENEFICIARIO)
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
  
  create index IT.IN_GSTRA_NRO_DOC_SOLICITANTE on IT.GE_SNP_TRANSFERENCIAS (NRO_DOC_SOLICITANTE)
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
  
  create index IT.IN_GSTRA_NRO_DOC_SOL_PTE on IT.GE_SNP_TRANSFERENCIAS (NRO_DOC_SOLICITANTE, COD_SWI_PTE_SOLICITANTE, FEC_INSERCION)
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
  
  
  create index IT.IN_GSTRA_NRO_DOC_BEN_PTE on IT.GE_SNP_TRANSFERENCIAS (NRO_DOC_BENEFICIARIO, COD_SWI_PTE_BENEFICIARIO, FEC_INSERCION)
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