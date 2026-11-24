

-- Create/Recreate primary, unique and foreign key constraints 
alter table IT.GE_MEN_CLI_MT940_V1
  drop constraint PK_GE_MEN_CLI_MT940_V1 cascade;
alter table IT.GE_MEN_CLI_MT940_V1
  add constraint PK_GE_MEN_CLI_MT940_V1 primary key (COD_PERSONA, NRO_CUENTA, NRO_EXTRACTO, NRO_SECUENCIA, TIP_GENERACION, FEC_DESDE, FEC_HASTA )
  using index 
  tablespace IT_IND
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 2M
    next 1M
    minextents 1
    maxextents unlimited
  );
