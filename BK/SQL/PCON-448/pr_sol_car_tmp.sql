-- Create table
create global temporary table IT.PR_SOL_CAR_TMP
(
  nro_solicitud    NUMBER(7) not null,
  cod_transaccion  NUMBER(4) not null,
  fec_tasa         DATE,
  val_tasa         NUMBER(20,4) default 0,
  monto            NUMBER(18,2) default 0,
  cod_tasa         NUMBER(3),
  cod_ent_seguro   NUMBER(5),
  cod_moneda       VARCHAR2(3) not null,
  mto_mon_prestamo NUMBER(18,2) default 0
)
on commit preserve rows;
-- Add comments to the table 
comment on table IT.PR_SOL_CAR_TMP
  is 'Contiene los datos temporales de los cargos cobrados en la aceptación de préstamos.';
-- Add comments to the columns 
comment on column IT.PR_SOL_CAR_TMP.nro_solicitud
  is 'Número de propuesta.';
comment on column IT.PR_SOL_CAR_TMP.cod_transaccion
  is 'Código de la transacción del cargo.';
comment on column IT.PR_SOL_CAR_TMP.fec_tasa
  is 'Fecha de la tasa.';
comment on column IT.PR_SOL_CAR_TMP.val_tasa
  is 'Valor de la tasa.';
comment on column IT.PR_SOL_CAR_TMP.monto
  is 'Monto del cargo.';
comment on column IT.PR_SOL_CAR_TMP.cod_tasa
  is 'Código de tasa aplicada.';
comment on column IT.PR_SOL_CAR_TMP.cod_ent_seguro
  is 'Código del seguro.';
comment on column IT.PR_SOL_CAR_TMP.cod_moneda
  is 'Código de moneda.';
comment on column IT.PR_SOL_CAR_TMP.mto_mon_prestamo
  is 'Monto del cargo en USD.';
-- Grant/Revoke object privileges 
grant select, insert, update, delete on IT.PR_SOL_CAR_TMP to IT_TEMPORAL;
