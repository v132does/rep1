-- Create table
create global temporary table IT.GE_EXT_CLI_MOVIMIENTOS_TMP
(
  mto_debito       NUMBER(18,2),
  mto_credito      NUMBER(18,2),
  ind_acumula      VARCHAR2(1),
  cod_tra_padre    NUMBER(4),
  cod_persona      VARCHAR2(10),
  fec_extracto     DATE,
  cod_extracto     NUMBER(3),
  nro_cuenta       VARCHAR2(15),
  fec_movimiento   DATE,
  fec_valor        DATE,
  hor_movimiento   VARCHAR2(8),
  nro_documento    NUMBER(15),
  cod_modulo       NUMBER(3),
  cod_modalidad    NUMBER(3),
  usu_insercion    VARCHAR2(10) default SUBSTR(USER,1,10),
  fec_insercion    DATE default SYSDATE,
  usu_modificacion VARCHAR2(10) default SUBSTR(USER,1,10),
  fec_modificacion DATE default SYSDATE,
  fre_extracto     VARCHAR2(1),
  nro_secuencia    NUMBER(3),
  cod_ofi_origen   NUMBER(3),
  concepto         VARCHAR2(100)
)
on commit preserve rows;
-- Add comments to the table 
comment on table IT.GE_EXT_CLI_MOVIMIENTOS_TMP
  is 'Detalle de Cuentas del Extracto provisorios.';
-- Add comments to the columns 
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.mto_debito
  is 'Importe del Debito.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.mto_credito
  is 'Importe del Credito.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.ind_acumula
  is 'Indicador de acumlacion (S= SI / N= NO).';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.cod_tra_padre
  is 'Codigo de Transaccion Padre.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.cod_persona
  is 'Codigo del Cliente.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.fec_extracto
  is 'Fecha del Extracto.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.cod_extracto
  is 'Codigo de Extracto.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.nro_cuenta
  is 'Numero de Cuenta.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.fec_movimiento
  is 'Fecha del Movimiento.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.fec_valor
  is 'Fecha Valor.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.hor_movimiento
  is 'Hora del Movimiento.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.nro_documento
  is 'Numero de Documento.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.cod_modulo
  is 'Modulo de la Cuenta.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.cod_modalidad
  is 'Modalidad de la Cuenta.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.usu_insercion
  is 'Usuario que realizo la insercion del registro.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.fec_insercion
  is 'Fecha en que se inserto el registro.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.usu_modificacion
  is 'Usuario que realizo la ultima modificacion en el registro.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.fec_modificacion
  is 'Fecha en que se realizo la ultima modificacion en el registro.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.fre_extracto
  is 'Frecuencia de Extracto (D, S, M).';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.nro_secuencia
  is 'Numero de secuencia.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.cod_ofi_origen
  is 'Codigo de oficina origen del movimiento.';
comment on column IT.GE_EXT_CLI_MOVIMIENTOS_TMP.concepto
  is 'Concepto';
-- Create/Recreate indexes 
create index IN_GECMT_COD_TRA_PADRE on IT.GE_EXT_CLI_MOVIMIENTOS_TMP (COD_TRA_PADRE, COD_MODULO, COD_MODALIDAD);
create index IN_GECMT_NRO_CUENTA on IT.GE_EXT_CLI_MOVIMIENTOS_TMP (COD_PERSONA, FEC_EXTRACTO, COD_EXTRACTO, NRO_CUENTA, FEC_INSERCION);
create index IN_GECMT_USU_INSERCION on IT.GE_EXT_CLI_MOVIMIENTOS_TMP (USU_INSERCION);


