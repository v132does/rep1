Begin pre_ini_aplicacion; end; 
/
insert into ge_tas_rangos (COD_TASA, FEC_VIGENCIA, COD_OFICINA, COD_MONEDA, COD_MODULO, COD_MODALIDAD, NRO_CUENTA, VAL_HASTA, VAL_TASA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD, NO_ACTUALIZABLE, VAL_EXTENSION, COD_PERSONA, OBSERVACIONES, FEC_VENCIMIENTO, COD_ENTE)
values (580, to_date('01-01-2024', 'dd-mm-yyyy'), null, 'GS', null, null, null, 999999999999.00, 5.0000, 'IT', to_date('20-09-2024 14:20:02', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('20-09-2024 14:20:02', 'dd-mm-yyyy hh24:mi:ss'), null, 'N', null, null, null, null, null);

insert into ge_tas_rangos (COD_TASA, FEC_VIGENCIA, COD_OFICINA, COD_MONEDA, COD_MODULO, COD_MODALIDAD, NRO_CUENTA, VAL_HASTA, VAL_TASA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD, NO_ACTUALIZABLE, VAL_EXTENSION, COD_PERSONA, OBSERVACIONES, FEC_VENCIMIENTO, COD_ENTE)
values (580, to_date('01-01-2024', 'dd-mm-yyyy'), null, 'USD', null, null, null, 999999999.00, 5.0000, 'IT', to_date('20-09-2024 14:20:02', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('20-09-2024 14:20:02', 'dd-mm-yyyy hh24:mi:ss'), null, 'N', null, null, null, null, null);

commit;
