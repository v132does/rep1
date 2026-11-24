-- Create/Recreate primary, unique and foreign key constraints 
alter table IT.CB_ASI_FUTUROS_DET
  drop constraint FK_BAFDE_NRO_ASIENTO;
alter table IT.CB_ASI_FUTUROS_DET
  add constraint FK_BAFDE_NRO_ASIENTO foreign key (FECHA, COD_OFICINA, NRO_ASIENTO)
  references IT.CB_ASI_FUTUROS (FECHA, COD_OFICINA, NRO_ASIENTO) on delete cascade
  deferrable initially deferred;
