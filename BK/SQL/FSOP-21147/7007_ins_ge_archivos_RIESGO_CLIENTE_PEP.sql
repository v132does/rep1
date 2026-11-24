BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/

insert into ge_archivos (REFERENCIA, ARCHIVO, NRO_SECUENCIA, FOR_FECHA, USU_MODIFICACION, FEC_MODIFICACION, USU_INSERCION, FEC_INSERCION, LIN_INICIAL, LIN_FINAL, SEPARADOR, UTI_LOADER, POS_PROCESO, PRE_PROCESO)
values ('RIESGO_CLIENTE_PEP', 'CLIENTESPEP.CSV', '1', null, 'IT', to_date('17-12-2021 01:11:54', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('17-12-2021 01:11:54', 'dd-mm-yyyy hh24:mi:ss'), 2, null, ';', null, 'PRG_INH_PER_PEP', null);

commit;
