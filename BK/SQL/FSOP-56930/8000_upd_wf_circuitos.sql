BEGIN
  pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
  --WF_CIR_TAREAS
  FOR rec IN (select rowid from  wf_cir_tareas
              WHERE (cod_circuito, cod_tarea) IN (SELECT cod_circuito, cod_tar_actual
                                                    FROM wf_circuitos
                                                   WHERE cod_tip_circuito = 600
                                                     AND estado NOT IN ('C', 'F')
                                                     AND fec_inicio <= to_date('27/07/2025')))
  LOOP
     UPDATE wf_cir_tareas
        SET estado     = 'C', --cancelado
            cod_causa  = 237, --otros
            comentario = 'Pedido FIELDESK-159369'
      WHERE ROWID = rec.rowid;
      
      commit;
  
  END LOOP;
  
  --WF_CIRCUITOS
  FOR rec1 IN (select rowid from  wf_circuitos
               WHERE cod_tip_circuito = 600
                 AND estado NOT IN ('C', 'F')
                 AND fec_inicio <= to_date('27/07/2025'))
  LOOP
   UPDATE wf_circuitos
      SET estado  = 'C', --cancelado
          fec_fin = SYSDATE
    WHERE ROWID = rec1.rowid;
      
    commit;
  
  END LOOP;
END;
