Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD)
values ('COD_MAD_ACT_FEC_INICIO', 'S', 6, 61);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD)
values ('COD_MAD_ACT_FEC_INICIO', 'S', 6, 609);

commit;
