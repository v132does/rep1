CREATE OR REPLACE FUNCTION IT."FUP_OBT_ULT_CAPITAL"(p_nro_cuenta in pr_cta_prestamos.nro_cuenta%type)
  return number is
  v_fecha  pr_cobros.fecha%type;
  v_hora   pr_cobros.hora%type;
  v_return pr_cobros.mto_capital%type;
begin
  -- Máxima Fecha --
  select max(c.fecha)
    into v_fecha
    from pr_cobros c
   where c.nro_cuenta = p_nro_cuenta;
  -- Máxima hora --
  select max(c.hora)
    into v_hora
    from pr_cobros c
   where c.nro_cuenta = p_nro_cuenta
     and c.fecha = v_fecha;
  ------------------------------------
  select sum(r.mto_capital)
    into v_return
    from pr_cobros r
   where nro_cuenta = p_nro_cuenta
     and r.fecha = v_fecha
     and r.hora = v_hora;
  return v_return;
exception
  when no_data_found then
    return null;
  when others then
    raise_Application_error(-20000, 'Obt.Monto de Cobro.' || sqlerrm);
end;
/

