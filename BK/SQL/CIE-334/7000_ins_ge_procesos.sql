begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;
/
insert into ge_procesos (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO, HOR_INICIO, HOR_FIN, COD_USUARIO, ERROR, PERMISO, UBI_DESTINO)
values (7, 'PRE CIERRE DE DIA', 1, 'N', 'F', null, null, null, null, 'ADM. DE SISTEMAS-ADMINISTRADOR DE SISTEMAS ó FIELCO_CIERRE-CADENA DE CIERRE', null);

commit;
