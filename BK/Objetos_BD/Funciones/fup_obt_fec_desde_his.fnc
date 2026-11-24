create or replace function it.FUP_OBT_FEC_DESDE_HIS
          (p_cuenta pr_cuotas.nro_cuenta%type,
           p_cuota  pr_cuotas.nro_cuota%type,
           p_cod_tas_fondo pr_tas_fondos.cod_tas_fondo%type)
  return date is
  v_cod_tas_fondo pr_tas_fondos.cod_tas_fondo%type := 0;
  v_cuota  pr_cuotas.nro_cuota%type := 0;
  v_fecha  date := NULL;
begin
  begin
    select nvl(min(cod_tas_fondo),0), nvl(min(c.nro_cuota),0)
    into   v_cod_tas_fondo, v_cuota
    from   pr_cuotas c, pr_cuotas_his h
    where  c.nro_cuenta = h.nro_cuenta
    and    c.nro_cuota  = h.nro_cuota
    and    c.nro_cuenta = p_cuenta;
  exception
    when no_data_found then
      v_cod_tas_fondo := 0;
      v_cuota         := 0;
      v_fecha         := NULL;
  end;

  if p_cuota >= v_cuota then
    if p_cod_tas_fondo = 0 then
      begin
        select max(t.cod_tas_fondo)
        into   v_cod_tas_fondo
        from   pr_tas_fondos t,  pr_cuotas_his h
        where  t.cod_tas_fondo = h.cod_tas_fondo
        and    h.nro_cuota  = p_cuota
        and    h.nro_cuenta = p_cuenta;
      exception
        when no_data_found then
          v_cod_tas_fondo := 0;
        end;
      ---
      begin
        select t.fec_desde
        into   v_fecha
        from   pr_tas_fondos t,
               pr_cuotas_his h
        where  t.cod_tas_fondo = v_cod_tas_fondo
        and    t.cod_tas_fondo = h.cod_tas_fondo
        and    h.nro_cuota  = p_cuota
        and    h.nro_cuenta = p_cuenta;
      exception
        when no_data_found then
          v_fecha         := null;
      end;
      ---
    elsif p_cod_tas_fondo > v_cod_tas_fondo then
      ---
      begin
        select t.fec_desde
        into   v_fecha
        from   pr_tas_fondos t
        where  t.cod_tas_fondo = p_cod_tas_fondo;
      exception
        when no_data_found then
          v_fecha         := null;
      end;
      ---
    end if;
  end if;

  Return v_fecha;

end FUP_OBT_FEC_DESDE_HIS;
/

