Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into GE_PAR_DINAMICOS (PARAMETRO, VAL_PARAMETRO)
values ('SNP_TRA_CLE_USD_P', '199');

insert into GE_PAR_DINAMICOS (PARAMETRO, VAL_PARAMETRO)
values ('SNP_TRA_CLE_USD_G', '197');

COMMIT;
