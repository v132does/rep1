-- Add comments to the columns 
comment on column IT.GE_ING_CLIENTES.estado
  is 'P-Pendiente, V-Verificado, E-Error, M-Migrado';

-- Add/modify columns 
alter table IT.GE_ING_CLIENTES add observacion varchar2(100);
-- Add comments to the columns 
comment on column IT.GE_ING_CLIENTES.observacion
  is 'Observacion.';
