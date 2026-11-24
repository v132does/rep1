Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, OPE_MOD_CERRADO, UBI_MENU, INA_CIERRE)
values ('PRG_ACT_PARAMETROS', 'ACTUALIZA PARAMETROS', 4, 1, 'BASE DE DATOS', 'BASE DE DATOS', 'Actualiza parametros durante el cierre.', 'S', 'Proceso de Cierre diario', 'N');

commit;
