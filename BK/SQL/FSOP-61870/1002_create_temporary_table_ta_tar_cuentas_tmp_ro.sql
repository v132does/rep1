create table IT.TA_TAR_CUENTAS_TMP_RO
(
  nro_tarjeta           VARCHAR2(19),
  denominacion          VARCHAR2(42),
  cod_entidad           NUMBER(3),
  cod_afinidad          NUMBER(6),
  cod_marca             VARCHAR2(3),
  cod_pro_marca         VARCHAR2(3),
  nro_cuenta            NUMBER(11),
  cod_persona           NUMBER(7),
  nro_documento         VARCHAR2(16),
  tip_tarjeta           VARCHAR2(1),
  nom_plastico          VARCHAR2(26),
  fec_desde             DATE,
  duracion              NUMBER(2),
  fec_hasta             DATE,
  fec_embozado          DATE,
  personalizada         VARCHAR2(1),
  renovar               VARCHAR2(1),
  tip_plastico          VARCHAR2(1),
  tip_documento         VARCHAR2(3),
  nom_banda             VARCHAR2(26),
  fec_recibo            DATE,
  fec_embozado2         DATE,
  fec_pin               DATE,
  fec_emision           DATE,
  tip_ult_embozado      VARCHAR2(1),
  cob_seguro            VARCHAR2(1),
  recuperada            VARCHAR2(1),
  vencida               VARCHAR2(1),
  tip_bloqueo           VARCHAR2(1),
  sit_tarjeta           VARCHAR2(1),
  reservado             NUMBER(4),
  usu_insercion         VARCHAR2(10),
  fec_ingreso           DATE,
  usu_ult_actualizacion VARCHAR2(10),
  fec_ult_actualizacion DATE,
  fec_sit_tarjeta       DATE,
  obs_sit_tarjeta       VARCHAR2(40),
  emboza                VARCHAR2(1),
  reserva               NUMBER(4),
  reservado6            NUMBER(6),
  reservado1            VARCHAR2(1),
  reservado2            NUMBER(4),
  reservado3            NUMBER(10),
  reservado4            NUMBER(10),
  mot_novedad           NUMBER(3),
  mot_entidad           NUMBER(3),
  cod_for_recibo        NUMBER(4),
  pin_formato           NUMBER(4),
  cod_promotor          NUMBER(7),
  cod_mot_novedad       NUMBER(3),
  seg_cod_mot_entidad   NUMBER(3),
  obs_mot_tarjeta       VARCHAR2(40),
  cod_dis_datacard      VARCHAR2(3),
  fec_reservado1        DATE,
  fec_reservado2        DATE,
  letra                 VARCHAR2(2)
)
tablespace IT_DATA
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 16M
    next 1M
    minextents 1
    maxextents unlimited
  );
comment on table IT.TA_TAR_CUENTAS_TMP_RO
  is 'Tabla de Tarjetas.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.nro_tarjeta
  is 'Número de la Tarjeta.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.denominacion
  is 'Denominación.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.cod_entidad
  is 'Código de Entidad.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.cod_afinidad
  is 'Código de Afinidad.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.cod_marca
  is 'Código de Marca.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.cod_pro_marca
  is 'Código de Producto de Marca.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.nro_cuenta
  is 'Número de Cuneta.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.cod_persona
  is 'Código de Persona.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.nro_documento
  is 'Número de Documento.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.tip_tarjeta
  is 'Tipo de Tarjeta.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.nom_plastico
  is 'Nombre del Plástico.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.fec_desde
  is 'Fecha desde.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.duracion
  is 'Duración.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.fec_hasta
  is 'Fecha Hasta,';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.fec_embozado
  is 'Fecha Embozado.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.personalizada
  is 'Personalizada.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.renovar
  is 'Renovar.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.tip_plastico
  is 'Tipo de Plástico.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.tip_documento
  is 'Tipo de Documento.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.nom_banda
  is 'Nombre de Banda.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.fec_recibo
  is 'Fehca de Recibo.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.fec_embozado2
  is 'Fecha de Embozado2.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.fec_pin
  is 'Fecha de PIN.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.fec_emision
  is 'Fecha de Emisión.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.tip_ult_embozado
  is 'Tipo de ⁄último Embozado.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.cob_seguro
  is 'Cobertura del Seguro.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.recuperada
  is 'Recuperada.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.vencida
  is 'Vencida.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.tip_bloqueo
  is 'Tipo de Bloqueo.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.sit_tarjeta
  is 'Situación de la Tarjeta.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.reservado
  is 'Reservado.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.usu_insercion
  is 'Usuario que insertó el registro.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.fec_ingreso
  is 'Fecha de Ingreso.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.usu_ult_actualizacion
  is 'Usuario encargado de actualizar por última vez.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.fec_ult_actualizacion
  is 'Fecha de la ˙ltima actualización.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.fec_sit_tarjeta
  is 'Fecha de Situación de la Tarjeta.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.obs_sit_tarjeta
  is 'Observación de la situación de la Tarjeta.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.emboza
  is 'Emboza.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.reserva
  is 'Espacio Reservado.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.reservado6
  is 'Espacio Reservado.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.reservado1
  is 'Espacio Reservado.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.reservado2
  is 'Espacio Reservado.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.reservado3
  is 'Espacio Reservado.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.reservado4
  is 'Espacio Reservado.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.mot_novedad
  is 'Motivo de la Novedad.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.mot_entidad
  is 'Motivo de la Entidad.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.cod_for_recibo
  is 'Código del formato recibido.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.pin_formato
  is 'Pin del formato.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.cod_promotor
  is 'Código del Promotor';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.cod_mot_novedad
  is 'Código del Motivo de Novedad.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.seg_cod_mot_entidad
  is 'Segundo Código del Motivo de Novedad.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.obs_mot_tarjeta
  is 'Observación del motivo de la tarjeta.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.cod_dis_datacard
  is 'Código Datacard.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.fec_reservado1
  is 'Fecha: campo fecha reservado 1.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.fec_reservado2
  is 'Fecha: campo fecha reservado 2.';
comment on column IT.TA_TAR_CUENTAS_TMP_RO.letra
  is 'Letra: campo reservado.';
create index IT.IN_TCTAR_COD_AFINIDAD1 on IT.TA_TAR_CUENTAS_TMP_RO (COD_AFINIDAD)
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
create index IT.IN_TCTAR_COD_ENTIDAD1 on IT.TA_TAR_CUENTAS_TMP_RO (COD_ENTIDAD)
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
create index IT.IN_TCTAR_COD_PERSONA1 on IT.TA_TAR_CUENTAS_TMP_RO (COD_PERSONA)
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
create index IT.IN_TCTAR_DENOMINACION1 on IT.TA_TAR_CUENTAS_TMP_RO (DENOMINACION)
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
create index IT.IN_TCTAR_NRO_CTA1 on IT.TA_TAR_CUENTAS_TMP_RO (TO_CHAR(NRO_CUENTA), TRIM(NRO_TARJETA))
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
create index IT.IN_TCTAR_NRO_CUENTA1 on IT.TA_TAR_CUENTAS_TMP_RO (NRO_CUENTA)
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
create index IT.IN_TCTAR_NRO_DOCUMENTO1 on IT.TA_TAR_CUENTAS_TMP_RO (NRO_DOCUMENTO)
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
create index IT.IN_TCTAR_NRO_TARJETA1 on IT.TA_TAR_CUENTAS_TMP_RO (NRO_TARJETA)
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
create index IT.IN_TCTAR_SIT_TARJETA1 on IT.TA_TAR_CUENTAS_TMP_RO (SIT_TARJETA)
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

