create index IT.IN_SBCVC_NRO_DOCUMENTOS on IT.SB_CRC_VTA_CARTERAS (NRO_DOCUMENTO)
  tablespace IT_DATA
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