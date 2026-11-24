begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('POR_UTI_SOL_CHE', '100');
/
commit;
