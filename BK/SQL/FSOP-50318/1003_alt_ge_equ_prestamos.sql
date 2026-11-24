-- Add/modify columns 
alter table IT.GE_EQU_PRESTAMOS add est_deuda VARCHAR2(160);
-- Add comments to the columns 
comment on column IT.GE_EQU_PRESTAMOS.est_deuda
  is 'Es el estado en que se encuentra la operación';
