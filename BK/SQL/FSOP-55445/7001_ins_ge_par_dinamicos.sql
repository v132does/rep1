Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_par_dinamicos (parametro, val_parametro) values ('IND_AUD_GENERAL','N');

commit;
