Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('PRT_PAS_VENCIDAS', 'PASE A VENC. TARJETAS', 4, 15, 'C:', 'C:', 'Pasa a Operación vencida la tarjeta de credito contenidas en el archivo TAR_PASE_VENCIDA.', null, null, 'N', null, null, 'BASE DATOS', null);

commit;
