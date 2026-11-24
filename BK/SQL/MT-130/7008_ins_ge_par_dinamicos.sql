begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('CJ_TRA_PAD_DEP_OEN', '1127');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('CJ_TRA_HIJ_DEP_OEN', '4614');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('CJ_TRA_HIJ_DEP_OEN_TED', '503');

commit;
