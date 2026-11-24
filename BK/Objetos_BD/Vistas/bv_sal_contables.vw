create or replace force view it.bv_sal_contables as
select
a.cod_rubro,
b.descripcion,
a.cod_oficina,
cod_moneda,
decode(b.cod_moneda,'GS',(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0)),
(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))) sal_contable
from cb_rubros b, cb_sal_oficinas a
where a.cod_rubro = b.cod_rubro
and substr(a.cod_rubro,1,1) in ('1','2','4','5')
and decode(b.cod_moneda,'GS',(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0)),
(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))) <> 0;

