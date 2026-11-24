begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
delete from ge_procesos_det
 where cod_proceso = 11
   and cod_programa in ('PRA_INI_EST_MODULO','PRC_INI_EST_MODULO');--2 registros afectados
/
commit;
