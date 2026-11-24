BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
DELETE FROM wf_tip_cir_tareas 
WHERE cod_tip_circuito = 600 
AND cod_tip_tarea = 1;

COMMIT;
