create table IT.TA_CUENTAS_TMP_RO
(
  nro_cuenta          NUMBER(11),
  denominacion        VARCHAR2(42),
  cod_entidad         NUMBER(3),
  cod_afinidad        NUMBER(6),
  cod_marca           VARCHAR2(3),
  cod_pro_marca       VARCHAR2(3),
  tip_cuenta          VARCHAR2(1),
  cod_persona         NUMBER(7),
  cod_pais            NUMBER(3),
  cod_departamento    NUMBER(3),
  cod_ciudad          NUMBER(6),
  telefono            VARCHAR2(15),
  cod_oficina         NUMBER(4),
  oficial             NUMBER(7),
  tip_costo           VARCHAR2(1),
  vip                 VARCHAR2(1),
  franqueo            VARCHAR2(1),
  ret_extracto        VARCHAR2(1),
  tip_cierre          VARCHAR2(2),
  sit_cuenta          VARCHAR2(1),
  dia_mora            NUMBER(5),
  fec_ult_vencimiento DATE,
  fec_ult_cierre      DATE,
  tip_documento       VARCHAR2(3),
  nro_documento       VARCHAR2(16),
  ruc                 VARCHAR2(11),
  cob_costo           VARCHAR2(1),
  mot_ret_extracto    NUMBER(3),
  usu_insercion       VARCHAR2(10),
  fec_ingreso         DATE,
  usu_actualizacion   VARCHAR2(10),
  fec_actualizacion   DATE,
  ind_seg_vida        VARCHAR2(1),
  calificacion_bcp    NUMBER(1) default 0,
  reservado           NUMBER(10),
  fec_sit_cuenta      DATE,
  observacion         VARCHAR2(40),
  dir_correo          VARCHAR2(60),
  mot_novedad         NUMBER(3),
  mot_entidad         NUMBER(3),
  emp_adherida        NUMBER(5),
  cod_zona            VARCHAR2(10),
  reserva             VARCHAR2(1),
  celular             VARCHAR2(15),
  dir_recibo          VARCHAR2(35),
  ciu_recibo          VARCHAR2(15),
  pri_dir_extracto    VARCHAR2(50),
  seg_dir_extracto    VARCHAR2(50),
  ter_dir_extracto    VARCHAR2(50),
  cod_per_entidad     VARCHAR2(15),
  fec_ult_transaccion DATE,
  fec_pri_compra      DATE,
  fec_ult_pago        DATE,
  fec_reservado1      DATE,
  fec_reservado2      DATE,
  cod_exc_cargo       VARCHAR2(30)
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
comment on table IT.TA_CUENTAS_TMP_RO
  is 'Tabla de Cuentas Generales.';
comment on column IT.TA_CUENTAS_TMP_RO.nro_cuenta
  is 'Número de Cuenta.';
comment on column IT.TA_CUENTAS_TMP_RO.denominacion
  is 'Denominación.';
comment on column IT.TA_CUENTAS_TMP_RO.cod_entidad
  is 'Código de Entidad.';
comment on column IT.TA_CUENTAS_TMP_RO.cod_afinidad
  is 'Código de Afinidad.';
comment on column IT.TA_CUENTAS_TMP_RO.cod_marca
  is 'Código de Marca.';
comment on column IT.TA_CUENTAS_TMP_RO.cod_pro_marca
  is 'Código de Producto de Marca.';
comment on column IT.TA_CUENTAS_TMP_RO.tip_cuenta
  is 'Tipo de Cuenta.';
comment on column IT.TA_CUENTAS_TMP_RO.cod_persona
  is 'Código de Persona.';
comment on column IT.TA_CUENTAS_TMP_RO.cod_pais
  is 'Código de Pais.';
comment on column IT.TA_CUENTAS_TMP_RO.cod_departamento
  is 'Código de Departamento.';
comment on column IT.TA_CUENTAS_TMP_RO.cod_ciudad
  is 'Código de Ciudad';
comment on column IT.TA_CUENTAS_TMP_RO.telefono
  is 'Teléfono.';
comment on column IT.TA_CUENTAS_TMP_RO.cod_oficina
  is 'Código de Oficina.';
comment on column IT.TA_CUENTAS_TMP_RO.oficial
  is 'Oficial.';
comment on column IT.TA_CUENTAS_TMP_RO.tip_costo
  is 'Tipo de Costo.';
comment on column IT.TA_CUENTAS_TMP_RO.vip
  is 'VIP.';
comment on column IT.TA_CUENTAS_TMP_RO.franqueo
  is 'Franqueo.';
comment on column IT.TA_CUENTAS_TMP_RO.ret_extracto
  is 'Retención de Extracto.';
comment on column IT.TA_CUENTAS_TMP_RO.tip_cierre
  is 'Tipo de Cierre.';
comment on column IT.TA_CUENTAS_TMP_RO.sit_cuenta
  is 'Situación de Cuenta.';
comment on column IT.TA_CUENTAS_TMP_RO.dia_mora
  is 'DÌas de Mora.';
comment on column IT.TA_CUENTAS_TMP_RO.fec_ult_vencimiento
  is 'Fecha de último vencimiento.';
comment on column IT.TA_CUENTAS_TMP_RO.fec_ult_cierre
  is 'Fecha de último cierre.';
comment on column IT.TA_CUENTAS_TMP_RO.tip_documento
  is 'Tipo de Documento.';
comment on column IT.TA_CUENTAS_TMP_RO.nro_documento
  is 'Número de Documento.';
comment on column IT.TA_CUENTAS_TMP_RO.ruc
  is 'RUC.';
comment on column IT.TA_CUENTAS_TMP_RO.cob_costo
  is 'Cobertura de Costo.';
comment on column IT.TA_CUENTAS_TMP_RO.mot_ret_extracto
  is 'Motivo de Retención de Extracto.';
comment on column IT.TA_CUENTAS_TMP_RO.usu_insercion
  is 'Usuario que realizó la inserción del registro.';
comment on column IT.TA_CUENTAS_TMP_RO.fec_ingreso
  is 'Fecha de Ingreso.';
comment on column IT.TA_CUENTAS_TMP_RO.usu_actualizacion
  is 'Usuario que realizÛ la última actualización del registro.';
comment on column IT.TA_CUENTAS_TMP_RO.fec_actualizacion
  is 'Fecha en que se actualizó por última vez el registro.';
comment on column IT.TA_CUENTAS_TMP_RO.ind_seg_vida
  is 'Seguro de Vida.';
comment on column IT.TA_CUENTAS_TMP_RO.calificacion_bcp
  is 'Calificación BCP.';
comment on column IT.TA_CUENTAS_TMP_RO.reservado
  is 'Reservado.';
comment on column IT.TA_CUENTAS_TMP_RO.fec_sit_cuenta
  is 'Fecha de Situación de Cuenta.';
comment on column IT.TA_CUENTAS_TMP_RO.observacion
  is 'Observación.';
comment on column IT.TA_CUENTAS_TMP_RO.dir_correo
  is 'Dirección de Correo';
comment on column IT.TA_CUENTAS_TMP_RO.mot_novedad
  is 'Motivo de la Novedad.';
comment on column IT.TA_CUENTAS_TMP_RO.mot_entidad
  is 'Motivo de la Entidad.';
comment on column IT.TA_CUENTAS_TMP_RO.emp_adherida
  is 'Empresa Adherida.';
comment on column IT.TA_CUENTAS_TMP_RO.cod_zona
  is 'Código de Zona.';
comment on column IT.TA_CUENTAS_TMP_RO.reserva
  is 'Reserva.';
comment on column IT.TA_CUENTAS_TMP_RO.celular
  is 'Celular.';
comment on column IT.TA_CUENTAS_TMP_RO.dir_recibo
  is 'Driección de Recibo.';
comment on column IT.TA_CUENTAS_TMP_RO.ciu_recibo
  is 'Ciudad de Recibo';
comment on column IT.TA_CUENTAS_TMP_RO.pri_dir_extracto
  is 'Primera Dirección del Extracto.';
comment on column IT.TA_CUENTAS_TMP_RO.seg_dir_extracto
  is 'Segunda Dirección del Extracto.';
comment on column IT.TA_CUENTAS_TMP_RO.ter_dir_extracto
  is 'tercera Dirección del Extracto.';
comment on column IT.TA_CUENTAS_TMP_RO.cod_per_entidad
  is 'Código de Cliente Entidad.';
comment on column IT.TA_CUENTAS_TMP_RO.fec_ult_transaccion
  is 'Fecha de ⁄última TransacciÛn.';
comment on column IT.TA_CUENTAS_TMP_RO.fec_pri_compra
  is 'Fecha de Primera Compra.';
comment on column IT.TA_CUENTAS_TMP_RO.fec_ult_pago
  is 'Fecha ⁄último Pago.';
comment on column IT.TA_CUENTAS_TMP_RO.fec_reservado1
  is 'Fecha: campo fecha reservado 1.';
comment on column IT.TA_CUENTAS_TMP_RO.fec_reservado2
  is 'Fecha: campo fecha reservado 2.';
comment on column IT.TA_CUENTAS_TMP_RO.cod_exc_cargo
  is 'Codigos de Excepciones de Cargos del Cierre.';
create index IT.IN_TC_COD_ADIFINIDAD1 on IT.TA_CUENTAS_TMP_RO (COD_AFINIDAD)
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
create index IT.IN_TC_COD_ENTIDAD1 on IT.TA_CUENTAS_TMP_RO (COD_ENTIDAD)
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
create index IT.IN_TC_COD_PERSONA1 on IT.TA_CUENTAS_TMP_RO (COD_PERSONA)
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
create index IT.IN_TC_DENOMINACION1 on IT.TA_CUENTAS_TMP_RO (DENOMINACION)
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
create index IT.IN_TC_NRO_CUENTA1 on IT.TA_CUENTAS_TMP_RO (NRO_CUENTA)
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
create index IT.IN_TC_NRO_DOCUMENTO1 on IT.TA_CUENTAS_TMP_RO (NRO_DOCUMENTO)
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
create index IT.IN_TC_SIT_CUENTA1 on IT.TA_CUENTAS_TMP_RO (SIT_CUENTA)
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


