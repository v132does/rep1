create or replace function it.fug_eva_ref_bancaria(P_COD_PERSONA IN VARCHAR2) return varchar2 is
  Result varchar2(1) := 'N';
begin
  -- Retorna S o N, dependiendo de los datos fueron confirmados telefonicamente
  select max(cod_referencia) into Result
    from cr_ref_comerciales a
   where a.cod_persona = p_cod_persona
     and a.tip_referencia = 'B' -- Referencia Bancaria
     and a.est_verificacion = 'V';
  return(Result);
exception
  when no_data_found then
     return (-1);
  when others then 
     raise_application_error(-20000,'fug_eva_ref_bancaria '||sqlerrm);  
end fug_eva_ref_bancaria;
/

