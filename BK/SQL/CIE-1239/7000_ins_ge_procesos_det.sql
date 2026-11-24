begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; pae_cnf.G_PROGRAMA := 'GPPROFIN'; end; 
/
--insertamos el nuevo programa
INSERT INTO BA_PROGRAMAS (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, OBSERVACION,OPE_MOD_CERRADO, UBI_MENU, INA_CIERRE)
VALUES ('PRE_EJE_DEPURACION(1)', 'DEPURACION DE TABLAS GRUPO 1', 4, 3, 'BASE DE DATOS', 'BASE DE DATOS', 'Depuracion del primer grupo de tablas',null,'S', ' ', 'N');
/
--insercion del proceso nuevo a la cadena de cierre con obligatoriedad 'N' y frecuencia 'D' 
insert into ge_procesos_det (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, HOR_INICIO, HOR_FIN, COD_USUARIO, ERROR, DIR_DESTINATARIO, ACTIVO, FORMATO, CLAVE, CON_COPIA, NOM_ARCHIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO, VAR_SUSTITUCION)
values (11, 369, 'DEPURACION DE TABLAS GRUPO 1', 'PRE_EJE_DEPURACION(1)', 'S', 'D', null, null, null, null, null, 'S', null, null, null, null, 'S', ',', '"', null);
/
commit;
/
--insertamos el nuevo programa
INSERT INTO BA_PROGRAMAS (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, OBSERVACION,OPE_MOD_CERRADO, UBI_MENU, INA_CIERRE)
VALUES ('PRE_EJE_DEPURACION(2)', 'DEPURACION DE TABLAS GRUPO 2', 4, 3, 'BASE DE DATOS', 'BASE DE DATOS', 'Depuracion del segundo grupo de tablas',null,'S', ' ', 'N');
/
--actualizamos el proceso existente
update ge_procesos_det a
   set cod_programa = 'PRE_EJE_DEPURACION(2)',
       descripcion = 'DEPURACION DE TABLAS GRUPO 2'
 where cod_proceso = 11
   and nro_orden = 386;
/
commit;
