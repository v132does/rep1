create or replace procedure it.xx_arregla_inidia_cta_ban is
-- cta bancarias, regularizar el doble debito y doble credito
  cursor c_arregla is
  select a.nro_cuenta, a.sal_total, a.sal_tot_batch, p.mto_debito, p.mto_credito
    from cc_cta_bancarias a, (select nro_cuenta, sum(decode(x.cod_transaccion,503,x.monto,0)) mto_debito,
                                                 sum(decode(x.cod_transaccion,602,x.monto,0)) mto_credito
                                from ge_movimientos_noc_xxjj x
                               where cod_transaccion in (503,602)
                               group by nro_cuenta) p
   where a.nro_cuenta=p.nro_cuenta;
begin
   for reg in c_arregla loop
           --- Doble debito, credito
           UPDATE CC_CTA_BANCARIAS A
              SET (A.SAL_TOTAL) = a.sal_total + nvl(reg.mto_debito,0) - nvl(reg.mto_credito,0)
            WHERE A.NRO_CUENTA = reg.NRO_CUENTA;
   end loop;
end;
/

