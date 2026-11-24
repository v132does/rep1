begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODALIDAD, COD_SUB_MODALIDAD)
values ('PRE_GAR_INF_FOGAPY', '32,33,34,39,40,41,45,46,47', null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODALIDAD, COD_SUB_MODALIDAD)
values ('PRE_MAD_INF_FOGAPY', 'S', 634, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODALIDAD, COD_SUB_MODALIDAD)
values ('PRE_MAD_INF_FOGAPY', 'S', 645, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODALIDAD, COD_SUB_MODALIDAD)
values ('PRE_MAD_INF_FOGAPY', 'S', 668, 6);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODALIDAD, COD_SUB_MODALIDAD)
values ('PRE_MAD_INF_FOGAPY', 'S', 668, 7);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODALIDAD, COD_SUB_MODALIDAD)
values ('PRE_MAD_INF_FOGAPY', 'S', 668, 8);

commit;
