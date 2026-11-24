BEGIN pre_ini_aplicacion; END; 
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA)
values ('PRE_CHE_ROG_VAL_DIVISOR', '1.005', 6, 668, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA)
values ('PRE_CHE_ROG_POR_IVA_CAL', '10', 6, 668, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA)
values ('PRE_CHE_ROG_POR_EXE_CAL', '90', 6, 668, null, null);

commit;
