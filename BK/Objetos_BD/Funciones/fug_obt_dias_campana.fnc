create or replace function it.fug_obt_dias_campana(p_cod_persona in varchar2)
return number is
Result number;

/* Funcion que verifica si una persona forma o formó parte de alguna campaña agenda*/
begin
 
  Result := 999999;
  -- Captura la cantidad de dias que transcurrieron desde la ultima campaña
  select nvl(pag_cal.FU_OBT_FEC_ACTUAL(1) - max(a.fec_ini_asignacion),999999)
    into Result
    from cr_agendas a
   where a.cod_persona = p_cod_persona
     and a.cod_campana is not null;
 return(Result);
exception
  when no_data_found then
    return 999999;
  when others then
     return 999999;
end fug_obt_dias_campana;
/

