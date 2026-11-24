Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_archivos (REFERENCIA, ARCHIVO, NRO_SECUENCIA, FOR_FECHA, LIN_INICIAL, LIN_FINAL, SEPARADOR, UTI_LOADER, POS_PROCESO, PRE_PROCESO)
values ('TAR_DEV_CARGOS', 'TAR_DEV_CARGOS.CSV', '1', null, 2, null, ';', null, 'PRT_DEV_CAR_TARJETAS', null);

commit;
