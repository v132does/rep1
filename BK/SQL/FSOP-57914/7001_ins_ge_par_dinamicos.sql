BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('CJ_VAL_USD_CAJA', 'S');

commit;
