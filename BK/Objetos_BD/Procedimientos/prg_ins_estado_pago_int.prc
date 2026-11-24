create or replace procedure it.prg_ins_estado_pago_int(p_registro  in  it.bw_estado_pago_intencion%rowtype,
                                                      p_inserto   out boolean,
                                                      p_registro_out out it.bw_estado_pago_intencion%rowtype) is
  pragma autonomous_transaction;
  v_dup_val_on_index exception;
  pragma exception_init(v_dup_val_on_index, -00001);
begin
  -- Log inicio de operacion
  it.prg_ins_log_intencion(p_registro.cod_intencion, 'INFO', 'Intentando insertar registro');
  
  -- Intentar insertar el registro
  INSERT INTO it.bw_estado_pago_intencion ( cod_intencion, estado, respuesta)
  VALUES ( p_registro.cod_intencion, p_registro.estado, p_registro.respuesta)
  RETURNING id, cod_intencion, estado, respuesta 
  INTO p_registro_out.id, p_registro_out.cod_intencion, p_registro_out.estado, p_registro_out.respuesta;
  
  p_inserto := true;
  
  commit;
  -- Log insercion exitosa
  it.prg_ins_log_intencion(p_registro.cod_intencion, 'INFO', 'Registro insertado exitosamente');
exception
  when v_dup_val_on_index then
    -- Si hay error de unique constraint, buscar el registro existente
    rollback;
    p_inserto := false;
    
    -- Log error de duplicado
    it.prg_ins_log_intencion(p_registro.cod_intencion, 'INFO', 'Error - Registro duplicado, recuperando existente');
    it.prg_ins_log_pag_int_salario(p_registro.cod_intencion, NULL, NULL, 'Error DUP_VAL_ON_INDEX - Registro duplicado');
    
    SELECT *
    INTO p_registro_out
    FROM it.bw_estado_pago_intencion
    WHERE cod_intencion = p_registro.cod_intencion;
    
  when others then
    rollback;
    -- Log error general
    it.prg_ins_log_intencion(p_registro.cod_intencion, 'INFO', 'Error: ' || SQLERRM);
    it.prg_ins_log_pag_int_salario(p_registro.cod_intencion, NULL, NULL, 'Error OTHERS: ' || SQLERRM);
    raise;
end;
/
