begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/ 
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('USU_ONB_PERSONAS', ',ONBOARDING,PERSONS,', null, null, null, null, 'CURIARTE', to_date('02-07-2024 13:12:41', 'dd-mm-yyyy hh24:mi:ss'), 'CURIARTE', to_date('02-07-2024 13:12:41', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
