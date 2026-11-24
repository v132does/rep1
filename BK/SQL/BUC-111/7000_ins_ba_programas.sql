begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('GLESPTMP', 'REPORTE EXTRACTO A REQUERIMIENTO ESPECIAL', 3, 1, 'Z:\GF10G\EXE', 'Z:\GF10G\RDF', 'Extracto a Requerimiento Especial', null, null, 'S', null, null, 'Informes/Extractos/Extracto a Requerimiento Especial', null);

insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('GPEXTRES', 'EXTRACTO A REQUERIMIENTO ESPECIAL', 1, 1, 'Z:\GF10G\EXE', 'Z:\GF10G\FMB
', 'Permite procesar Extracto a Requerimiento Especial.', null, null, 'S', null, null, 'Informes/Extractos/Extracto a Requerimiento Especial', null);

commit;
