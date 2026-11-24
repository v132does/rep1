create or replace function it.fug_tie_clave(P_COD_PERSONA IN VARCHAR2) return varchar2 is
  Result VARCHAR2(1) := 'N';
-- Verifica si el cliente puede Tener Clave.
begin
  -- Verifico si la persona es o no cliente
  Select 'S'
    into Result
    from ge_clientes a
   where a.cod_persona = p_cod_persona; -- que tenga alguna cuenta
  return(Result);
exception
  when no_data_found then
     return ('N');
  when others then
     raise_application_error(-20000,'FUG_TIE_CLAVE '||sqlerrm);
end fug_tie_clave;
/

