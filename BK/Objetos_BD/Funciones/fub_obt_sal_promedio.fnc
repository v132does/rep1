create or replace function it.fub_obt_sal_promedio(p_nro_cuenta varchar2,p_cod_modulo number,p_fecha date) return number is
  v_sal_promedio number;
begin

  case
     when p_cod_modulo=3 then
        select round(a.sal_acu_diario/decode(nvl(a.can_dia_acumulado,1),0,1,nvl(a.can_dia_acumulado,1)),0)
        into v_sal_promedio
        from ah_sal_mensuales a
        where a.nro_cuenta=p_nro_cuenta
        and a.ano=to_char(p_fecha,'YYYY')
        and a.mes=to_char(p_fecha,'MM');
     when p_cod_modulo=4 then
        select round(c.sal_acu_diario/decode(nvl(c.can_dia_acumulado,1),0,1,nvl(c.can_dia_acumulado,1)),0)
        into v_sal_promedio
        from cc_sal_mensuales c
        where c.nro_cuenta=p_nro_cuenta
        and c.ano=to_char(p_fecha,'YYYY')
        and c.mes=to_char(p_fecha,'MM');
     when p_cod_modulo=6 then
        select round(p.tot_cap_acumulado/decode(nvl(p.can_dia_acumulado,1),0,1,nvl(p.can_dia_acumulado,1)),0)
        into v_sal_promedio
        from pr_sal_mensuales p
        where p.nro_cuenta=p_nro_cuenta
        and p.ano=to_char(p_fecha,'YYYY')
        and p.mes=to_char(p_fecha,'MM');
     else
        return null;

  end case;

  return(v_sal_promedio);

  exception
     when others then
        return null;
end fub_obt_sal_promedio;
/

