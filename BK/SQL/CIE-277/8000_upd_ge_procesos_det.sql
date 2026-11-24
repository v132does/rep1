begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ge_procesos_det t
set t.cod_programa='PRE_TAB_DEPURACION'
where t.nro_orden = 23
and t.cod_proceso = 12; 

commit;