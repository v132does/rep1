begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; pae_cnf.G_PROGRAMA := 'GPPROFIN'; end; 
/
----------
--eliminamos el 232 (COBRO POR MANTENIMIENTO PAQUETE PAG_CAR.PR_DEB_CRE_BATCH(21)) del cierre
delete from ge_procesos_det a
 where a.cod_proceso = 11
   and nro_orden = 232; --1 registro afectado
commit;
----------
--mudamos del orden 231 al orden 232 el proceso PAA_DEP.PR_AH_PROGRAMADO
update ge_procesos_det a
   set nro_orden = 232
 where a.cod_proceso = 11
   and nro_orden = 231; --1 registro afectado
commit;
----------
--mudamos del orden 230 al 231 el proceso PRC_ACT_SAL_MENSUAL
update ge_procesos_det a
   set nro_orden = 231
 where a.cod_proceso = 11
   and nro_orden = 230; --1 registro afectado
commit;
----------
--insercion de los procesos nuevos a ba_programas
INSERT INTO BA_PROGRAMAS (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, OBSERVACION,OPE_MOD_CERRADO, UBI_MENU, INA_CIERRE)
VALUES ('PRA_CAP_CTA_VIS_PREVIO', 'CUENTAS A CAPITALIZAR', 4, 3, 'BASE DE DATOS', 'BASE DE DATOS', 'Procedimiento que dentifica las cuentas de ahorro vista que capitalizan',null,'S', ' ', 'N');
commit;

INSERT INTO BA_PROGRAMAS (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, OBSERVACION,OPE_MOD_CERRADO, UBI_MENU, INA_CIERRE)
VALUES ('PRA_CAP_CTA_PREVIO_CIERRE', 'CUENTAS A CAPITALIZAR', 4, 3, 'BASE DE DATOS', 'BASE DE DATOS', 'Procedimiento que se ejecuta en el cierre e invoca al PRA_CAP_CTA_VIS_PREVIO',null,'S', ' ', 'N');
commit;

INSERT INTO BA_PROGRAMAS (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, OBSERVACION,OPE_MOD_CERRADO, UBI_MENU, INA_CIERRE)
VALUES ('PRA_CTA_VIS_NO_CAPITALIZAN', 'CUENTAS A NO CAPITALIZAR', 4, 3, 'BASE DE DATOS', 'BASE DE DATOS', 'Procedimiento que actualiza las cuentas que no capitalizan',null,'S', ' ', 'N');
commit;
----------
--insercion del proceso nuevo a la cadena de cierre
insert into ge_procesos_det (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, HOR_INICIO, HOR_FIN, COD_USUARIO, ERROR, DIR_DESTINATARIO, ACTIVO, FORMATO, CLAVE, CON_COPIA, NOM_ARCHIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO, VAR_SUSTITUCION)
values (11, 230, 'CUENTAS A CAPITALIZAR', 'PRA_CAP_CTA_PREVIO_CIERRE', 'S', 'M', null, null, null, null, null, 'S', null, null, null, null, 'S', ',', '"', null);
commit;
----------
--insercion del proceso a la cadena de dependencias
--el proceso previo debe lanzarse luego de terminar el PRA_ACT_SAL_MENSUAL
insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
values (11, 'PRA_CAP_CTA_PREVIO_CIERRE', 11, 'PRA_ACT_SAL_MENSUAL', 'P', 'El proceso PRA_CAP_CTA_PREVIO_CIERRE debe lanzarse al finalizar el PRA_ACT_SAL_MENSUAL.');
--el proceso previo debe terminar antes del PRA_CAP_CTA_VISTA_CIERRE
insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
values (11, 'PRA_CAP_CTA_VISTA_CIERRE', 11, 'PRA_CAP_CTA_PREVIO_CIERRE', 'F', 'El proceso PRA_CAP_CTA_VISTA_CIERRE no debe empezar sin que el PRA_CAP_CTA_VISTA_CIERRE finalice');
commit;
