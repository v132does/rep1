Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ge_procesos_det
set cod_proceso = 14,
nro_orden = 1
where cod_proceso = 12
and nro_orden = 32;

commit;