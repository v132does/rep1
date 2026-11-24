Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ge_arc_tablas (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, BORRAR)
values ('PRO_VEN_SOBREGIROS', 'CC_PRO_TMP_VENCIDOS', 'ARC_SOBREGIROS.CSV', 1, 'S');

commit;
