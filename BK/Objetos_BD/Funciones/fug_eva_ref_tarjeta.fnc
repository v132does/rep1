create or replace function it.fug_eva_ref_tarjeta(P_COD_PERSONA IN VARCHAR2) return varchar2 is
  Result varchar2(1) := 'N';
begin
  -- Retorna S o N, dependiendo de los datos fueron confirmados telefonicamente
  select min(cod_referencia) into Result
    from cr_ref_comerciales a
   where a.cod_persona = p_cod_persona
     and a.tip_referencia = 'T' -- Referencia de Tarjetas.
     and a.est_verificacion = 'V';
  return(Result);
exception
  when no_data_found then
     return (-1);
  when others then 
     raise_application_error(-20000,'fug_eva_ref_tarjeta '||sqlerrm);  
end fug_eva_ref_tarjeta;
/

