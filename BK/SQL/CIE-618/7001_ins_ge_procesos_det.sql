begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;  
/
insert into GE_PROCESOS_DET (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, COD_USUARIO, ERROR, DIR_DESTINATARIO, ACTIVO, FORMATO, CLAVE, CON_COPIA, NOM_ARCHIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO, VAR_SUSTITUCION)
values (10, 101, 'TRANSP A HISTORICO GE_CON_TRANS', 'PRB_CON_TRA_HIS', 'N', 'D', null, null, null, 'S', null, null, null, null, 'S', ',', '"', null);

commit;
