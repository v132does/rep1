create or replace force view it.gv_sal_cta_atm_cierre as
select c.cod_modulo, c.cod_modalidad, c.nro_cuenta, c.denominacion, c.cod_moneda, c.sal_total
from cc_cta_corrientes c, cc_cta_transaccionales t
where c.nro_cuenta = t.nro_cuenta
union all
select c.cod_modulo, c.cod_modalidad, c.nro_cuenta, c.denominacion, c.cod_moneda, c.sal_total
from cc_cta_bancarias c;

