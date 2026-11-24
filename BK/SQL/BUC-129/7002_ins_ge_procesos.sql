Begin 
  pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
end; 
/
insert into GE_PROCESOS (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO, ERROR, PERMISO, UBI_DESTINO)
values (64, 'OPERACIONES_PERSONAS', 1, 'N', 'P',  null, null, null);

COMMIT;
