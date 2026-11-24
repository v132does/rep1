create or replace force view it.smg_cua_armamay_sal_oficina2 as
select a.msuc, (a.mcta || lpad(a.msubcta,6,0)) cta_as, b.cod_rubro cta_it, b.cod_moneda,
       a.saldoact saldo_gs_as,
       a.saldoactme saldo_me_as,
       saldo_gs saldo_gs_it,
       saldo_me saldo_me_it,
       a.saldoact+saldo_gs diff_gs ,
       saldoactme+saldo_me diff_me
from it.simgia_armamay a,
       (select c.cod_oficina, c.cod_rubro, r.cod_rub_externo, r.cod_moneda,
             (nvl(c.sal_mon_loc_ant,0)+nvl(c.deb_mon_local,0)-nvl(c.cre_mon_local,0))/*+
             (nvl(c.sal_equ_loc_ant,0)+nvl(c.deb_equ_local,0)-nvl(c.cre_equ_local,0))*/
              saldo_gs,
             (nvl(c.sal_mon_rub_ant,0)+nvl(c.deb_mon_rubro,0)-nvl(c.cre_mon_rubro,0)) saldo_me
         from it.cb_sal_oficinas c, cb_rubros r
        where r.cod_rubro=c.cod_rubro) b
where a.msuc = b.cod_oficina(+)
and (a.mcta || lpad(a.msubcta,6,0)) = b.cod_rub_externo(+)
and (a.saldoact <> 0 or a.saldoactme <>0
or b.saldo_gs <> 0 or b.saldo_me <> 0)
--and (a.saldoact+saldo_gs<>0 or saldoactme+saldo_me<>0)
UNION ALL
select b.cod_oficina, b.cod_rub_externo cta_as, b.cod_rubro cta_it, b.cod_moneda,
       0 saldo_gs_as,
       0 saldo_me_as,
       saldo_gs saldo_gs_it,
       saldo_me saldo_me_it,
       saldo_gs diff_gs ,
       saldo_me diff_me
from   (select c.cod_oficina, c.cod_rubro, r.cod_rub_externo, r.cod_moneda,
             (nvl(c.sal_mon_loc_ant,0)+nvl(c.deb_mon_local,0)-nvl(c.cre_mon_local,0))/*+
             (nvl(c.sal_equ_loc_ant,0)+nvl(c.deb_equ_local,0)-nvl(c.cre_equ_local,0))*/
              saldo_gs,
             (nvl(c.sal_mon_rub_ant,0)+nvl(c.deb_mon_rubro,0)-nvl(c.cre_mon_rubro,0)) saldo_me
         from it.cb_sal_oficinas c, cb_rubros r
        where r.cod_rubro=c.cod_rubro
          and r.imputable='S') b
where not exists( select 1 from it.simgia_armamay a
                   where a.msuc = b.cod_oficina
                     and (a.mcta || lpad(a.msubcta,6,0)) = b.cod_rub_externo)
and (b.saldo_gs <> 0 or b.saldo_me <>0)
order by 1,3
;

