BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:= 1; END;
/
insert into it.ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('TIP_OPE_SOB_LINEA1', '187,215,397,', null, null, null, null, 'ACASCO', to_date('26-06-2025 13:22:17', 'dd-mm-yyyy hh24:mi:ss'), 'ACASCO', to_date('26-06-2025 14:05:06', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into it.ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('TIP_OPE_SOB_LINEA2', '189,', null, null, null, null, 'ACASCO', to_date('26-06-2025 14:12:34', 'dd-mm-yyyy hh24:mi:ss'), 'ACASCO', to_date('26-06-2025 14:12:34', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
