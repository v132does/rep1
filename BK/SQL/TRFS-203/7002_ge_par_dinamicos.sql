begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end; 
/
insert into GE_PAR_DINAMICOS (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('SPI_CAN_MIN_USU_APN', '1', null, null, null, null,  null);

insert into GE_PAR_DINAMICOS (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('SPI_CAN_MAX_USU_APN', '10', null, null, null, null,  null);

commit;
