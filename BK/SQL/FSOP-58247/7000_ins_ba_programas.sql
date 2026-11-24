Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, UBI_MENU, INA_CIERRE)
values ('GMCONUMB', 'VERIFICACION DE OPERAC.CAJA', 50, 1, 'Z:\GF10G\EXE', 'Z:\GF10G\FMB', 'Permite la confirmación de Operaciones pendientes de Caja por Umbral.', null, null, 'N', null, 'General => Operaciones => Autorización de Umbral Superado', null);

commit;
