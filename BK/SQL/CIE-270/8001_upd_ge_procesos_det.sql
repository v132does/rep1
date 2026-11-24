begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
update ge_procesos_det a
set a.nro_orden = 149
where a.cod_proceso = 11
and a.nro_orden = 20;
commit;
