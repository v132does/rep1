begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_archivos (REFERENCIA, ARCHIVO, NRO_SECUENCIA, FOR_FECHA, LIN_INICIAL, LIN_FINAL, SEPARADOR, UTI_LOADER, POS_PROCESO, PRE_PROCESO)
values ('ALT_CTA_IPS', 'ALTAS_IN_IPS.XLS', '1', 'DDMMYYYY', 3, null, null, 'N', null, null);

commit;


