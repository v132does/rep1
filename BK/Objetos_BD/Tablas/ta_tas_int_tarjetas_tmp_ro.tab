create table IT.TA_TAS_INT_TARJETAS_TMP_RO
(
  cod_entidad          NUMBER(3),
  cod_afinidad         NUMBER(6),
  cod_moneda           NUMBER(3),
  cod_tip_tas_interes  NUMBER(3),
  tip_tas_financiacion CHAR(1),
  val_tasa             NUMBER(5,2),
  fec_actualizacion    DATE default sysdate,
  usu_actualizacion    VARCHAR2(10)
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
comment on table IT.TA_TAS_INT_TARJETAS_TMP_RO
  is 'Tabla de Tasas de Interes  General de Tarjetas';
comment on column IT.TA_TAS_INT_TARJETAS_TMP_RO.cod_entidad
  is 'CÛdigo de Entidad.';
comment on column IT.TA_TAS_INT_TARJETAS_TMP_RO.cod_afinidad
  is 'CÛdigo de Afinidad';
comment on column IT.TA_TAS_INT_TARJETAS_TMP_RO.cod_moneda
  is 'CÛdigo de Moneda.';
comment on column IT.TA_TAS_INT_TARJETAS_TMP_RO.cod_tip_tas_interes
  is 'CÛdigo del tipo de tasa de interes.';
comment on column IT.TA_TAS_INT_TARJETAS_TMP_RO.tip_tas_financiacion
  is 'Tipo de tasa de financiación.';
comment on column IT.TA_TAS_INT_TARJETAS_TMP_RO.val_tasa
  is 'Valor de Tasa.';
comment on column IT.TA_TAS_INT_TARJETAS_TMP_RO.fec_actualizacion
  is 'Fecha de la última actualizacion del registro.';
comment on column IT.TA_TAS_INT_TARJETAS_TMP_RO.usu_actualizacion
  is 'Usuario responsable de la ˙ltima actualización del registro.';
create index IT.IN_TTINT_COD_ENTIDAD1 on IT.TA_TAS_INT_TARJETAS_TMP_RO (COD_ENTIDAD)
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
create index IT.IN_TTINT_TIP_TAS_FINANCIACION1 on IT.TA_TAS_INT_TARJETAS_TMP_RO (TIP_TAS_FINANCIACION)
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

