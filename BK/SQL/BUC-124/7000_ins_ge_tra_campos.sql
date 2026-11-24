Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_tra_campos (COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, NRO_ORDEN, COD_CAMPO, TIP_CAMPO, LON_CAMPO, TIP_DESPLIEGUE, LON_DESPLIEGUE, NRO_LINEA, NRO_COLUMNA, FORMATO, ALINEACION, ETIQUETA, NRO_LIN_ETIQUETA, NRO_COL_ETIQUETA, VAL_DEFECTO, VAL_POSIBLES, VAL_MINIMO, VAL_MAXIMO, TIP_DATO, VALIDADO, AYUDA)
values (355, 9, 91, 14, 'HORA', 'X', 100, 'T', 0, 1, 16, null, 'I', null, 7, 2, null, null, null, null, 'I', 'S', NULL);

insert into ge_tra_campos (COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, NRO_ORDEN, COD_CAMPO, TIP_CAMPO, LON_CAMPO, TIP_DESPLIEGUE, LON_DESPLIEGUE, NRO_LINEA, NRO_COLUMNA, FORMATO, ALINEACION, ETIQUETA, NRO_LIN_ETIQUETA, NRO_COL_ETIQUETA, VAL_DEFECTO, VAL_POSIBLES, VAL_MINIMO, VAL_MAXIMO, TIP_DATO, VALIDADO, AYUDA)
values (355, 9, 91, 15, 'OPCION', 'X', 100, 'T', 0, 1, 16, null, 'I', null, 7, 2, null, null, null, null, 'D', 'S', '¿?');

update ge_tra_campos
set    validado = 'S'
where  cod_transaccion = 355
and    cod_campo       = 'IMP_CHEQUE';

commit;
