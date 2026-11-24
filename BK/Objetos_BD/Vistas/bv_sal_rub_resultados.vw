create or replace force view it.bv_sal_rub_resultados as
select
a.cod_rubro,
b.descripcion,
a.cod_oficina,
cod_moneda,
(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0)) * -1 sal_contable
from cb_rubros b, cb_sal_oficinas a
where a.cod_rubro = b.cod_rubro
and substr(a.cod_rubro,1,1) in ('6','7')
and nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0) <> 0;

