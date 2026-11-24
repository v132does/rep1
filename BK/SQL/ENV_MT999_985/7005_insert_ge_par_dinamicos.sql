begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('COD_CIR_ENV_MT999_SIPAP', '995', null, null, null, null, 'BROLON', to_date('31-07-2025 15:48:52', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('04-08-2025 09:36:16', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
