begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('CJ_TRA_HIJ_OTE_CLI', '3683');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('CJ_TRA_HIJ_OTE_TED', '602');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('CJ_TRA_PAD_OTE', '1126');

commit;
