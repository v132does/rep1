CREATE OR REPLACE PROCEDURE IT.prg_act_workflow IS

  --Cursor del archivo tmp importado.
  CURSOR c_pre_wf_tmp IS
    SELECT cod_persona 
    FROM ge_per_workflow_tmp; 

  --Declaramos las variables
  v_cod_error    VARCHAR2(5) := 'Ok';
  v_msj_error    VARCHAR2(1000) := 'Procesado con exito.';
  v_can_registro NUMBER;
  v_cantidad     NUMBER := 0;
  v_cod_circuito wf_circuitos.cod_circuito%TYPE;
BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.G_COD_MODULO := 1;
  end;
  FOR c IN c_pre_wf_tmp LOOP
    v_can_registro := 0;
      
      BEGIN
        SELECT count(1)
          INTO v_can_registro
          FROM wf_circuitos t
         WHERE t.cod_persona = c.cod_persona
           AND t.estado not in ('C', 'F')
           AND t.cod_tip_circuito in ('37', '39');
      EXCEPTION
        WHEN no_data_found THEN
          v_cod_error := 'Error';
          v_msj_error := 'Registro no encontrado en la tabla tmp.';
        WHEN OTHERS THEN
          v_cod_error := 'Error';
          v_msj_error := 'Inconveniente en el control de datos duplicados.';
      END;
      IF v_can_registro > 0 then
         BEGIN
            SELECT t.cod_circuito
                INTO v_cod_circuito
                FROM wf_circuitos t
               WHERE t.cod_persona = c.cod_persona
                 AND t.estado not in ('C', 'F')
                 AND t.cod_tip_circuito in ('37','39')
                 AND rownum=1;
            EXCEPTION
              WHEN no_data_found THEN
                v_cod_error := 'Error';
                v_msj_error := 'Registro no encontrado en la tabla tmp.';
              WHEN OTHERS THEN
                v_cod_error := 'Error';
                v_msj_error := 'Inconveniente en el control de datos duplicados.';
          END; 
         --Actualiza la tarea A Aprobado
         BEGIN
           UPDATE wf_cir_tareas ct
              SET ct.estado = 'A'
            WHERE ct.cod_circuito in(SELECT t.cod_circuito
                                       FROM wf_circuitos t
                                      WHERE t.cod_persona = c.cod_persona
                                        and t.estado not in ('C', 'F')
                                        and t.cod_tip_circuito in ('37', '39'))
              AND ct.estado = 'P';
         EXCEPTION
           WHEN OTHERS THEN
             v_cod_error := 'Error';
              prg_ins_log_programas('PRG_ACT_WORKFLOW',substr('1-Error: ' || sqlerrm, 1, 4000),null,c.cod_persona);
         END;

          -- Finaliza el circuito      
          BEGIN
            UPDATE wf_circuitos
               SET estado = 'F'
             WHERE cod_persona = c.cod_persona
               AND estado not in ('C', 'F')
               AND cod_tip_circuito in ('37','39');
          EXCEPTION
            WHEN OTHERS THEN
              v_cod_error := 'Error';
              prg_ins_log_programas('PRG_ACT_WORKFLOW',substr('1-Error: ' || sqlerrm, 1, 4000),null,c.cod_persona);
          END;
            IF v_cod_error='Ok' THEN
               it.prw_per_dat_doc(v_cod_circuito,'A','','finalizacion masiva');
            END IF; 
    END IF;
  END LOOP;
  
END;
/
