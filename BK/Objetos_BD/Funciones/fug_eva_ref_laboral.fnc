create or replace function it.fug_eva_ref_laboral(P_COD_PERSONA IN VARCHAR2) return varchar2 is
  Result varchar2(1) := 'N';
begin
  -- Retorna S o N, dependiendo de los datos fueron confirmados telefonicamente
  select 'S' into Result
    from cr_ref_personales a
   where a.cod_persona = p_cod_persona
     and a.tip_referencia = 'L' -- REF LABORAL
     and a.est_verificacion = 'V';
  return(Result);
exception
  when no_data_found then
     return ('N');
  when too_many_rows then
     return ('S');   
  when others then 
     raise_application_error(-20000,'fug_obt_eva_ref_laboral '||sqlerrm);  
end fug_eva_ref_laboral;
/

