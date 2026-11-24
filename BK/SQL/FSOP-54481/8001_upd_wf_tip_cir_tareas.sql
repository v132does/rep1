BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
UPDATE wf_tip_cir_tareas
   SET det_sql = NULL
 WHERE cod_tip_circuito = 600
   AND cod_tip_tarea = 0;

UPDATE wf_tip_cir_tareas
   SET det_sql = 'BEGIN pre_ins_dat_adicionales(''&'||'COD_PERSONA'',''&'||'TIP_ACCION'',''&'||'COD_CIRCUITO'');END;'
 WHERE cod_tip_circuito = 600
   AND cod_tip_tarea = 2;

COMMIT;   
