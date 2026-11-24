create or replace function it.fug_obt_paq_nro_secuencia(p_cod_persona ba_personas.cod_persona%type)
  return number is
  v_nro_secuencia number;
begin

  select max(t.nro_secuencia)
    into v_nro_secuencia
    from ge_paq_clientes t
   where t.cod_persona = p_cod_persona;

   v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;

   return(v_nro_secuencia);

exception
  when no_data_found then
    v_nro_secuencia := 1;
    return(v_nro_secuencia);
end;
/

