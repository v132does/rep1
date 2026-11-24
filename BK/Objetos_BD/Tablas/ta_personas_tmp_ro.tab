create table IT.TA_PERSONAS_TMP_RO
(
  cod_entidad       NUMBER(7),
  cod_persona       VARCHAR2(10),
  dir_correo        VARCHAR2(60),
  tip_persona       CHAR(1),
  nom_completo      VARCHAR2(42),
  pri_nombre        VARCHAR2(20),
  seg_nombre        VARCHAR2(20),
  pri_apellido      VARCHAR2(20),
  seg_apellido      VARCHAR2(20),
  nombre            VARCHAR2(42),
  nom_largo         VARCHAR2(83),
  tip_documento     VARCHAR2(3),
  nro_documento     VARCHAR2(16),
  cod_pais          NUMBER(3),
  cod_sexo          CHAR(1),
  fec_nacimiento    DATE,
  lug_nacimiento    VARCHAR2(15),
  ruc_extracto      VARCHAR2(11),
  est_civil         CHAR(1),
  cod_ocupacion     NUMBER(4),
  raz_social        VARCHAR2(30),
  ruc               VARCHAR2(11),
  nom_comercial     VARCHAR2(40),
  tip_per_juridica  NUMBER(3),
  tip_firma         NUMBER(1),
  usu_actualizacion VARCHAR2(10),
  fec_actualizacion DATE,
  direccion         NUMBER(3),
  telefono          NUMBER(3),
  tip_cliente       CHAR(1)
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
comment on table IT.TA_PERSONAS_TMP_RO
  is 'Tabla de Personas';
comment on column IT.TA_PERSONAS_TMP_RO.cod_entidad
  is 'Código de Entidad.';
comment on column IT.TA_PERSONAS_TMP_RO.cod_persona
  is 'Código de Persona.';
comment on column IT.TA_PERSONAS_TMP_RO.dir_correo
  is 'Dirección de Correo.';
comment on column IT.TA_PERSONAS_TMP_RO.tip_persona
  is 'Tipo de Persona.';
comment on column IT.TA_PERSONAS_TMP_RO.nom_completo
  is 'Nombre Completo.';
comment on column IT.TA_PERSONAS_TMP_RO.pri_nombre
  is 'Primer Nombre.';
comment on column IT.TA_PERSONAS_TMP_RO.seg_nombre
  is 'Segundo Nombre.';
comment on column IT.TA_PERSONAS_TMP_RO.pri_apellido
  is 'Primer Apellido';
comment on column IT.TA_PERSONAS_TMP_RO.seg_apellido
  is 'Segundo Apellido.';
comment on column IT.TA_PERSONAS_TMP_RO.nombre
  is 'Nombre.';
comment on column IT.TA_PERSONAS_TMP_RO.nom_largo
  is 'Nombre Largo.';
comment on column IT.TA_PERSONAS_TMP_RO.tip_documento
  is 'Tipo de Documento.';
comment on column IT.TA_PERSONAS_TMP_RO.nro_documento
  is 'Número de Documento.';
comment on column IT.TA_PERSONAS_TMP_RO.cod_pais
  is 'Código de PaÌs.';
comment on column IT.TA_PERSONAS_TMP_RO.cod_sexo
  is 'Código de Sexo (M=Masculino / F=Femenino)';
comment on column IT.TA_PERSONAS_TMP_RO.fec_nacimiento
  is 'Fecha de Nacimiento.';
comment on column IT.TA_PERSONAS_TMP_RO.lug_nacimiento
  is 'Lugar de Nacimiento.';
comment on column IT.TA_PERSONAS_TMP_RO.ruc_extracto
  is 'Extracto del RUC.';
comment on column IT.TA_PERSONAS_TMP_RO.est_civil
  is 'Estado Civil.';
comment on column IT.TA_PERSONAS_TMP_RO.cod_ocupacion
  is 'Código de OcupaciÛn.';
comment on column IT.TA_PERSONAS_TMP_RO.raz_social
  is 'Razon Social.';
comment on column IT.TA_PERSONAS_TMP_RO.ruc
  is 'RUC.';
comment on column IT.TA_PERSONAS_TMP_RO.nom_comercial
  is 'Nombre Comercial.';
comment on column IT.TA_PERSONAS_TMP_RO.tip_per_juridica
  is 'Tipo de Persona Jurídica.';
comment on column IT.TA_PERSONAS_TMP_RO.tip_firma
  is 'Tipo de Firma.';
comment on column IT.TA_PERSONAS_TMP_RO.usu_actualizacion
  is 'Usuario que realizó última actualización.';
comment on column IT.TA_PERSONAS_TMP_RO.fec_actualizacion
  is 'Fecha en que se realizó la última modificación.';
comment on column IT.TA_PERSONAS_TMP_RO.direccion
  is 'Dirección.';
comment on column IT.TA_PERSONAS_TMP_RO.telefono
  is 'Teléfono.';
comment on column IT.TA_PERSONAS_TMP_RO.tip_cliente
  is 'Tipo de Cliente.';
create index IT.IN_TPER_COD_PERSONA1 on IT.TA_PERSONAS_TMP_RO (TO_NUMBER(COD_PERSONA))
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
create index IT.IN_TTPER_COD_PERSONA1 on IT.TA_PERSONAS_TMP_RO (TRIM(COD_PERSONA))
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

