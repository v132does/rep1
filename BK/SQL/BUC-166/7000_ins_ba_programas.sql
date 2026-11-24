Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('PRT_DEV_CAR_TARJETAS', 'DEV.CARGOS TARJETAS', 4, 15, 'C:', 'C:', 'Devolución de Cargos Tarjetas, utilizado en importacion del archivo TAR_DEV_CARGOS.', null, null, 'N', null, null, 'BASE DATOS', null);

commit;
