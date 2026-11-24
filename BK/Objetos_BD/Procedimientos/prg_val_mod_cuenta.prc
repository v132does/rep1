create or replace procedure it.prg_val_mod_cuenta(p_nro_cuenta ge_cuentas.nro_cuenta%type)
is
  v_modalidad ge_cuentas.cod_modalidad%type;
  function fu_obt_modalidad return number is
    v_cod_modalidad ge_cuentas.cod_modalidad%type;
    begin
      select a.cod_modalidad
        into v_cod_modalidad
        from ge_cuentas a
       where a.nro_cuenta = p_nro_cuenta;
      return v_cod_modalidad;
    exception
      when no_data_found then
        return null;
      when others then
        return null;
    end;
begin

  v_modalidad := fu_obt_modalidad;

  if nvl(v_modalidad,'1') not in (41,31) then
    raise_application_error(-20000,'Solo de admiten Cuentas Corrientes o Ahorro.');
  end if;

end;
/

