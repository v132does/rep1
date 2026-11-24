create or replace function it.fug_ant_laboral(P_COD_PERSONA IN VARCHAR2)
return number is
  Result number:= 0; -- en meses
begin
  -- Retorna la antiguedad laboral de la persona en meses
  select round(max((sysdate - t.fec_ingreso)) / 30.4,2) -- para obtener en meses
    into Result
    from cr_inf_laborales t
   where t.cod_persona = p_cod_persona
     and t.actual = 'S';
  return(Result);
exception
  when no_data_found then
     return (0);
  when others then 
     raise_application_error(-20000,'fug_ant_laboral '||sqlerrm);  
end fug_ant_laboral;
/

