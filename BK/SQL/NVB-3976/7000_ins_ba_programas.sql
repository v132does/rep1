BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('GPELIONB', 'ELIMINACION DE ONBOARDING PERSONAS', 1, 1, 'Z:\GF10G\EXE', 'Z:\GF10G\FMB', 'Permite la eliminación Onboarding de un Cliente de manera definitiva del Sistema.', null, null, 'S', null, null, 'Operaciones/Eliminación/Onboarding', null);

COMMIT;
