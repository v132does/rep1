begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;  
/
insert into BA_PROGRAMAS (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('PRB_CON_TRA_HIS', 'TRANSP A HISTORICO GE_CON_TRANSACCIONES', 4, 6, 'BASE DE DATOS', 'BASE DE DATOS', 'Transpaso de registros al historico de ge_con_transacciones', null, 'Renegociacion de prestamos con Tasa Variable', 'N', null, null, 'BASE DE DATOS', 'N');

commit;
