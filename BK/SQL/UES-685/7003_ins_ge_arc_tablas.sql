begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_arc_tablas (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, BORRAR)
values ('ALT_CTA_IPS', 'GE_CTA_IPS_EMP_TMP', 'ALTAS_IN_IPS.XLS', 1, 'N');

commit;
