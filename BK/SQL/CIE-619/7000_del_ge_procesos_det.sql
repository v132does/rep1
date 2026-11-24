begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
delete ge_procesos_det a
where a.cod_proceso = 11
and a.nro_orden = 381;
commit;
