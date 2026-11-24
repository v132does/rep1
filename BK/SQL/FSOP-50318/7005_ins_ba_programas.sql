begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
/

insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('PRG_GEN_EQU_DATOS', 'GENERACION DE DATOS PARA BASE POSITIVA', 8, 12, 'BASE DE DATOS', 'BASE DE DATOS', 'Proceso mensual de generación de datos para Base Positiva equifax', null, null, 'LMENDOZA', to_date('30-06-2025 06:27:56', 'dd-mm-yyyy hh24:mi:ss'), 'LMENDOZA', to_date('01-07-2025 06:27:56', 'dd-mm-yyyy hh24:mi:ss'), 'N', null, null, 'Ejecutado en proceso independiente', 'N');

commit;
