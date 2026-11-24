begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end; 
/
insert into GE_PAR_DINAMICOS (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('SPI_CAN_MIN_USU_ENV', '1', null, null, null, null, 'BROLON', to_date('18-12-2023 18:39:41', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('18-12-2023 18:39:41', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into GE_PAR_DINAMICOS (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('SPI_CAN_MAX_USU_ENV', '10', null, null, null, null, 'BROLON', to_date('19-12-2023 22:48:40', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('19-12-2023 22:48:40', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
