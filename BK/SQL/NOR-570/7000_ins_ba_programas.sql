begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/

insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, OPE_MOD_CERRADO, UBI_MENU)
values ('PRS_GEN_DAT_DIVERSOS', 'GENERACION DE DATOS PARA INFORME DE DIVERSOS', 4, 2, 'BASE DE DATOS', 'BASE DE DATOS', 'Genera los datos para la insercion a sb_diversos', 'N', 'Proceso Independiente');

insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, OPE_MOD_CERRADO, UBI_MENU)
values ('PRS_GEN_ARC_DIVERSOS', 'GENERACION ARCHIVO DE DIVERSOS', 4, 2, 'BASE DE DATOS', 'BASE DE DATOS', 'Genera el archivo con datos divesos a ser enviado al bcp ', 'N', 'Proceso Independiente');

commit;
