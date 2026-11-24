create or replace procedure it.prg_ins_log_intencion(p_cod_intencion it.bw_log_intencion.cod_intencion%type,
                                                     p_tipo_log      it.bw_log_intencion.tipo_log%type,
                                                     p_mensaje       it.bw_log_intencion.mensaje%type) is
  pragma autonomous_transaction;
begin
   
  insert into it.bw_log_intencion (cod_intencion, tipo_log, mensaje) 
  values (p_cod_intencion, p_tipo_log, p_mensaje);
  commit;
exception
  when others then
    null;
end;
/
