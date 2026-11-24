create or replace function it.fug_obt_por_reintegro(p_cod_promocion varchar2, p_cod_persona varchar2, v_por_default number)
return number is
  v_por_reintegro ge_com_niveles.por_reintegro%type;
  v_fec_valor date := trunc(sysdate);
begin
  begin
    select nvl(c.por_reintegro,0) + nvl(v_por_default, 0)
      into v_por_reintegro
      from ge_com_personas_nivel a, ge_promociones b, ge_com_niveles c
     where a.cod_persona = p_cod_persona
       and b.cod_promocion = p_cod_promocion
       and a.cod_nivel = b.cod_nivel
       and a.cod_nivel = c.cod_nivel;
     return v_por_reintegro;
  exception
    when no_data_found then
      return null;
  end;
end;

/
