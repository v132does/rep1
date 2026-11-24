Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD)
values ('PRP_RRR_MOD_MED_TRAN', 'S', 6, 970);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD)
values ('PRP_RRR_MOD_MED_TRAN', 'S', 6, 978);

COMMIT;
