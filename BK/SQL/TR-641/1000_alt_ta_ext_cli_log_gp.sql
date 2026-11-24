-- Add/modify columns 
alter table IT.TA_EXT_CLI_LOG_GP add est_extracto varchar2(5);
-- Add comments to the columns 
comment on column IT.TA_EXT_CLI_LOG_GP.fec_cierre
  is 'Fecha de Cierre del Extracto.';
comment on column IT.TA_EXT_CLI_LOG_GP.nro_cuenta
  is 'Nro. de Cuenta de la TC.';
comment on column IT.TA_EXT_CLI_LOG_GP.nro_tarjeta
  is 'Nro. de Tarjeta.';
comment on column IT.TA_EXT_CLI_LOG_GP.lin_error
  is 'Nro. de linea que dio error.';
comment on column IT.TA_EXT_CLI_LOG_GP.nom_archivo
  is 'Nombre del archivo procesado.';
comment on column IT.TA_EXT_CLI_LOG_GP.con_movimiento
  is 'Indica si corresponde a un extracto con o sin movimiento (S/N).';
comment on column IT.TA_EXT_CLI_LOG_GP.err_log
  is 'Error generado en el proceso.';
comment on column IT.TA_EXT_CLI_LOG_GP.usu_insercion
  is 'Usuario que inserto el registro.';
comment on column IT.TA_EXT_CLI_LOG_GP.fec_insercion
  is 'Fecha de insercion del registro.';
comment on column IT.TA_EXT_CLI_LOG_GP.usu_modificacion
  is 'Usuario que modifico el registro.';
comment on column IT.TA_EXT_CLI_LOG_GP.fec_modificacion
  is 'Fecha de modificacion del registro.';
comment on column IT.TA_EXT_CLI_LOG_GP.est_extracto
  is 'Estado del extracto en el S3 - OK/Error.';
