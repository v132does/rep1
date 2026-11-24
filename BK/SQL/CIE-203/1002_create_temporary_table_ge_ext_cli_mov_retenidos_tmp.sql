-- Create table
create global temporary table IT.GE_EXT_CLI_MOV_RETENIDOS_TMP
(
  fec_extracto     DATE,
  cod_retencion    NUMBER(3),
  nro_documento    NUMBER(15),
  cod_persona      VARCHAR2(10),
  monto            NUMBER(18,2),
  fec_movimiento   DATE,
  fec_liberacion   DATE,
  nro_cuenta       VARCHAR2(15),
  cod_modulo       NUMBER(3),
  cod_modalidad    NUMBER(3),
  usu_insercion    VARCHAR2(10) default SUBSTR(USER,1,10),
  fec_insercion    DATE default SYSDATE,
  usu_modificacion VARCHAR2(10) default SUBSTR(USER,1,10),
  fec_modificacion DATE default SYSDATE,
  fre_extracto     VARCHAR2(1),
  cod_extracto     NUMBER(3)
)
on commit preserve rows;
-- Add comments to the table 
comment on table IT.GE_EXT_CLI_MOV_RETENIDOS_TMP
  is 'Detalle de Depositos a confirmar en extractos provisorios.';
-- Add comments to the columns 
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.fec_extracto
  is 'Fecha del extracto.';
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.cod_retencion
  is 'Codigo de retencion.';
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.nro_documento
  is 'Nro de boleta.';
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.cod_persona
  is 'Codigo de la persona.';
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.monto
  is 'Monto de la boleta.';
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.fec_movimiento
  is 'Fecha del movimiento.';
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.fec_liberacion
  is 'Fecha de liberacion del deposito.';
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.nro_cuenta
  is 'Nro de cuenta.';
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.cod_modulo
  is 'Codigo del modulo de la cuenta.';
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.cod_modalidad
  is 'Codigo de la modalidad de la cuenta.';
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.usu_insercion
  is 'Usuario que inserto el registro.';
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.fec_insercion
  is 'Fecha de insercion.';
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.usu_modificacion
  is 'usuario que modifico el registro.';
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.fec_modificacion
  is 'Fecha de modificacion.';
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.fre_extracto
  is 'Frecuencia de extracto.';
comment on column IT.GE_EXT_CLI_MOV_RETENIDOS_TMP.cod_extracto
  is 'Codigo de extracto.';
-- Create/Recreate indexes 
create index IN_GECMT_NRO_BOLETA on IT.GE_EXT_CLI_MOV_RETENIDOS_TMP (COD_PERSONA, FEC_EXTRACTO, FRE_EXTRACTO, COD_EXTRACTO, NRO_CUENTA);
  
