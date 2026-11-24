create or replace force view it.smg_inv_maecartera_cuenta_a as
select
'A' tip_saldo,
cod_oficina sucursalfu,
'' nuries,
'' numero_cuenta_it_it,
'' numero_cuenta_it_as,
'GS'cod_moneda,
''nombre,
''rubro_as,
''cod_rub_externo,
0 saldo_maecartera,
0 saldo_maeicpc,
0 saldo_maecartera_maeicpc,
0 saldo_it,
0 dif_saldo,
'NO' diferencia_rubro

FROM ba_oficinas

/*select
'A' tip_saldo,
mae.sucursalfu,
mae.nuries,
inv.nro_cuenta numero_cuenta_it_it,
mae.numero_cuenta_it as numero_cuenta_it_as,
decode(mae.iaddivisa,'0','GS','5','USD','17','EUR') cod_moneda,
inv.nombre,
mae.rubro_as,
inv.cod_rub_externo,
nvl(mae.guaranies, 0)  saldo_maecartera,
nvl(maei.saldo_maeicpc,0) saldo_maeicpc,
nvl(mae.guaranies, 0) + nvl(maei.saldo_maeicpc,0) saldo_maecartera_maeicpc,
nvl(inv.sal_actual, 0) saldo_it,
((nvl(mae.guaranies,0)+nvl(maei.saldo_maeicpc,0)) - nvl(inv.sal_actual,0)) as dif_saldo,
case  when nvl(inv.cod_rub_externo,0) <> nvl(mae.rubro_as,0) then 'SI' else 'NO' end diferencia_rubro

from

(select FUB_smg_OBT_CTA_IT(a.sucursalfu,a.propuesta,a.nuries) numero_cuenta_it,
a.iaddivisa,
a.sucursalfu,
sum(a.IADADEV) guaranies,
a.CTADOCPAS rubro_as,
a.nuries from
bbva.maeact_maecartera a where a.IADADEV > 0 group by a.sucursalfu, a.propuesta, a.nuries, a.CTADOCPAS, a.iaddivisa) mae

left join

(select sum(u.intnodev) saldo_maeicpc, u.ctapasivo rubro_maeicpc,
FUB_smg_OBT_CTA_IT(u.sucursal,u.propuesta,u.riesgo) numero_cuenta_it
from bbva.maeact_maeicpc u GROUP BY u.ctapasivo, u.sucursal,u.propuesta,u.riesgo) maei
on maei.numero_cuenta_it = mae.numero_cuenta_it

left join

(select i.cod_rub_externo, i.cod_moneda, i.cod_modalidad,
i.sal_actual as sal_actual, i.nro_cuenta, i.nombre, i.cod_rubro from simgia_invengen i where i.tip_saldo = 'A') inv

on inv.nro_cuenta = mae.numero_cuenta_it

union
--maestro invengen
select
'A' tip_saldo,
nvl(mae.sucursalfu,maei.sucursal) sucursalfu,
nvl(mae.nuries,maei.riesgo) nuries,
inv.nro_cuenta numero_cuenta_it_it,
nvl(mae.numero_cuenta_it, maei.numero_cuenta_it) as numero_cuenta_it_as,
inv.cod_moneda,
inv.nombre,
nvl(mae.rubro_as,maei.rubro_maeicpc) rubro_as,
inv.cod_rub_externo,
nvl(mae.guaranies, 0) saldo_maecartera,
nvl(maei.saldo_maeicpc,0) saldo_maeicpc,
nvl(mae.guaranies, 0) + nvl(maei.saldo_maeicpc,0) saldo_maecartera_maeicpc,
nvl(inv.sal_actual, 0) saldo_it,
((nvl(mae.guaranies,0)+nvl(maei.saldo_maeicpc,0)) - nvl(inv.sal_actual,0))as dif_saldo,
case  when nvl(inv.cod_rub_externo,0) <> nvl(mae.rubro_as, maei.rubro_maeicpc) then 'SI' else 'NO' end diferencia_rubro

from

(select FUB_smg_OBT_CTA_IT(a.sucursalfu,a.propuesta,a.nuries) numero_cuenta_it,
a.iaddivisa,
a.sucursalfu,
sum(a.IADADEV) guaranies,
a.ctadocpas rubro_as,
a.nuries from
bbva.maeact_maecartera a where a.IADADEV > 0 group by a.sucursalfu, a.propuesta, a.nuries, a.ctadocpas, a.iaddivisa) mae

right join

(select i.cod_rub_externo, i.cod_moneda, i.cod_modalidad,
i.sal_actual as sal_actual, i.nro_cuenta, i.nombre, i.cod_rubro from simgia_invengen i where i.tip_saldo = 'A') inv

on inv.nro_cuenta = mae.numero_cuenta_it

left join

(select sum(u.intnodev) saldo_maeicpc, u.ctapasivo rubro_maeicpc, u.riesgo, u.sucursal,
FUB_smg_OBT_CTA_IT(u.sucursal,u.propuesta,u.riesgo) numero_cuenta_it
from bbva.maeact_maeicpc u GROUP BY u.ctapasivo, u.sucursal,u.propuesta,u.riesgo) maei

on maei.numero_cuenta_it = inv.nro_cuenta

union
--maestro maeicpc

select
'A' tip_saldo,
maei.sucursal,
maei.riesgo,
inv.nro_cuenta numero_cuenta_it_it,
maei.numero_cuenta_it as numero_cuenta_it_as,
decode(maei.divisa,'0','GS','5','USD','17','EUR') cod_moneda,
inv.nombre,
maei.rubro_maeicpc rubro_as,
inv.cod_rub_externo,
nvl(mae.guaranies, 0)  saldo_maecartera,
nvl(maei.saldo_maeicpc,0) saldo_maeicpc,
nvl(mae.guaranies, 0) + nvl(maei.saldo_maeicpc,0) saldo_maecartera_maeicpc,
nvl(inv.sal_actual, 0) saldo_it,
((nvl(mae.guaranies,0)+nvl(maei.saldo_maeicpc,0)) - nvl(inv.sal_actual,0)) as dif_saldo,
case  when nvl(inv.cod_rub_externo,0) <> nvl(maei.rubro_maeicpc,0) then 'SI' else 'NO' end diferencia_rubro

from

(select FUB_smg_OBT_CTA_IT(a.sucursalfu,a.propuesta,a.nuries) numero_cuenta_it,
a.iaddivisa,
a.sucursalfu,
sum(a.iadadev) guaranies,
a.ctadocpas rubro_as,
a.nuries from
bbva.maeact_maecartera a where a.iadadev > 0 group by a.sucursalfu, a.propuesta, a.nuries, a.ctadocpas, a.iaddivisa) mae

right join

(select sum(u.intnodev) saldo_maeicpc, u.ctapasivo rubro_maeicpc, nc.divisa, u.riesgo, u.sucursal,
FUB_smg_OBT_CTA_IT(u.sucursal,u.propuesta,u.riesgo) numero_cuenta_it
from bbva.maeact_maeicpc u join bbva.loans_numero_cuenta nc on u.propuesta = nc.propuesta
and u.riesgo = nc.nuries and u.sucursal = nc.sucursalfu
where substr(trim(u.rubrocr), 1, 3) not like '295'
and  u.intnodev > 0
GROUP BY u.ctapasivo, u.sucursal,u.propuesta,u.riesgo, nc.divisa) maei
on maei.numero_cuenta_it = mae.numero_cuenta_it

left join

(select i.cod_rub_externo, i.cod_moneda, i.cod_modalidad,
i.sal_actual as sal_actual, i.nro_cuenta, i.nombre, i.cod_rubro from simgia_invengen i where i.tip_saldo = 'A') inv

on inv.nro_cuenta = maei.numero_cuenta_it
;*/
;

