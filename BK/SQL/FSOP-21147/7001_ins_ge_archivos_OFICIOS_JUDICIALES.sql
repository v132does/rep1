BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/

insert into ge_archivos (REFERENCIA, ARCHIVO, NRO_SECUENCIA, FOR_FECHA, USU_MODIFICACION, FEC_MODIFICACION, USU_INSERCION, FEC_INSERCION, LIN_INICIAL, LIN_FINAL, SEPARADOR, UTI_LOADER, POS_PROCESO, PRE_PROCESO)
values ('OFICIOS_JUDICIALES', 'OFICIOS JUDICIALES.CSV', '1', null, 'IT', to_date('07-01-2022 16:59:37', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('07-01-2022 16:59:37', 'dd-mm-yyyy hh24:mi:ss'), 2, null, ';', null, 'PRG_INH_PER_JUDICIALES', null);

commit;
