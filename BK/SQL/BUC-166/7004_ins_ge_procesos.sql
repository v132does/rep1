Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_procesos (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO, ERROR, PERMISO, UBI_DESTINO)
values (960, 'TAR_DEV_CARGOS', 1, 'S', 'P', null, null, null);

insert into ge_procesos_det (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, ERROR, DIR_DESTINATARIO, ACTIVO, FORMATO, CLAVE, CON_COPIA, NOM_ARCHIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO, VAR_SUSTITUCION)
values (960, 1, 'TAR_DEV_CARGOS', 'PRT_DEV_CAR_TARJETAS', 'N', 'D', null, null, 'S', null, null, null, null, 'N', ';', '"', null);

commit;
