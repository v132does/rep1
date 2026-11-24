create or replace function it.fug_PUNTAJE
  (P_COD_PERSONA in varchar2, 
   P_COD_PUNTAJE in number) return number is
  v_puntaje number;
begin
  select nvl(puntaje,-100)
    into v_puntaje
     from cr_per_puntajes
   where cod_persona = p_cod_persona
     and cod_puntaje = p_cod_puntaje;       
  return(v_puntaje);
exception
  when others then
     return -100;
end fug_puntaje;
/

