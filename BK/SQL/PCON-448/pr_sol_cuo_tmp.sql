-- Create table
create global temporary table IT.PR_SOL_CUO_TMP
(
  nro_solicitud      NUMBER(7) not null,
  nro_cuota          NUMBER(3) not null,
  mto_capital        NUMBER(18,2) default 0 not null,
  fec_vto_habil      DATE,
  fec_vto_exacto     DATE,
  val_interes        NUMBER(20,4) default 0,
  sal_capital        NUMBER(18,2) default 0,
  sal_cap_anterior   NUMBER(18,2) default 0,
  dia_periodo        NUMBER(4),
  dia_transcurridos  NUMBER(4),
  dia_interes        NUMBER(4),
  tip_calculo        VARCHAR2(1),
  val_int_original   NUMBER(20,4) default 0,
  val_int_adelantado NUMBER(20,4) default 0,
  val_iva_interes    NUMBER(20,4) default 0,
  val_seguro         NUMBER(18,2)
)
on commit preserve rows;
-- Add comments to the table 
comment on table IT.PR_SOL_CUO_TMP
  is 'Contiene datos temporales de las Cuotas de las Solicitudes de Prestamos.';
-- Add comments to the columns 
comment on column IT.PR_SOL_CUO_TMP.nro_solicitud
  is 'Número de propuesta.';
comment on column IT.PR_SOL_CUO_TMP.nro_cuota
  is 'Número de cuota.';
comment on column IT.PR_SOL_CUO_TMP.mto_capital
  is 'Monto de capital a amortizar.';
comment on column IT.PR_SOL_CUO_TMP.fec_vto_habil
  is 'Fecha de vencimiento hábil.';
comment on column IT.PR_SOL_CUO_TMP.fec_vto_exacto
  is 'Fecha de vencimiento exacto.';
comment on column IT.PR_SOL_CUO_TMP.val_interes
  is 'Valor del interés a amortizar.';
comment on column IT.PR_SOL_CUO_TMP.sal_capital
  is 'Valor del saldo del capital.';
comment on column IT.PR_SOL_CUO_TMP.sal_cap_anterior
  is 'Valor del saldo del capital anterior.';
comment on column IT.PR_SOL_CUO_TMP.dia_periodo
  is 'Cantidad de dias del periodo.';
comment on column IT.PR_SOL_CUO_TMP.dia_transcurridos
  is 'Cantidad de dias transcurridos desde el inicio.';
comment on column IT.PR_SOL_CUO_TMP.dia_interes
  is 'Cantidad de dias del interés.';
comment on column IT.PR_SOL_CUO_TMP.tip_calculo
  is 'Tipo de cálculo del interés.';
comment on column IT.PR_SOL_CUO_TMP.val_int_original
  is 'Valor original del interés.';
comment on column IT.PR_SOL_CUO_TMP.val_int_adelantado
  is 'Valor del interés adelantado.';
comment on column IT.PR_SOL_CUO_TMP.val_seguro
  is 'Valor del seguro que fue calculado por WF. Este campo se utiliza para los reportes.';
-- Grant/Revoke object privileges 
grant select, insert, update, delete on IT.PR_SOL_CUO_TMP to IT_TEMPORAL;
