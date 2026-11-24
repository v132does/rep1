begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('ACT_DEB_AUT_PAGSUE', 'N');

commit ;
