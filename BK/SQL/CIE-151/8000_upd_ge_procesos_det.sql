begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
update ge_procesos_det a
set a.nro_orden = 99
where a.cod_proceso = 11
and a.nro_orden = 300;

update ge_procesos_det a
set a.nro_orden = 101
where a.cod_proceso = 11
and a.nro_orden = 305;

update ge_procesos_det a
set a.nro_orden = 102
where a.cod_proceso = 11
and a.nro_orden = 73;

commit;

