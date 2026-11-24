create or replace function it.fug_obt_sal_promedio
( p_nro_cuenta in ge_cuentas.nro_cuenta%type
  ,p_cod_modulo in ge_cuentas.cod_modulo%type
  ,p_ano in number
  ,p_mes in number )
 return number is
 v_sal_acu_diario  ah_sal_mensuales.sal_acu_diario%type;
 v_can_dia_acumulado  ah_sal_mensuales.can_dia_acumulado%type;
begin
if p_cod_modulo = 3 then -- Ahorro --
  select sum(nvl(sal_acu_diario,0)), sum(nvl(can_dia_acumulado,0))
     into v_sal_acu_diario, v_can_dia_acumulado
   from ah_sal_mensuales
   where nro_cuenta = p_nro_cuenta 
      and ano = p_ano and mes = p_mes;
 end if;
 if p_cod_modulo = 4 then -- Cuenta Corriente --
   select sum(nvl(sal_acu_diario, 0)), sum(nvl(can_dia_acumulado, 0))
     into v_sal_acu_diario, v_can_dia_acumulado
     from cc_sal_mensuales
    where nro_cuenta = p_nro_cuenta
         and ano = p_ano and mes = p_mes;
end if;
 if p_cod_modulo = 5 then --Tarjeta --
   select sum((nvl(acu_sal_facturar, 0) + nvl(acu_sal_facturado, 0) +
              nvl(acu_sal_financiado, 0))) as sal_acu_diario,
          sum(nvl(can_dia_acumulado, 0))
     into v_sal_acu_diario, v_can_dia_acumulado
     from ta_sal_mensuales
    where nro_cuenta = p_nro_cuenta
        and ano = p_ano and mes = p_mes;
end if;
  return round(v_sal_acu_diario / v_can_dia_acumulado,2) ;
exception
  when others then
       return 0 ;
end ;
/

