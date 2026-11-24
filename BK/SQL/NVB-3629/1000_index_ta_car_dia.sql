create index IT.IN_TACAR_DIA_COM_CTA on IT.TA_CAR_DIA_ING_DET (NRO_CUENTA, COMPROBANTE)
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