create index IT.IN_WPAGS_COD_PAG_SERVICIO on IT.BW_PAG_SERVICIOS (COD_PAG_SERVICIO)
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
