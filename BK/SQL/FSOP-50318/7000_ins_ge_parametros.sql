begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
/

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_DEFECTO, MODIFICABLE)
values ('ENV_SER_BAS_POSITIVA', 'ENVIA WS DE BASE POSITIVA', 'GE_PAR_DINAMICOS', null, 'Indica si está habilitado el envío por WS de Base positiva', null, null, 'FENCISO', to_date('02-05-2025 16:24:11', 'dd-mm-yyyy hh24:mi:ss'), 'FENCISO', to_date('02-05-2025 16:24:11', 'dd-mm-yyyy hh24:mi:ss'), null, null);

commit;
