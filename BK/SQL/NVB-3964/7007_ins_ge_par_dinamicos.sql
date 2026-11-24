begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into it.ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('SIB_CRC_MAD_EXC_ARCHIVO', 'S', 10, 149, null, null, null);

insert into it.ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('SIG_NROCTA', '149000000', 10, 149, null, null, null);

insert into it.ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('REP_TIP_NEGOCIACIONES', 'S', 10, 149, null, null, null);
/
commit;
/
