create table IT.TA_MOV_INTERESES_TMP_RO
(
  ref_archivo       VARCHAR2(30) default 'TAR_MOV_INTERESES' not null,
  nro_cuenta        VARCHAR2(15) not null,
  tip_movimiento    VARCHAR2(1),
  nro_cta_bancaria  VARCHAR2(15),
  fec_proceso       DATE,
  mto_amortizacion  NUMBER(18,2),
  mto_int_cuota     NUMBER(18,2),
  mto_imp_int_cuota NUMBER(18,2),
  cod_plan          VARCHAR2(2),
  cod_entidad       VARCHAR2(3),
  afinidad          VARCHAR2(10),
  sal_aumentado     NUMBER(18,2),
  sal_disminuido    NUMBER(18,2)
)
tablespace IT_DATA
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
comment on column IT.TA_MOV_INTERESES_TMP_RO.ref_archivo
  is 'Referencia del Archivo de Importación.';
comment on column IT.TA_MOV_INTERESES_TMP_RO.nro_cuenta
  is 'Nro. de Cuenta de Tarjeta.';
comment on column IT.TA_MOV_INTERESES_TMP_RO.tip_movimiento
  is 'Tipo de Movimiento.';
comment on column IT.TA_MOV_INTERESES_TMP_RO.nro_cta_bancaria
  is 'Nro. de Cuenta de Bancaria.';
comment on column IT.TA_MOV_INTERESES_TMP_RO.fec_proceso
  is 'Fecha de Proceso.';
comment on column IT.TA_MOV_INTERESES_TMP_RO.mto_amortizacion
  is 'Monto de Amortización.';
comment on column IT.TA_MOV_INTERESES_TMP_RO.mto_int_cuota
  is 'Monto de Interés de la Cuota.';
comment on column IT.TA_MOV_INTERESES_TMP_RO.mto_imp_int_cuota
  is 'Monto del Impuesto del Interés.';
comment on column IT.TA_MOV_INTERESES_TMP_RO.cod_plan
  is 'Código Plan.';
comment on column IT.TA_MOV_INTERESES_TMP_RO.cod_entidad
  is 'Código de Entidad.';
comment on column IT.TA_MOV_INTERESES_TMP_RO.afinidad
  is 'Código Afinidad.';
comment on column IT.TA_MOV_INTERESES_TMP_RO.sal_aumentado
  is 'Saldo Aumentado.';
comment on column IT.TA_MOV_INTERESES_TMP_RO.sal_disminuido
  is 'Saldo Disminuido.';
create index IT.IN_TMEINT_NRO_CUENTA1 on IT.TA_MOV_INTERESES_TMP_RO (NRO_CUENTA)
  tablespace IT_IND
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
create index IT.IN_TMEINT_REF_ARCHIVO1 on IT.TA_MOV_INTERESES_TMP_RO (REF_ARCHIVO)
  tablespace IT_IND
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );

