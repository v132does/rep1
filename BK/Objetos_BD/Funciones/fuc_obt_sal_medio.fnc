CREATE OR REPLACE FUNCTION IT."FUC_OBT_SAL_MEDIO"(p_nro_cuenta in ge_cuentas.nro_cuenta%type,
                                               p_fecha      in ge_movimientos.fecha%type,
                                               p_cod_moneda in ba_monedas.cod_moneda%type)
  return Number is
  v_saldo     number;
  v_salMOV    number;
  v_salCC     number;
  v_sal_medio number;
  v_can_dias  number;
Begin
  --saldo de la cuenta
  select saldo
    into v_salCC
    from (select sum(saldo * count(*)) saldo
            from cc_sobregiros
           where nro_cuenta = p_nro_cuenta
             and to_char(fecha, 'mmyyyy') = to_char(p_fecha, 'mmyyyy')
           group by saldo);

  --comisiones de la cuenta que provocan sobregiro
  select saldo
    into v_salMOV
    from (select sum(monto * count(*)) saldo
            from cc_movimientos_his m
           where m.nro_cuenta = p_nro_cuenta
             and to_char(m.fecha, 'mmyyyy') = to_char(p_fecha, 'mmyyyy')
             and cod_transaccion in
                 (517, 523, 528, 550, 780, 989, 523, 325, 319, 788)
             and m.cod_modalidad = '41'
             and m.reversado = 'N'
             and m.cod_usu_reversion is null
           group by m.monto);

  v_saldo := v_salMOV + v_salCC;

  --los días que en que se sobregira en el mes  
  select count(*)
    into v_can_dias
    from cc_sobregiros
   where nro_cuenta = p_nro_cuenta
     and to_char(fecha, 'mmyyyy') = to_char(p_fecha, 'mmyyyy');

  v_sal_medio := v_saldo / to_number(v_can_dias);

  --v_sal_medio := v_saldo / to_number(to_char(last_day(p_fecha),'dd')); --anterior

  return round(v_sal_medio,
               fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                   NULL,
                                   NULL,
                                   p_cod_moneda));
Exception
  when others then
    return 0;
end;
/

