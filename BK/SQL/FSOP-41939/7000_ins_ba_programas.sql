begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, UBI_MENU, INA_CIERRE)
values ('BLIMPRED', 'IMPRESIÓN DE RECIBOS POR RANGO DE FECHAS', 50, 2, 'Z:\GF10G\EXE', 'Z:\GESTION FINANCIERA\CONTABILIDAD\FORMS', 'Impresión de Recibos por Rango de Fechas', null, null, 'N', null, 'Informes/General/Recibos/Impresión de Recibos por Rango de Fechas', 'N');
/
commit;