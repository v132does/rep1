begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('CAN_MAX_DOC_FACTURY', '10000', null, null, null, null, 'FENCISO', to_date('16-01-2024 15:40:17', 'dd-mm-yyyy hh24:mi:ss'), 'FENCISO', to_date('16-01-2024 15:40:17', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;