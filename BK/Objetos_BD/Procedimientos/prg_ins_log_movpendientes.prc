create or replace procedure it.prg_ins_log_movpendientes(p_nro_documento it.bw_log_movpendientes.nro_documento%type,
                                                         p_det_error     it.bw_log_movpendientes.det_error%type,
                                                         p_cod_persona   it.bw_log_movpendientes.cod_persona%type) is
  pragma autonomous_transaction;
begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
   
  insert into it.bw_log_movpendientes (nro_documento, det_error, cod_persona) values (p_nro_documento, p_det_error, p_cod_persona);
  commit;
exception
  when others then
    null;
end;
/
