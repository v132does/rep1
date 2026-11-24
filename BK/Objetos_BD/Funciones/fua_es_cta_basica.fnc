create or replace function it.fua_es_cta_basica(p_nro_cuenta ge_cta_clientes.nro_cuenta%type default null)
  return varchar2 is

  v_cta_basica varchar2(1) := 'N';
begin
  begin
    Select 'S'
      into v_cta_basica
      from ah_cta_vistas a
     where a.cod_sub_modalidad = 26
       and a.nro_cuenta = p_nro_cuenta;
  exception
    when too_many_rows then
      v_cta_basica := 'S';
    when no_data_found then
      v_cta_basica := 'N';
    when others then
      v_cta_basica := 'N';
  end;
  return v_cta_basica;
end;
/

