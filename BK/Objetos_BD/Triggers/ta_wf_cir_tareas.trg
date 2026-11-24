CREATE OR REPLACE TRIGGER IT.TA_WF_CIR_TAREAS
  AFTER INSERT OR DELETE OR UPDATE
     ON WF_CIR_TAREAS
    FOR EACH ROW
DECLARE
  v_cod_error number := 0;
BEGIN
  IF inserting THEN
    -- inserto los detalles de la tarea                                      
     insert into wf_cir_tar_detalles
        (cod_circuito, cod_tarea, cod_tar_detalle, descripcion, estado)
      select :new.cod_circuito, :new.cod_tarea, rownum, descripcion, 'P'
        from wf_tip_cir_tar_det a
       where a.cod_tip_circuito = :new.cod_tip_circuito
         and a.cod_tip_tarea = :new.cod_tip_tarea;

  ELSIF deleting THEN
     -- borro las subtareas
     delete from wf_cir_tar_detalles
      where cod_circuito = :old.cod_circuito
        and cod_tarea = :old.cod_tarea;
                                             
  END IF;
EXCEPTION
  when others then
     null;
END;
/

