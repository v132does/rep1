create or replace procedure it.xx_arregla_inidia_ctacte is
/* cta cte: regularizar creditos 613,615 */
  cursor c_arregla is
  select a.nro_cuenta, a.sal_total, a.sal_tot_batch, p.mto_credito
    from cc_cta_corrientes a, (select nro_cuenta, sum(x.monto) mto_credito
                                 from ge_movimientos_noc_xxjj x
                                where cod_transaccion in (613,615)
                                group by nro_cuenta) p
   where a.nro_cuenta=p.nro_cuenta;

begin
   for reg in c_arregla loop
           UPDATE CC_CTA_CORRIENTES A
              SET A.SAL_TOTAL    = a.sal_total    - NVL(reg.mto_credito,0)
                , A.SAL_RETENIDO = a.sal_retenido - NVL(reg.mto_credito,0)
            WHERE a.NRO_CUENTA = reg.NRO_CUENTA;
   end loop;
end;
/

