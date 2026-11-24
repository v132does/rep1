begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
delete from ge_procesos_det where cod_proceso = 998;

delete from ge_procesos where cod_proceso = 998;

commit;
