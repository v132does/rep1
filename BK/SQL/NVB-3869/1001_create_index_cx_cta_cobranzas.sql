DROP INDEX IT.IN_BBVA_COD_MODALIDAD;
create index IT.IN_CXCOB_COD_MODULO on IT.CX_CTA_COBRANZAS (COD_MODULO, COD_MODALIDAD) ONLINE
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
create index IT.IN_CXCOB_COD_BCO_CORRESP on IT.CX_CTA_COBRANZAS (COD_BCO_CORRESPONSAL) ONLINE
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
create index IT.IN_CXCOB_COD_CAU_CANCELA on IT.CX_CTA_COBRANZAS (COD_CAU_CANCELACION) ONLINE
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
create index IT.IN_CXCOB_COD_CIU_BENEFICIARIO on IT.CX_CTA_COBRANZAS (COD_CIU_BENEFICIARIO, COD_PAI_BENEFICIARIO) ONLINE
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
create index IT.IN_CXCOB_COD_CIU_PAGADOR on IT.CX_CTA_COBRANZAS (COD_CIU_PAGADOR, COD_PAI_PAGADOR) ONLINE
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
create index IT.IN_CXCOB_COD_OFICINA on IT.CX_CTA_COBRANZAS (COD_OFICINA) ONLINE
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
create index IT.IN_CXCOB_COD_PAI_BENEFICIARIO on IT.CX_CTA_COBRANZAS (COD_PAI_BENEFICIARIO) ONLINE
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
  create index IT.IN_CXCOB_COD_PAI_PAGADOR on IT.CX_CTA_COBRANZAS (COD_PAI_PAGADOR) ONLINE
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
create index IT.IN_CXCOB_COD_PER_BENEFICIARIO on IT.CX_CTA_COBRANZAS (COD_PER_BENEFICIARIO) ONLINE
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
