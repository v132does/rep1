create or replace procedure it.xx_arregla_inidia is
  cursor c_arregla is
  select a.nro_cuenta, a.sal_total, a.sal_tot_batch, a.mto_deb_pendientes, a.mto_cre_pendientes, a.mto_cre_a_confirmar, p.mto_debito
  from cc_cta_corrientes a,
  (select nro_cuenta, sum(decode(x.cod_transaccion,503,x.monto,602,x.monto*-1)) mto_debito
     from ge_movimientos_noc_xxjj x
     where cod_transaccion in (503,602)
     group by nro_cuenta) p
where a.nro_cuenta=p.nro_cuenta
and a.nro_cuenta !='0701451893'; ----'0102150093';--prueba inicial
begin
   for reg in c_arregla loop
   --   if nvl(reg.sal_tot_batch,0)-nvl(reg.mto_debito,0) <> nvl(reg.sal_total,0)
   --   and (nvl(reg.sal_tot_batch,0)-nvl(reg.mto_debito,0))-reg.sal_total=reg.mto_debito then
         --- Doble debito
         update cc_cta_corrientes
            set sal_total = sal_total + reg.mto_debito
          where nro_cuenta = reg.nro_cuenta;
   --   end if;
   end loop;
end;
/

