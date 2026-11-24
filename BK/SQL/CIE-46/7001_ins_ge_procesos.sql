begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ge_procesos (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO, HOR_INICIO, HOR_FIN, COD_USUARIO, ERROR, PERMISO, UBI_DESTINO)
values (74, 'GENERA DATOS TEMPORALES DE TARJETAS', 1, 'N', 'N', null, null, null, null, 'ADM. DE SISTEMAS-ADMINISTRADOR DE SISTEMAS', null);
/
commit;