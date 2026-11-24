create or replace function it.fug_saldo_medio(p_nro_cuenta in cc_cta_corrientes.nro_cuenta%type, P_FECHA in date) return Number is
 v_saldo     number;
 v_sal_medio number;
 v_moneda    cc_cta_corrientes.cod_moneda%type;
Begin
  select sum(saldo*count(*)) into v_saldo
    from cc_sobregiros
   where nro_cuenta = p_nro_cuenta
     and to_char(fecha,'mmyyyy') = to_char(p_fecha,'mmyyyy')
  group by saldo   ;
  
  select a.cod_moneda
    into v_moneda  
    from cc_cta_corrientes a
    where a.nro_cuenta = p_nro_cuenta;


  v_sal_medio := v_saldo / to_number(to_char(last_day(p_fecha),'dd'));
  return round(v_sal_medio,fug_obt_redondeo_seg(v_moneda));
Exception
  when others then
    return 0;
end;
/

