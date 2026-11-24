-- Add/modify columns 
alter table IT.GE_DAT_TRANSFERENCIAS add cotizacion NUMBER(14,8);
-- Add comments to the columns 
comment on column IT.GE_DAT_TRANSFERENCIAS.cotizacion
  is 'Cotizacion del movimiento';
