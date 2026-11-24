create index IT.IN_COD_PERSONA_ESTADO on BA_USUARIOS (COD_PERSONA, ESTADO)
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
