begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into it.pr_rub_eco_modalidades (COD_MODULO, COD_MODALIDAD, COD_RUB_ECONOMICO, REFERENCIA)
values (10, 149, '659900', 904);
/
commit;
/