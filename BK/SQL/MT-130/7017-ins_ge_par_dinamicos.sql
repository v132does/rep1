BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/

---Parámetro dinámico 
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('CJ_RET_DEP_TED', 'N', null, null, null, null, 'IT', to_date('29-04-2021 18:40:50', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('05-05-2022 09:00:12', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('COD_TRA_CTA_TED_DP_EF_TED_RET', '503', null, null, null, null, 'IT', to_date('03-05-2023 10:17:36', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-05-2023 10:17:36', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('COD_TRA_HIJO_DEP_EFE_TED_RET', '613', null, null, null, null, 'IT', to_date('03-05-2023 10:06:37', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-05-2023 10:06:37', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('COD_TRA_PADRE_DEP_EFE_TED_RET', '393', null, null, null, null, 'IT', to_date('03-05-2023 10:03:56', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-05-2023 10:03:56', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('CJ_OPE_DEP_RET', '03', null, null, null, null, 'IT', to_date('29-05-2023 18:00:17', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('29-05-2023 18:00:17', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('CJ_TIP_PERSONA', 'J', null, null, null, null, 'IT', to_date('29-05-2023 18:00:17', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('29-05-2023 18:00:17', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('CJ_TRA_PAD_EFE_LIB', '318', null, null, null, null, 'IT', to_date('02-08-2023 16:45:54', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('02-08-2023 16:45:54', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('CJ_TRA_HIJ_EFE_LIB', '318', null, null, null, null, 'IT', to_date('02-08-2023 16:45:53', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('02-08-2023 16:45:53', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('CJ_COD_RET_EFE_24', '10', null, null, null, null, 'IT', to_date('04-08-2023 14:40:59', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('04-08-2023 15:53:23', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('CJ_COD_RET_EFE_48', '11', null, null, null, null, 'IT', to_date('04-08-2023 15:53:23', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('04-08-2023 15:53:23', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('CJ_COD_RET_EFE_72', '12', null, null, null, null, 'IT', to_date('04-08-2023 15:53:23', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('04-08-2023 15:53:23', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
