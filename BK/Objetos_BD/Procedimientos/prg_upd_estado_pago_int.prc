create or replace procedure it.prg_upd_estado_pago_int(p_cod_intencion it.bw_estado_pago_intencion.cod_intencion%type,
                                                      p_estado        it.bw_estado_pago_intencion.estado%type,
                                                      p_respuesta     it.bw_estado_pago_intencion.respuesta%type) is
  pragma autonomous_transaction;
begin
  -- Actualizar el registro por cod_intencion
  UPDATE it.bw_estado_pago_intencion
  SET estado = p_estado,
      respuesta = p_respuesta
  WHERE cod_intencion = p_cod_intencion;
  
  commit;
exception
  when others then
    rollback;
    raise;
end;
/
