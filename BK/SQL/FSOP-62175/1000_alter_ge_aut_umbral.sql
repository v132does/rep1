-- Add/modify columns 
alter table IT.GE_AUT_UMBRAL add cod_moneda VARCHAR2(3);
alter table IT.GE_AUT_UMBRAL add monto_operacion NUMBER(18,2);
-- Add comments to the columns 
comment on column IT.GE_AUT_UMBRAL.cod_moneda
  is 'Moneda de la operacion.';
comment on column IT.GE_AUT_UMBRAL.monto_operacion
  is 'Monto de la operacion.';
