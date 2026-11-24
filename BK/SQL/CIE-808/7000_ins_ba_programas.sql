begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION,  OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, UBI_MENU, INA_CIERRE)
values ('PRG_VAL_CONTROLES', 'PROCESO CONTROLES', 4, 6, 'base de datos', 'base de datos', 'Control de procesos', null, null, 'N', null, 'base de datos', 'N');

commit;
