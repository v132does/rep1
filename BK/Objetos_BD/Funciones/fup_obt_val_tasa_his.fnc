create or replace function it.FUP_OBT_VAL_TASA_HIS
          (p_cuenta pr_cuotas.nro_cuenta%type,
           p_cuota  pr_cuotas.nro_cuota%type)
  return number is
  v_cod_tas_fondo pr_tas_fondos.cod_tas_fondo%type := 0;
  v_tasa pr_cuotas_his.val_tasa%type := 0;
  v_cuota  pr_cuotas.nro_cuota%type := 0;
begin
  begin
    select nvl(min(cod_tas_fondo),0), nvl(min(c.nro_cuota),0)
    into   v_cod_tas_fondo, v_cuota
    from   pr_cuotas c, pr_cuotas_his h
    where  c.nro_cuenta = h.nro_cuenta
    and    c.nro_cuota  = h.nro_cuota
    and    c.nro_cuenta = p_cuenta;
    --and    c.nro_cuota  = p_cuota;
  exception
    when no_data_found then
      v_cod_tas_fondo := 0;
      v_cuota         := 0;
  end;

  if v_cod_tas_fondo = 0 or p_cuota >= v_cuota then
    select p.val_tasa
    into   v_tasa
    from   pr_cta_prestamos p
    where  p.nro_cuenta = p_cuenta;
  else
  --dbms_output.put_line(to_char(v_cod_tas_fondo));
  --dbms_output.put_line(to_char(v_cuota));
   select h.val_tasa
    into   v_tasa
    from   pr_cuotas_his h
    where  h.cod_tas_fondo = v_cod_tas_fondo
    and    h.nro_cuenta    = p_cuenta
    and    h.nro_cuota     = v_cuota;
  end if;
  Return v_tasa;

end FUP_OBT_VAL_TASA_HIS;
/

