alter table IT.CR_PIZ_PLAZOS_HIS
      drop constraint UK_CR_PIZ_PLAZOS_HIS;
-- Create/Recreate primary, unique and foreign key constraints 
alter table IT.CR_PIZ_PLAZOS_HIS
  add constraint UK_CR_PIZ_PLAZOS_HIS unique (COD_MODULO, COD_MODALIDAD, COD_MONEDA, MTO_DESDE, PLZ_DESDE, TIP_CAPITALIZACION,COD_SUB_MODALIDAD)
  using index 
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
