begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ge_tas_fechas (COD_TASA, FEC_VIGENCIA, COD_OFICINA, COD_MONEDA, COD_MODULO, COD_MODALIDAD, NRO_CUENTA, VAL_MAXIMO, VAL_MINIMO, VAL_BASE, VAL_TASA, APLICAR, FEC_VENCIMIENTO, OBSERVACIONES, VAL_EXTENSION, TIP_IVA, COD_PERSONA, COD_SUB_MODALIDAD, NO_ACTUALIZABLE, COD_ENTE)
values (530, to_date('01-02-2012', 'dd-mm-yyyy'), null, 'GS', 3, 38, null, null, null, 0.00, 0, 'ST', null, null, null, null, null, null, null, null);

insert into ge_tas_fechas (COD_TASA, FEC_VIGENCIA, COD_OFICINA, COD_MONEDA, COD_MODULO, COD_MODALIDAD, NRO_CUENTA, VAL_MAXIMO, VAL_MINIMO, VAL_BASE, VAL_TASA, APLICAR, FEC_VENCIMIENTO, OBSERVACIONES, VAL_EXTENSION, TIP_IVA, COD_PERSONA, COD_SUB_MODALIDAD, NO_ACTUALIZABLE, COD_ENTE)
values (530, to_date('01-02-2012', 'dd-mm-yyyy'), null, 'USD', 3, 38, null, null, null, 0.00, 0, 'ST', null, null, null, null, null, null, null, null);

insert into ge_tas_fechas (COD_TASA, FEC_VIGENCIA, COD_OFICINA, COD_MONEDA, COD_MODULO, COD_MODALIDAD, NRO_CUENTA, VAL_MAXIMO, VAL_MINIMO, VAL_BASE, VAL_TASA, APLICAR, FEC_VENCIMIENTO, OBSERVACIONES, VAL_EXTENSION, TIP_IVA, COD_PERSONA, COD_SUB_MODALIDAD, NO_ACTUALIZABLE, COD_ENTE)
values (602, to_date('01-01-2012', 'dd-mm-yyyy'), null, 'GS', 3, 38, null, null, null, 0.00, 0.5, 'ST', null, null, null, null, null, null, 'N', null);

insert into ge_tas_fechas (COD_TASA, FEC_VIGENCIA, COD_OFICINA, COD_MONEDA, COD_MODULO, COD_MODALIDAD, NRO_CUENTA, VAL_MAXIMO, VAL_MINIMO, VAL_BASE, VAL_TASA, APLICAR, FEC_VENCIMIENTO, OBSERVACIONES, VAL_EXTENSION, TIP_IVA, COD_PERSONA, COD_SUB_MODALIDAD, NO_ACTUALIZABLE, COD_ENTE)
values (602, to_date('01-01-2012', 'dd-mm-yyyy'), null, 'USD', 3, 38, null, null, null, 0.00, 0.5, 'ST', null, null, null, null, null, null, 'N', null);


commit;
