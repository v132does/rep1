create or replace procedure it.prg_ins_log_pagsalarios(p_cod_persona   it.ge_log_pagsalarios.cod_persona%type,
                                                       p_cod_sesion    it.ge_log_pagsalarios.cod_sesion%type,
                                                       p_nro_documento it.ge_log_pagsalarios.nro_documento%type,
                                                       p_nivel         it.ge_log_pagsalarios.nivel%type,
                                                       p_detalle       it.ge_log_pagsalarios.detalle%type) is
  pragma autonomous_transaction;
begin
  insert into it.ge_log_pagsalarios
    (cod_persona, cod_sesion, nro_documento, nivel, detalle)
  values
    (p_cod_persona, p_cod_sesion, p_nro_documento, upper(p_nivel), p_detalle);
  commit;
exception
  when others then
    null;
end;
/
