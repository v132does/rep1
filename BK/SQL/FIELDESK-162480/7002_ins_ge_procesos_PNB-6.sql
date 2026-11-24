begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;
/
insert into ge_procesos(cod_proceso, descripcion, nro_orden, obligatorio, tipo, permiso)
values(660, 'REPROCESO DE INFORME LCR', 1, 'N', 'N', 'ADM. DE SISTEMAS-ADMINISTRADOR DE SISTEMAS');

commit;
