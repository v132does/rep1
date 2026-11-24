begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; pae_cnf.G_PROGRAMA := 'GPPROFIN'; end; 
/
update ba_cod_referencias--modificamos para que el proceso PRG_VER_JOB_CIERRE(11) pueda recibirlo
   set val_maximo = 'M',--frecuencia mensual
       abreviatura = '11',--ciclo 11 (cierre)
       significado = 'Control Job Cierre - PRA_CTA_VIS_NO_CAPITALIZAN'
 where dominio = 'JOBS_PARALELOS'
   and val_minimo = 'JOB_CTA_NO_CAP_';--1 registro afectado
/
commit;
/
delete from ge_procesos_det --eliminamos del cierre el programa existente
  where cod_proceso = 11
    and nro_orden = 994;--1 registro afectado
/
commit;
/
delete from ba_programas--eliminamos del maestro de programas por error de FK sobre ge_procesos_det
 where cod_programa = 'PRG_VER_JOB_CIERRE';--1 registro afectado
/
commit;
/
--insertamos el nuevo programa con el parametro 11 correspondiente al cod_proceso 11 del cierre
INSERT INTO BA_PROGRAMAS (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, OBSERVACION,OPE_MOD_CERRADO, UBI_MENU, INA_CIERRE)
VALUES ('PRG_VER_JOB_CIERRE(11)', 'VERIFICA JOB DINAMICO', 4, 3, 'BASE DE DATOS', 'BASE DE DATOS', 'Procedimiento que se ejecuta en el cierre e invoca al PRG_VER_JOB_DINAMICO del cierre',null,'S', ' ', 'N');
/
--insercion del proceso nuevo a la cadena de cierre con obligatoriedad 'N' y frecuencia 'D' con el parametro 11 correspondiente al cod_proceso 11 del cierre
insert into ge_procesos_det (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, HOR_INICIO, HOR_FIN, COD_USUARIO, ERROR, DIR_DESTINATARIO, ACTIVO, FORMATO, CLAVE, CON_COPIA, NOM_ARCHIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO, VAR_SUSTITUCION)
values (11, 994, 'VERIFICA JOB DINAMICO', 'PRG_VER_JOB_CIERRE(11)', 'N', 'D', null, null, null, null, null, 'S', null, null, null, null, 'S', ',', '"', null);
/
commit;
