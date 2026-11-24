begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('GE_VAL_NIV_PARALELISMO', '6', null, null, null, null,  null);
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('GE_ACT_PARALEL_RES37', 'S', null, null, null, null,  null);
/
commit;--2 registros
