create or replace function it.fut_obt_sal_adelanto(p_nro_cuenta in ta_cta_tarjetas.nro_cuenta%type)
  return number is

  v_dis_adelanto    ge_movimientos.monto%type;
  v_sal_disponible  ge_movimientos.monto%type;
  v_cod_modulo       ba_modulos.cod_modulo%type;
  v_cod_modalidad    ge_modalidades.cod_modalidad%type;
  v_por_adelanto     number(5,2);
begin

   begin
    select a.cod_modulo,
           a.cod_modalidad
      into v_cod_modulo,
           v_cod_modalidad
      from ta_cta_tarjetas a
     where a.nro_cuenta = p_nro_cuenta
     and rownum=1;
  exception
    when no_data_found then
       raise_application_error(-20000,'No existe Tarjeta'|| sqlerrm);
    when others then
      raise_application_error(-20000,'Otro Error'||  sqlerrm);
  end;

  v_por_adelanto:= 0;
  v_por_adelanto:= nvl(fug_obt_pardinamico('POR_ADE_TARJETA',
                                     5,
                                     v_cod_modalidad),0); 
  if v_por_adelanto <> 0 then
     --Convertimos a porcentaje
     v_por_adelanto:= v_por_adelanto /100;
  end if;

  select nvl(((t.lin_credito * /*0.3*/v_por_adelanto) -
             nvl((select sum(nvl(a.monto, 0))
                    from ta_movimientos_his a
                   where a.cod_transaccion in (251, 1251, 5154)
                     and a.nro_secuencia = 1
                     and a.fecha between t.fec_ult_cierre and
                         t.fec_vct_ult_cierre
                     and a.nro_cuenta = t.nro_cuenta),
                  0)) - nvl((select sum(nvl(a.monto, 0)) as monto_m
                              from ge_movimientos a
                             where a.cod_transaccion in (251, 1251, 5154)
                               and a.reversado = 'N'
                               and a.nro_secuencia = 1
                               and a.nro_cuenta = t.nro_cuenta),
                            0),
             0) - nvl((select sum(nvl(a.monto, 0)) as monto_m
                              from ge_movimientos_noc a
                             where a.cod_transaccion in (251, 1251, 5154)
                               and a.reversado = 'N'
                               and a.nro_secuencia = 1
                               and a.nro_cuenta = t.nro_cuenta),
                            0)  as disponible_adelanto,

               nvl(lin_credito, 0) -
             (nvl(t.sal_facturar, 0) + nvl(t.sal_financiado, 0) +
             nvl(t.sal_facturado, 0) + nvl(t.sal_cuo_pendientes, 0)) as sal_disponible


    into v_dis_adelanto,
         v_sal_disponible
    from ta_cta_tarjetas t
   where t.nro_cuenta = p_nro_cuenta;

   if v_sal_disponible > v_dis_adelanto then
       return (v_dis_adelanto);
   else
       return (v_sal_disponible);
   end if;
exception
  when others then
    raise_application_error(-20000, sqlerrm);

end fut_obt_sal_adelanto;
/

