begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('FEC_MAX_REV_TIG', '180', null, null, null, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('COD_TRA_COM_TIGO_CM', '9196', 4, 41, null, null, null);

commit;