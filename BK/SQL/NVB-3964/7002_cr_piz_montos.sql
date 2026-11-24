begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into it.cr_piz_montos (COD_MODULO, COD_MODALIDAD, COD_MONEDA, MTO_DESDE, MTO_HASTA, COD_SUB_MODALIDAD)
values (10, 127, 'USD', 1000.00, 999999999.00, null);

insert into it.cr_piz_montos (COD_MODULO, COD_MODALIDAD, COD_MONEDA, MTO_DESDE, MTO_HASTA, COD_SUB_MODALIDAD)
values (10, 149, 'GS', 10000000.00, 999999999999.00, null);

insert into it.cr_piz_montos (COD_MODULO, COD_MODALIDAD, COD_MONEDA, MTO_DESDE, MTO_HASTA, COD_SUB_MODALIDAD)
values (10, 149, 'USD', 1000.00, 999999999.00, null);
/
commit;
/