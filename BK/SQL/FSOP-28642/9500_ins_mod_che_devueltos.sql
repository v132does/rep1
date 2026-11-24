begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
--
delete from ge_par_dinamicos d where d.parametro= 'MOD_CHE_DEVUELTOS';

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO)
values ('MOD_CHE_DEVUELTOS', 'S', 4);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO)
values ('MOD_CHE_DEVUELTOS', 'S', 3);

commit;
