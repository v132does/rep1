begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_archivos (REFERENCIA, ARCHIVO, NRO_SECUENCIA, FOR_FECHA, USU_MODIFICACION, FEC_MODIFICACION, USU_INSERCION, FEC_INSERCION, LIN_INICIAL, LIN_FINAL, SEPARADOR, UTI_LOADER, POS_PROCESO, PRE_PROCESO)
values ('PER_WORKFLOW', 'PER_WORKFLOW.CSV', '1', null, 'CURIARTE', to_date('26-06-2024 16:30:07', 'dd-mm-yyyy hh24:mi:ss'), 'CURIARTE', to_date('26-06-2024 11:55:41', 'dd-mm-yyyy hh24:mi:ss'), 2, null, ';', null, 'PRG_ACT_WORKFLOW', null);

commit;
