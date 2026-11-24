begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, UBI_MENU, INA_CIERRE)
values ('BMAUTASI', 'AUTORIZACION ASIENTOS CONTABLES', 1, 2, 'Z:\GF10G\EXE', 'Z:\GF10G\FMB', 'Autorizar Mantenimiento de Asientos Contables', null, null, 'S', null, 'Contabilidad => Autorización de Asientos', 'N');
/
commit;
