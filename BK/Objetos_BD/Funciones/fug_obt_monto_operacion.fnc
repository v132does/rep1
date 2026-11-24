create or replace function it.fug_obt_monto_operacion
 (p_nro_cuenta in ge_cuentas.nro_cuenta%type,pi_tip_monto in char)
 return number
 is
 v_mon_oper number :=0 ;
 v_cod_modulo ge_cuentas.cod_modulo%type;
 v_fec_actual         date := pag_cal.FU_OBT_FEC_ACTUAL(1);
begin
    -- Extrae el Módulo --
     Select cod_modulo
      into v_cod_modulo
      from ge_cuentas
     where nro_cuenta = p_nro_cuenta;
    if pi_tip_monto = 'A' then -- Atrasos
          if v_cod_modulo = 6 then  -- Préstamos
            Select sum(nvl(sal_capital, 0) + nvl(sal_interes, 0))
              into v_mon_oper
             from pr_cuotas
            where nro_cuenta = p_nro_cuenta
              and (v_fec_actual - fec_vencimiento) > 0
              and nvl(sal_capital, 0) > 0
            order by nro_cuota;
          elsif v_cod_modulo = 4 then -- Sobregiro
                Select sum(sal_total)
                  into v_mon_oper
                  from cc_sobregiros c
                 where c.nro_cuenta = p_nro_cuenta
                   and c.fecha = (Select max(c.fecha)
                                    from cc_sobregiros c
                                   where c.nro_cuenta = p_nro_cuenta);
          elsif  v_cod_modulo = 5 then -- Tarjeta
              Select sum(t.mto_mora)
                into v_mon_oper
                from ta_cta_tarjetas t, ge_cta_clientes c
               where t.nro_cuenta = c.nro_cuenta
                 and t.nro_cuenta = p_nro_cuenta
                 and c.relacion = 'P';
          end if;
     elsif pi_tip_monto = 'P' then -- Monto Pagado
            if v_cod_modulo = 6 then  -- Préstamos
                  Select sum(mto_capital + mto_interes)
                    into v_mon_oper
                    from pr_cobros
                   where nro_cuenta = p_nro_cuenta ;
           elsif v_cod_modulo = 4 then -- Sobregiro
                    Select (s.sal_tot_batch - s.sal_total)
                      into v_mon_oper
                      from cc_cta_corrientes s
                     where nro_cuenta = p_nro_cuenta;
          elsif  v_cod_modulo = 5 then -- Tarjeta
                   Select sum(monto)
                     into v_mon_oper
                     from ta_cobros
                    where nro_cuenta = p_nro_cuenta
                      and estado in ('P', 'C');
          end if;
     end if;
return nvl(v_mon_oper,0);
exception when others then
    return 0;
end;
/

