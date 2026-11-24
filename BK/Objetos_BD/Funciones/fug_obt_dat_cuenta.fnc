create or replace function it.fug_obt_dat_cuenta(p_nro_cuenta  in varchar2,
                                          p_cod_persona in varchar2,
                                          p_tipo        in char)
  return varchar2 is
  v_return varchar2(150);
begin
  if p_tipo = 'D' then
    -- Modalidad --
    Select fug_obt_des_modalidad(c.cod_modalidad)
      into v_return
      from ge_cta_clientes c
     where c.nro_cuenta = p_nro_cuenta
       and c.cod_persona = p_cod_persona;
  elsif p_tipo = 'M' then
    -- Moneda --
    Select fug_obt_mon_cta(c.nro_cuenta)
      into v_return
      from ge_cta_clientes c
     where c.nro_cuenta = p_nro_cuenta
       and c.cod_persona = p_cod_persona;
  end if;
  return(v_return);
Exception
  When NO_DATA_FOUND Then
    return('N'); -- retorna directamente NO
end fug_obt_dat_cuenta;
/

