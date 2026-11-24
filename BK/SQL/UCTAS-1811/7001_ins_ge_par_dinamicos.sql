begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD)
values ('COD_SUB_MAD_SIN_PER', '2,', 3, 334);

commit;
