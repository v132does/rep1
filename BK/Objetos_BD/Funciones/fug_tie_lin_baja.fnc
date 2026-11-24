create or replace function it.fug_tie_lin_baja(P_COD_PERSONA IN VARCHAR2) return varchar2 is
  Result varchar2(1) := 'N';
begin
  -- Retorna S si la persona tiene linea telefonica baja
  select 'S' into Result
    from ba_telefonos a
   where a.cod_persona = p_cod_persona
     and a.tip_linea = 'B'; -- linea baja
  return(Result);
exception
  when no_data_found then
     return ('N');
  when too_many_rows then
     return ('S');   
  when others then 
     raise_application_error(-20000,'fug_tie_lin_baja '||sqlerrm);  
end fug_tie_lin_baja;
/

