Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('OPE_SUP_MON_DEPOSITO', '10000', null, null, null, 'USD', null);

insert into it.ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('OPE_SUP_MON_DEPOSITO', '75000000', null, null, null, 'GS', null);

commit;
