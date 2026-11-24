create or replace force view it.smg_inv_cuenta_a as
select "SUCURSAL","CTA1","CTA2","TIPO","COD_MONEDA","MN","ME","DESCRIPCION" from
(select
a.sucursalfu sucursal,
substr(a.rubro_as,1,6) cta1,
substr(a.rubro_as,7,6) cta2,
2 tipo,
a.cod_moneda,
case when a.cod_moneda = 'GS' then a.saldo_maecartera_maeicpc else null end mn,
case when a.cod_moneda <> 'GS' then a.saldo_maecartera_maeicpc else null end  me,
'regul migra '||a.numero_cuenta_it_it  descripcion
from
smg_inv_maecartera_cuenta_a a where a.dif_saldo = 0 and a.diferencia_rubro = 'SI' and a.cod_rub_externo is not null
union
select
a.sucursalfu sucursal,
substr(a.cod_rub_externo,1,6) cta1,
substr(a.cod_rub_externo,7,6) cta2,
1 tipo,
a.cod_moneda,
case when a.cod_moneda = 'GS' then a.saldo_maecartera_maeicpc else null end mn,
case when a.cod_moneda <> 'GS' then a.saldo_maecartera_maeicpc else null end me,
'regul migra '||a.numero_cuenta_it_it descripcion
from
smg_inv_maecartera_cuenta_a a where a.dif_saldo = 0 and a.diferencia_rubro = 'SI' and a.cod_rub_externo is not null)
order by descripcion;

