Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('FEC_CIE_MENSUAL', '31/10/2024');

commit;
