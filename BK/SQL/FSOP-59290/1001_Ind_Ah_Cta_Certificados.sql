create index IT.IN_AHCER_COD_MODULO_3 ON IT.AH_CTA_CERTIFICADOS (COD_MODULO, COD_MODALIDAD, SERIE, NRO_CERTIFICADO, COD_MONEDA)
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
