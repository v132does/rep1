create or replace function it.fug_obt_sal_actual(p_cod_persona   in ba_personas.cod_persona%type,
                                                 p_cod_modulo    in ba_modulos.cod_modulo%type,
                                                 p_cod_modalidad in ge_modalidades.cod_modalidad%type,
                                                 p_nro_cuenta    in ge_cuentas.nro_cuenta%type)
  return number is
  v_sal_actual number;
begin
  if p_cod_modulo = 4 then
    -- cuentas pasivas
    pag_cta.pr_obt_cuenta(p_nro_cuenta);
    v_sal_actual := pag_cta.fu_sal_disponible;
  elsif p_cod_modulo = 3 then
    -- cuentas pasivas
    if p_cod_modalidad in (31,331,334) then
      pag_cta.pr_obt_cuenta(p_nro_cuenta);
      v_sal_actual := pag_cta.fu_sal_disponible;
    else
      select c.sal_total
        into v_sal_actual
        from ah_cta_certificados c
       where c.nro_cuenta = p_nro_cuenta;
    end if;
  elsif p_cod_modulo = 5 then
    -- tarjetas
    select nvl(lin_credito, 0) -
           (nvl(b.sal_facturar, 0) + nvl(b.sal_facturado, 0) +
            nvl(b.sal_financiado, 0) + nvl(b.sal_cuo_pendientes, 0))
      into v_sal_actual
      from ta_cta_tarjetas b
     where b.nro_cuenta = p_nro_cuenta;
  elsif p_cod_modulo = 6 then
    -- prestamos
    select nvl(b.sal_capital, 0) + nvl(b.sal_int_adelantado, 0) + nvl(b.sal_interes, 0)
      into v_sal_actual
      from pr_cta_prestamos b
     where b.nro_cuenta = p_nro_cuenta;
  end if;
  return v_sal_actual;
exception
  when others then
    return 0; -- saldo 0(cero)
end;
/

