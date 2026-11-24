Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
delete ge_procesos_det
where cod_proceso = 10
and nro_orden = 417;

commit;