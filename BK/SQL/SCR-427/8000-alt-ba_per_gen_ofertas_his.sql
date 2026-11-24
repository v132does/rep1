-- Add/modify columns 
alter table IT.BA_PER_GEN_OFERTAS_his add nde_prestamo number;
-- Add comments to the columns 
comment on column IT.BA_PER_GEN_OFERTAS_his.nde_prestamo
  is 'Nivel de endeudamiento Préstamo.';
