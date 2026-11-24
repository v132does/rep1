create table IT.CC_CHE_DEV_ERRORES
(
  nro_cuenta       VARCHAR2(15),
  nro_cheque       NUMBER(15),
  msj_error        VARCHAR2(100),
  importe          NUMBER(18,2) default 0,
  cod_banco        NUMBER(3),
  usu_insercion    VARCHAR2(10) default SUBSTR(USER,1,10) not null,
  fec_insercion    DATE default SYSDATE not null,
  usu_modificacion VARCHAR2(10) default SUBSTR(USER,1,10) not null,
  fec_modificacion DATE default SYSDATE not null,
  tip_importe      NUMBER(1)
)
;
comment on table IT.CC_CHE_DEV_ERRORES
  is 'Registro de errores en la carga de Cheques devueltos.';
comment on column IT.CC_CHE_DEV_ERRORES.nro_cuenta
  is 'Numero de cuenta.';
comment on column IT.CC_CHE_DEV_ERRORES.nro_cheque
  is 'Numero de cheque.';
comment on column IT.CC_CHE_DEV_ERRORES.msj_error
  is 'Mensaje de error.';
comment on column IT.CC_CHE_DEV_ERRORES.importe
  is 'Importe.';
comment on column IT.CC_CHE_DEV_ERRORES.cod_banco
  is 'Codigo de banco.';
comment on column IT.CC_CHE_DEV_ERRORES.usu_insercion
  is 'Usuario que realizo la insercion del registro.';
comment on column IT.CC_CHE_DEV_ERRORES.fec_insercion
  is 'Fecha en que se inserto el registro.';
comment on column IT.CC_CHE_DEV_ERRORES.usu_modificacion
  is 'Usuario que realizo la ultima modificacion en el registro.';
comment on column IT.CC_CHE_DEV_ERRORES.fec_modificacion
  is 'Fecha en que se realizo la ultima modificacion en el registro.';
comment on column IT.CC_CHE_DEV_ERRORES.tip_importe
  is 'Tipo de Importe.';
