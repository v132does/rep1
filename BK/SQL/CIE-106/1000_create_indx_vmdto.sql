CREATE INDEX IT.IN_VMDO_COD_PERSONA ON IT.vm_detalle_operaciones(cod_persona);

grant select on IT.vm_detalle_operaciones to IT_TEMPORAL;
create or replace public synonym vm_detalle_operaciones
  for IT.vm_detalle_operaciones;

grant select on IT.vm_total_operaciones to IT_TEMPORAL;
create or replace public synonym vm_total_operaciones
  for IT.vm_total_operaciones;