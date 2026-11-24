Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_procesos (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO, ERROR, PERMISO, UBI_DESTINO)
values (970, 'TAR_PASE_VENCIDA', 1, 'S', 'P', null, null);

insert into ge_procesos_det (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, ERROR, DIR_DESTINATARIO, ACTIVO, FORMATO, CLAVE, CON_COPIA, NOM_ARCHIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO, VAR_SUSTITUCION)
values (970, 1, 'TAR_PASE_VENCIDA', 'PRT_PAS_VENCIDAS', 'S', 'D', null, null, 'S', null, null, null, null, 'N', ',', '"', null);

commit;
