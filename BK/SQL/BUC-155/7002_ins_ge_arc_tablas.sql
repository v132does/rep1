Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_arc_tablas (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, BORRAR)
values ('TAR_PASE_VENCIDA', 'TA_MOV_ESPECIALES_TMP', 'TAR_PASE_VENCIDA.CSV', 1, 'S');

commit;
