-- Add/modify columns 
alter table IT.BA_PER_GEN_OFERTAS add nde_prestamo number;
-- Add comments to the columns 
comment on column IT.BA_PER_GEN_OFERTAS.nde_prestamo
  is 'Nivel de endeudamiento Préstamo.';
