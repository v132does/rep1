Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ge_procesos (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO, HOR_INICIO, HOR_FIN, COD_USUARIO, ERROR, PERMISO, UBI_DESTINO)
values (47, 'PRO_VEN_SOBREGIROS', 1, 'N', 'P', null, null, null, null, null, null);

commit;
