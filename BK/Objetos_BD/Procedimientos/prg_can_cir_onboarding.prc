CREATE OR REPLACE PROCEDURE IT.PRG_CAN_CIR_ONBOARDING(p_cod_persona in ba_personas.cod_persona%type,
                                                      p_cod_error out varchar2) is
  
BEGIN
  p_cod_error := 'OK';  
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
--- Actualiza imagenes
BEGIN
  UPDATE ba_per_ima_documentos d
     SET d.est_doc = 'A'
   WHERE d.cod_persona = trim(p_cod_persona)
     AND d.cod_tip_documento = 64
     AND d.est_doc <> 'A';
EXCEPTION
  WHEN OTHERS THEN
    p_cod_error := 'ERROR AL ACTUALIZAR IMAGENES'|| sqlerrm;
    prg_ins_log_programas('FD_SUBIR_DOCUMENTO',substr('1-Error: ' || sqlerrm ||' ------------ DATOS --> Persona: ' ||p_cod_persona,1,4000),NULL,p_cod_persona);
END;

--- Actualiza la tarea A Aprobado
BEGIN
  UPDATE wf_cir_tareas ct
     SET ct.estado = 'A'
   WHERE ct.cod_circuito IN
         (SELECT c.cod_circuito
            FROM wf_circuitos c
           WHERE c.cod_persona = trim(p_cod_persona)
             AND c.cod_tip_circuito = 48)
     AND ct.estado = 'P';
EXCEPTION
  WHEN OTHERS THEN
    p_cod_error := 'ERROR AL ACTUALIZAR TAREAS'|| sqlerrm;
    prg_ins_log_programas('FD_SUBIR_DOCUMENTO',substr('1-Error: ' || sqlerrm ||' ------------ DATOS --> Persona: ' ||p_cod_persona,1,4000),NULL,p_cod_persona);
END;

-- Finaliza el circuito
BEGIN
  UPDATE wf_circuitos c
     SET c.estado = 'F'
   WHERE c.cod_persona = trim(p_cod_persona)
     AND c.estado = 'E'
     AND c.cod_tip_circuito = 48;
EXCEPTION
  WHEN OTHERS THEN
    p_cod_error := 'ERROR AL ACTUALIZAR CIRCUITOS'|| sqlerrm;
    prg_ins_log_programas('FD_SUBIR_DOCUMENTO', substr('1-Error: ' || sqlerrm || ' ------------ DATOS --> Persona: ' || p_cod_persona, 1, 4000), NULL, p_cod_persona);
END;

IF p_cod_error = 'OK' THEN
   commit;
ELSE 
  rollback;
END IF;

END;
/
