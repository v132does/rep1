create index IT.IN_ACER_COD_MODULO ON IT.AH_CER_GRUPOS (COD_MODULO, COD_MODALIDAD, TIP_MONEDA, COD_OFICINA, SERIE, COD_USU_RESPONSABLE, ESTADO)
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
