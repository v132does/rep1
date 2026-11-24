BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/

insert into ge_archivos (REFERENCIA, ARCHIVO, NRO_SECUENCIA, FOR_FECHA, USU_MODIFICACION, FEC_MODIFICACION, USU_INSERCION, FEC_INSERCION, LIN_INICIAL, LIN_FINAL, SEPARADOR, UTI_LOADER, POS_PROCESO, PRE_PROCESO)
values ('ONU_PER_FISICA', 'ONU_PER_FISICA.XLS', '1', null, 'IT', to_date('31-05-2021 10:47:05', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('31-05-2021 10:47:05', 'dd-mm-yyyy hh24:mi:ss'), 1, null, null, null, null, null);

commit;
