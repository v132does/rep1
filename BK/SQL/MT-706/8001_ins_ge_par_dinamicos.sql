BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
--Parámetros
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('CJ_VAL_USD_TED', 'S', null, null, null, null, 'IT', to_date('10-07-2025 01:29:37', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('10-07-2025 01:29:37', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('IMP_MAX_DEP_FIS', '10000', null, null, null, null, 'IT', to_date('10-07-2025 01:36:16', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('10-07-2025 01:36:16', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('IMP_MAX_DEP_JUR', '50000', null, null, null, null, 'IT', to_date('10-07-2025 01:36:16', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('10-07-2025 01:36:16', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
