create or replace force view it.smg_cua_armamay_sal_oficina as
select a.msuc, (a.mcta || lpad(a.msubcta,6,0))cta_as, b.cod_rubro cta_it, b.cod_moneda,
       a.saldoact saldo_gs_as,
       a.saldoactme saldo_me_as,
       saldo_gs saldo_gs_it,
       saldo_me saldo_me_it,
       a.saldoact+saldo_gs diff_gs ,
       saldoactme+saldo_me diff_me
from it.simgia_armamay a,
       (select c.cod_oficina, c.cod_rubro, r.cod_rub_externo, r.cod_moneda,
             (nvl(c.sal_mon_loc_ant,0)+nvl(c.deb_mon_local,0)-nvl(c.cre_mon_local,0)) saldo_gs,
             (nvl(c.sal_mon_rub_ant,0)+nvl(c.deb_mon_rubro,0)-nvl(c.cre_mon_rubro,0)) saldo_me
         from it.cb_sal_oficinas c, cb_rubros r
        where r.cod_rubro=c.cod_rubro) b
where a.msuc = b.cod_oficina
and (a.mcta || lpad(a.msubcta,6,0)) = cod_rub_externo
order by 1,3;

