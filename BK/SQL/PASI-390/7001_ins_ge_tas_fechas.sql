Begin pre_ini_aplicacion; end; 
/
insert into ge_tas_fechas (COD_TASA, FEC_VIGENCIA, COD_OFICINA, COD_MONEDA, COD_MODULO, COD_MODALIDAD, NRO_CUENTA, VAL_MAXIMO, VAL_MINIMO, VAL_BASE, VAL_TASA, APLICAR, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, FEC_VENCIMIENTO, OBSERVACIONES, VAL_EXTENSION, TIP_IVA, COD_PERSONA, COD_SUB_MODALIDAD, NO_ACTUALIZABLE, COD_ENTE)
values (343, to_date('24-03-2021', 'dd-mm-yyyy'), null, null, 10, 150, null, null, null, 0.00, 0.5000, 'IN', 'IT', to_date('24-03-2025 16:33:05', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('24-03-2025 16:33:05', 'dd-mm-yyyy hh24:mi:ss'), null, null, null, null, null, null, 'N', null);

commit;
