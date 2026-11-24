begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('PRA_PRO_AHO_PROGRAMADO', 'PROVISIÓN DE INTERESES AHORRO PROGRAMADO', 4, 3, 'BASE DE DATOS', 'BASE DE DATOS', 'Este proceso provisiona los intereses de los ahorros programados en el cierre de dia', null, null, 'S', null, null, '.', 'N');

commit;
