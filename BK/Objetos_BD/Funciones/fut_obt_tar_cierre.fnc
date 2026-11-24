create or replace function it.fut_obt_tar_cierre(p_nro_cuenta in ta_cta_tarjetas.nro_cuenta%type,
                                              pi_tipo      in char)
  return varchar2 IS
  v_return     varchar2(500);
  v_fec_maxima date;
Begin
  if pi_tipo = 'T' then
    -- Tipo de Cierre de Tarjeta --
    select fut_obt_des_tip_cierre(t.cod_tip_cierre)
      into v_return
      from ta_cta_tarjetas t
     where t.nro_cuenta = p_nro_cuenta;
  elsif pi_tipo = 'D' then
    -- Deuda al Cierre --
    Select max(fec_cierre)
      into v_fec_maxima
      from ta_sal_cierres
     where nro_cuenta = p_nro_cuenta;
    --
    select nvl(sal_facturar, 0) + nvl(sal_financiado, 0) +
           nvl(sal_facturado, 0)
      into v_return
      from ta_sal_cierres
     where nro_cuenta = p_nro_cuenta
       and fec_cierre = v_fec_maxima;
  elsif pi_tipo = 'P' then
    -- Pago Minimo --
    Select max(fec_cierre)
      into v_fec_maxima
      from ta_sal_cierres
     where nro_cuenta = p_nro_cuenta;
    --
    select s.mto_pag_minimo
      into v_return
      from ta_sal_cierres s
     where s.nro_cuenta = p_nro_cuenta
       and s.fec_cierre = v_fec_maxima;
  elsif pi_tipo = 'M' then
    -- Dias de Mora --
    Select t.dia_mora
      into v_return
      from ta_cta_tarjetas t
     where t.nro_cuenta = p_nro_cuenta;
  elsif pi_tipo = 'I' then
    -- Importe de dias de Mora --
    Select t.mto_mora
      into v_return
      from ta_cta_tarjetas t
     where t.nro_cuenta = p_nro_cuenta;
  elsif pi_tipo = 'F' then
      -- Importe de Fecha de Debito --
      select max(mo.fecha)
        into v_return
        from ta_movimientos_his mo
       where cod_tra_padre = 986
         and mo.nro_cuenta = p_nro_cuenta
         and cod_transaccion = 978;
  elsif pi_tipo = 'E' then   
     -- Importe del Debito --
      select sum(mo.monto)
        into v_return
        from ta_movimientos_his mo
       where cod_tra_padre = 986
         and mo.nro_cuenta = p_nro_cuenta
         and mo.fecha = ((select max(mo.fecha)
                            from ta_movimientos_his mo
                           where cod_tra_padre = 986
                             and cod_transaccion = 978
                             and mo.nro_cuenta = p_nro_cuenta));
  end if;
  return v_return;
exception
  when no_data_found then
    return('No existe el dato en el cierre de tarjeta');
End;
/

