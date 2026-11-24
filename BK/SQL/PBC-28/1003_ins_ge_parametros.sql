-- Insert a GE_PARAMETROS
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('FEC_VOL_ENV_CORREOS', 'FECHAS DE VOLCADO CORREOS ENVIADOS', 'GE_PAR_DINAMICOS', null, 'TCASCO', to_date('04-04-2024 13:59:23', 'dd-mm-yyyy hh24:mi:ss'), 'TCASCO', to_date('04-04-2024 13:59:23', 'dd-mm-yyyy hh24:mi:ss'), 'Fechas en la que se realizara el volcado de datos de la tabla ba_env_correos a su historico, formato de ejemplo: 01,12,30', null, null, 'N', null);

commit;
