begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
/

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('ENV_SER_BAS_POSITIVA', 'N', null, null, null, null, 'FENCISO', to_date('02-05-2025 16:27:34', 'dd-mm-yyyy hh24:mi:ss'), 'FENCISO', to_date('02-05-2025 16:27:34', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
