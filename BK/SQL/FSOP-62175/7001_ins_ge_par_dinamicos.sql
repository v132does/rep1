Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('COD_GRU_TRA_UMBRAL_GS', '111');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('COD_GRU_TRA_UMBRAL_J', '112');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('COD_GRU_TRA_UMBRAL_GS_J', '113');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('IMP_MAX_DEP_F_GS', '20000');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('IMP_MAX_DEP_J_GS', '50000');

commit;
