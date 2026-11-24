begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO)
values ('HAB_CTA_CDA_DESMATERIALIZADO', 'N', 3);
commit;
