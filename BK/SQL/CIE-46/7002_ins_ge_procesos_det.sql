begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ge_procesos_Det (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, HOR_INICIO, HOR_FIN, COD_USUARIO, ERROR, DIR_DESTINATARIO, ACTIVO, FORMATO, CLAVE, CON_COPIA, NOM_ARCHIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO, VAR_SUSTITUCION)
values (74, 1, 'GENERA DATOS TEMPORALES DE TARJETAS', 'PRG_PRO_DAT_TARJETAS', 'N', 'D', null, null, null, null, null, 'S', null, null, null, null, null, null, null, null);
/
commit;