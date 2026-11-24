BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END; 
/

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('CORPS_CAN_MAX_USU_ENV', '10', null, null, null, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('CORPS_CAN_MIN_USU_ENV', '1', null, null, null, null, null);

commit;
