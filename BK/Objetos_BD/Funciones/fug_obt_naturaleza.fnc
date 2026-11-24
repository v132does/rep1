create or replace function it.fug_obt_naturaleza(p_cod_persona ba_personas.cod_persona%type)
  return ba_per_juridicas.naturaleza%type is
  v_naturaleza ba_per_juridicas.naturaleza%type;
--https://itti-digital.atlassian.net/browse/NVB-3811
begin
  select ju.naturaleza
    into v_naturaleza
    from ba_per_juridicas ju
   where ju.cod_persona = p_cod_persona;
  return v_naturaleza;
exception
  when others then
    return null;
end;
/

