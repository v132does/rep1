begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('MVMTS_CAN_MAX_USU', '9');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('MVMTS_CAN_MIN_USU', '1');

commit;
