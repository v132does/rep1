Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ge_arc_campos (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, DESCRIPCION, TIP_DATO, FORMATO, POS_INICIAL, LONGITUD, POS_DECIMAL, CAMPO, FUNCION)
values ('PRO_VEN_SOBREGIROS', 'CC_PRO_TMP_VENCIDOS', 'ARC_SOBREGIROS.CSV', 1, 'Numero de Cuenta', 'VARCHAR2', null, null, 10, null, 'NRO_CUENTA', null);

commit;
