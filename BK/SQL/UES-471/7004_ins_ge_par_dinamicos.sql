begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('COD_MAD_PADRE_DAS', '31', null, null, null, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('COD_MOD_PADRE_DAS', '3', null, null, null, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('COD_TRA_PADRE_DAS', '9834', null, null, null, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('COD_TRA_DEB_DAS', '9819', 3, 31, null, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('COD_TRA_DEB_DAS', '9819', 3, 334, null, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('COD_TRA_DEB_DAS', '9820', 4, 41, null, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('COD_TRA_CRE_DAS', '602', null, null, null, null, null);


insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('COD_TRA_DEBCOM_DAS', '9837', 3, 31, null, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('COD_TRA_DEBCOM_DAS', '9837', 3, 334, null, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('COD_TRA_DEBCOM_DAS', '9839', 4, 41, null, null, null);


commit;
