begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('TIP_MOD_CAV_CANCELA', '31,41,37,38,39,334,', null, null, null, null, 'ACASCO', to_date('18-12-2023 10:53:29', 'dd-mm-yyyy hh24:mi:ss'), 'ACASCO', to_date('18-12-2023 11:41:22', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('TIP_OPE_CDA_CANCELA', '156,138,306,102,298,292,', null, null, null, null, 'ACASCO', to_date('18-12-2023 10:53:30', 'dd-mm-yyyy hh24:mi:ss'), 'ACASCO', to_date('18-12-2023 11:41:22', 'dd-mm-yyyy hh24:mi:ss'), null);
commit;
