-- Add/modify columns 
alter table IT.BA_PER_GEN_OFERTAS add can_cuo_ml number;
alter table IT.BA_PER_GEN_OFERTAS add rci_ml number;
alter table IT.BA_PER_GEN_OFERTAS add mto_max_tc number;
alter table IT.BA_PER_GEN_OFERTAS add mto_max_pr number;
-- Add comments to the columns 
comment on column IT.BA_PER_GEN_OFERTAS.can_cuo_ml
  is 'Cantidad de cuotas recibidas ML. Matriz de ofertas.';
comment on column IT.BA_PER_GEN_OFERTAS.rci_ml
  is 'Relacion RCI de ML. Matriz de ofertas.';

-- Add comments to the columns 
comment on column IT.BA_PER_GEN_OFERTAS.mto_max_tc
  is 'Monto máximo para tarjeta de crédito.';
comment on column IT.BA_PER_GEN_OFERTAS.mto_max_pr
  is 'Monto máximo para préstamo.';
