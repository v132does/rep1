-- Create table
create global temporary table IT.CB_ASI_MASIVOS_TMP
(
  cod_ofi_operacion   NUMBER(3),
  cod_ofi_destino     NUMBER(3),
  cod_rubro           VARCHAR2(15),
  descripcion         VARCHAR2(100),
  tip_mov_rubro       VARCHAR2(1),
  cotizacion          NUMBER(14,8),
  monto               NUMBER(18,2),
  cod_moneda          VARCHAR2(3),
  nro_referencia      NUMBER(15),
  mto_mon_extranjera  NUMBER(18,2),
  mto_mon_local       NUMBER(18,2),
  nro_cuenta          VARCHAR2(15),
  cod_persona         VARCHAR2(10),
  cod_area            NUMBER(3),
  cod_ori_movimientos NUMBER(3),
  cod_cnc_movimientos NUMBER(3),
  cod_are_solicitante NUMBER(3)
)
on commit preserve rows;
-- Add comments to the table 
comment on table IT.CB_ASI_MASIVOS_TMP
  is 'Tabla que registra los asientos manuales importados.';
-- Add comments to the columns 
comment on column IT.CB_ASI_MASIVOS_TMP.cod_ofi_operacion
  is 'Código de Oficina de la Operación.';
comment on column IT.CB_ASI_MASIVOS_TMP.cod_ofi_destino
  is 'Código de Oficina Destino.';
comment on column IT.CB_ASI_MASIVOS_TMP.cod_rubro
  is 'Código de Rubro.';
comment on column IT.CB_ASI_MASIVOS_TMP.descripcion
  is 'Descripción.';
comment on column IT.CB_ASI_MASIVOS_TMP.tip_mov_rubro
  is 'Tipo de Movimiento (D-C).';
comment on column IT.CB_ASI_MASIVOS_TMP.cotizacion
  is 'Cotización.';
comment on column IT.CB_ASI_MASIVOS_TMP.monto
  is 'Importe.';
comment on column IT.CB_ASI_MASIVOS_TMP.cod_moneda
  is 'Código de Moneda.';
comment on column IT.CB_ASI_MASIVOS_TMP.nro_referencia
  is 'Número de Referencia.';
comment on column IT.CB_ASI_MASIVOS_TMP.mto_mon_extranjera
  is 'Importe en Moneda Extranjera.';
comment on column IT.CB_ASI_MASIVOS_TMP.mto_mon_local
  is 'Importe en Moneda Local.';
comment on column IT.CB_ASI_MASIVOS_TMP.nro_cuenta
  is 'Número de Cuenta del Cliente.';
comment on column IT.CB_ASI_MASIVOS_TMP.cod_persona
  is 'Código de Persona.';
comment on column IT.CB_ASI_MASIVOS_TMP.cod_area
  is 'Código de Area (Centros de Costos).';
comment on column IT.CB_ASI_MASIVOS_TMP.cod_ori_movimientos
  is 'Código de Origen del Movimiento.';
comment on column IT.CB_ASI_MASIVOS_TMP.cod_cnc_movimientos
  is 'Código del Concepto que genero el movimiento.';
comment on column IT.CB_ASI_MASIVOS_TMP.cod_are_solicitante
  is 'Código del área solicitante del movimiento.';

