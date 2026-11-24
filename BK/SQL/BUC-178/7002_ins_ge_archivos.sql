Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ge_archivos (REFERENCIA, ARCHIVO, NRO_SECUENCIA, FOR_FECHA, LIN_INICIAL, LIN_FINAL, SEPARADOR, UTI_LOADER, POS_PROCESO, PRE_PROCESO)
values ('PRO_VEN_SOBREGIROS', 'ARC_SOBREGIROS.CSV', '1', null, 2, null, ';', 'N', 'PRG_BLO_VEN_SOBREGIROS', null);

commit;
