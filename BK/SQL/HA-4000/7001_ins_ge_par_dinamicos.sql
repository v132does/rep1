Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('COD_CIR_NOT_ONB', ',37,38,39,41,42,44,');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('DIR_COR_TAR_ONB', 'workflow@ueno.com.py');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('HAB_NOT_CIR_ONB', 'S');


commit;