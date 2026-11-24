create table IT.TA_CTA_LIN_TARJETAS_TMP_RO
(
  cod_entidad         NUMBER(3),
  nro_cuenta          NUMBER(11),
  cod_moneda          NUMBER(3),
  cod_tip_lin_credito NUMBER(15,2),
  reservado           CHAR(1),
  mto_lin_credito     NUMBER(15,2)
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
comment on table IT.TA_CTA_LIN_TARJETAS_TMP_RO
  is 'Es la tabla de Saldo de la Cuenta.';
comment on column IT.TA_CTA_LIN_TARJETAS_TMP_RO.cod_entidad
  is 'Es el cÛdigo de la Entidad.';
comment on column IT.TA_CTA_LIN_TARJETAS_TMP_RO.nro_cuenta
  is 'Es el n˙mero de Cuenta.';
comment on column IT.TA_CTA_LIN_TARJETAS_TMP_RO.cod_moneda
  is 'El código de moneda';
comment on column IT.TA_CTA_LIN_TARJETAS_TMP_RO.cod_tip_lin_credito
  is 'El código de tipo de linea de crédito.';
comment on column IT.TA_CTA_LIN_TARJETAS_TMP_RO.reservado
  is 'Reservado.';
comment on column IT.TA_CTA_LIN_TARJETAS_TMP_RO.mto_lin_credito
  is 'El monto de la linea de crédito.';
create index IT.IN_NRO_CUENTA1 on IT.TA_CTA_LIN_TARJETAS_TMP_RO (NRO_CUENTA)
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

