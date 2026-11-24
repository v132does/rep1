create or replace function it.fug_es_cliente(P_COD_PERSONA IN VARCHAR2) return varchar2 is
  Result VARCHAR2(1) := 'N';
begin
  -- Verifico si la persona es o no cliente
  Select 'S'
    into Result
    from ge_clientes a
   where a.cod_persona = p_cod_persona
     and fug_obt_can_cuentas(p_cod_persona) > 0; -- que tenga alguna cuenta
  return(Result);
exception
  when no_data_found then
     return ('N');
  when others then
     raise_application_error(-20000,'FUG_ES_CLIENTE '||sqlerrm);
end fug_es_cliente;
/

