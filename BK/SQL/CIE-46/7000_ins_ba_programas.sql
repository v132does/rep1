begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('PRG_PRO_DAT_TARJETAS', 'GENERACION DE DATOS TEMPORALES DE TARJETAS', 4, 1, 'BASE DE DATOS', 'BASE DE DATOS', 'Genera los datos temporales de las operaciones de tarjetas', null, null, 'S', null, null, 'N/A', null);
/
commit;
