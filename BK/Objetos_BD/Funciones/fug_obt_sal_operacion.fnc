create or replace function it.fug_obt_sal_operacion(p_nro_cuenta in ge_cuentas.nro_cuenta%type,
                                                 p_cod_moneda in ge_cuentas.cod_moneda%type)
  return number is
  v_mon_oper   number := 0;
  v_cod_modulo ge_cuentas.cod_modulo%type;
  v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(1);
begin
  -- Extrae el Módulo --
  Select cod_modulo
    into v_cod_modulo
    from ge_cuentas
   where nro_cuenta = p_nro_cuenta;
  -- Atrasos
  if v_cod_modulo = 6 then
    -- Préstamos --
    Select sum(nvl(sal_capital, 0) + nvl(sal_interes, 0) + nvl(sal_int_documentado,0))
      into v_mon_oper
      from pr_cuotas
     where nro_cuenta = p_nro_cuenta
       and fec_vencimiento < v_fec_actual
       and (nvl(sal_capital, 0) > 0 or nvl(sal_interes, 0) > 0 or nvl(sal_int_documentado,0) > 0)
     order by nro_cuota;
  elsif v_cod_modulo = 4 then
    -- Sobregiro --
    Select sum(sal_total)
      into v_mon_oper
      from cc_sobregiros c, cc_sobregiros_res r
     where c.nro_cuenta = p_nro_cuenta
       and c.nro_cuenta = r.nro_cuenta
       and c.fecha = (Select max(c.fecha)
                        from cc_sobregiros c
                       where c.nro_cuenta = p_nro_cuenta)
       and nvl(r.can_dia_sobregiro,0) > 0 ;
  elsif v_cod_modulo = 5 then
    -- Tarjeta --
    Select sum(t.mto_mora)
      into v_mon_oper
      from ta_cta_tarjetas t, ge_cta_clientes c
     where t.nro_cuenta = c.nro_cuenta
       and t.nro_cuenta = p_nro_cuenta
       and c.relacion = 'P';
  elsif v_cod_modulo = 15 then
    -- Operaciones Vencidas --
    select sum(t.Sal_Total)
      into v_mon_oper
      from ov_cta_vencidas t
     WHERE T.NRO_CUENTA = p_nro_cuenta;
  end if;
  v_mon_oper := pal_cam.fu_con_mon_a_moneda(p_cod_moneda, 'GS', v_mon_oper);
  return nvl(v_mon_oper, 0);
exception
  when others then
    return 0;
end;
/

