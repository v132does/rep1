create or replace function it.fug_obt_est_cuenta(p_nro_cuenta ge_cta_clientes.nro_cuenta%type default null)
  return varchar2 is

  v_estado varchar2(1) := null;
begin
  begin
    Select a.estado
      into v_estado
      from ge_cuentas a
     where a.nro_cuenta = p_nro_cuenta;
  exception
    when no_data_found then
      v_estado := null;
    when others then
      v_estado := null;
  end;
  return v_estado;
end;
/

