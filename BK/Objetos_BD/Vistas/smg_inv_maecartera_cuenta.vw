create or replace force view it.smg_inv_maecartera_cuenta as
select cod_modalidad,
'C' tip_saldo,
'' cod_rubro,
0 sucursalfu,
'' nuries,
0 numero_cuenta_it_it,
0 numero_cuenta_it_as,
'GS' cod_moneda,
'prueba' nombre,
'' rubro_as,
0 cuenta_maeicpc,
'' cod_rub_externo,
0 saldo_as,
0 saldo_maeicpc,
0 saldo_it,
0 dif_saldo,
'NO'  diferencia_rubro,
'0' plazo_it,
'0' bcp1_it FROM ge_modalidades

/*select inv.cod_modalidad,
'C' tip_saldo,
inv.cod_rubro,
mae.sucursalfu,
mae.nuries,
inv.nro_cuenta numero_cuenta_it_it,
mae.numero_cuenta_it as numero_cuenta_it_as,
inv.cod_moneda,
inv.nombre,
mae.rubro_as,
0 cuenta_maeicpc,
inv.cod_rub_externo,
nvl(mae.guaranies,0) as saldo_as,
0 saldo_maeicpc,
nvl(inv.sal_actual,0) as saldo_it,
(nvl(mae.guaranies,0) - nvl(inv.sal_actual,0)) as dif_saldo,
case  when nvl(inv.cod_rub_externo,0) <> mae.rubro_as then 'SI' else 'NO' end diferencia_rubro,
substr(mae.rubro_as, 4, 1) as plazo_as, substr(inv.cod_rub_externo, 4, 1) as plazo_it,
substr(mae.rubro_as, 1, 3) as bcp1_as, substr(inv.cod_rub_externo, 1, 3) as bcp1_it

from

(select FUB_smg_OBT_CTA_IT(a.sucursalfu,a.propuesta,a.nuries) numero_cuenta_it, a.sucursalfu, nc.scheme_code modalidad_as,
sum(case when a.IADDIVISA = 0 then a.guaranies else a.CONTRAVALO end) guaranies, a.congru rubro_as, a.nuries from
bbva.maeact_maecartera a left join bbva.loans_numero_cuenta nc on a.SUCURSALFU = nc.sucursalfu and a.PROPUESTA = nc.propuesta
and a.congru = nc.congru and a.nuries = nc.nuries
group by a.sucursalfu, a.propuesta, a.nuries, a.congru, a.iaddivisa, nc.scheme_code) mae


right join

(select i.cod_rub_externo, i.cod_moneda, i.cod_modalidad,
sum(i.sal_actual) as sal_actual, i.nro_cuenta, i.nombre, i.cod_rubro from simgia_invengen i where i.tip_saldo = 'C'
group by i.cod_rub_externo,i.cod_moneda, i.nro_cuenta, i.nombre, i.cod_rubro, cod_modalidad) inv

on inv.nro_cuenta = mae.numero_cuenta_it
group by inv.cod_modalidad, mae.modalidad_as, mae.nuries, mae.numero_cuenta_it, inv.nro_cuenta, inv.cod_moneda, inv.nombre,
mae.rubro_as, inv.cod_rub_externo, mae.guaranies, inv.sal_actual, mae.sucursalfu, inv.cod_rubro


---------------------------------------------interes----------------------------------------------------
union all



select mae.modalidad_as,
'I' tip_saldo,
inv.cod_rubro,
mae.sucursalfu,
mae.nuries,
inv.nro_cuenta numero_cuenta_it_it,
mae.numero_cuenta_it as numero_cuenta_it_as,
decode(mae.iaddivisa,'0','GS','5','USD','17','EUR') cod_moneda,
inv.nombre,
mae.rubro_as,
maei.cuenta_maeicpc,
inv.cod_rub_externo,
nvl(mae.guaranies, 0) as saldo_as,
nvl(maei.saldo_maeicpc,0),
nvl(inv.sal_actual, 0) as saldo_it,
((nvl(mae.guaranies,0)+nvl(maei.saldo_maeicpc,0)) - nvl(inv.sal_actual,0)) as dif_saldo,
case  when nvl(inv.cod_rub_externo,0) <> mae.rubro_as then 'SI' else 'NO' end diferencia_rubro,
substr(mae.rubro_as, 4, 1) as plazo_as, substr(inv.cod_rub_externo, 4, 1) as plazo_it,
substr(mae.rubro_as, 1, 3) as bcp1_as, substr(inv.cod_rub_externo, 1, 3) as bcp1_it

from

(select FUB_smg_OBT_CTA_IT(a.sucursalfu,a.propuesta,a.nuries) numero_cuenta_it, nc.scheme_code modalidad_as, a.iaddivisa, a.sucursalfu,
sum(IADINTERES) guaranies, a.ctadocact rubro_as, a.nuries from
smg_maeact_maecartera a left join smg_loans_numero_cuenta nc on a.SUCURSALFU = nc.sucursalfu and a.PROPUESTA = nc.propuesta
and a.nuries = nc.nuries where a.ctadocact <> 0 group by a.sucursalfu, a.propuesta, a.nuries, a.ctadocact, a.iaddivisa, nc.scheme_code) mae

left join

(select sum(u.intdev+u.intnodev) saldo_maeicpc , u.ctaactivo cuenta_maeicpc,
FUB_smg_OBT_CTA_IT(u.sucursal,u.propuesta,u.riesgo) numero_cuenta_it
from smg_maeact_maeicpc u GROUP BY u.ctaactivo, u.sucursal,u.propuesta,u.riesgo) maei on maei.numero_cuenta_it = mae.numero_cuenta_it

left join

(select i.cod_rub_externo, i.cod_moneda, i.cod_modalidad,
sum(i.sal_actual) as sal_actual, i.nro_cuenta, i.nombre, i.cod_rubro from simgia_invengen i where i.tip_saldo = 'I'
group by i.cod_rub_externo,i.cod_moneda, i.nro_cuenta, i.nombre, i.cod_rubro, cod_modalidad) inv

on inv.nro_cuenta = mae.numero_cuenta_it
group by mae.modalidad_as, mae.nuries, mae.numero_cuenta_it, inv.nro_cuenta, inv.cod_moneda, inv.nombre,maei.cuenta_maeicpc,maei.saldo_maeicpc,
mae.rubro_as, inv.cod_rub_externo, mae.guaranies, inv.sal_actual, mae.iaddivisa, inv.cod_rubro, mae.sucursalfu

union

select inv.cod_modalidad,
'I' tip_saldo,
inv.cod_rubro,
mae.sucursalfu,
mae.nuries,
inv.nro_cuenta numero_cuenta_it_it,
mae.numero_cuenta_it as numero_cuenta_it_as,
inv.cod_moneda,
inv.nombre,
mae.rubro_as,
maei.cuenta_maeicpc,
inv.cod_rub_externo,
nvl(mae.guaranies, 0) as saldo_as,
nvl(maei.saldo_maeicpc,0),
nvl(inv.sal_actual, 0) as saldo_it,
((nvl(mae.guaranies,0)+nvl(maei.saldo_maeicpc,0)) - nvl(inv.sal_actual,0))as dif_saldo,
case  when nvl(inv.cod_rub_externo,0) <> mae.rubro_as then 'SI' else 'NO' end diferencia_rubro,
substr(mae.rubro_as, 4, 1) as plazo_as, substr(inv.cod_rub_externo, 4, 1) as plazo_it,
substr(mae.rubro_as, 1, 3) as bcp1_as, substr(inv.cod_rub_externo, 1, 3) as bcp1_it

from

(select FUB_smg_OBT_CTA_IT(a.sucursalfu,a.propuesta,a.nuries) numero_cuenta_it, nc.scheme_code modalidad_as, a.iaddivisa, a.sucursalfu,
sum(IADINTERES) guaranies, a.ctadocact rubro_as, a.nuries from
bbva.maeact_maecartera a left join bbva.loans_numero_cuenta nc on a.SUCURSALFU = nc.sucursalfu and a.PROPUESTA = nc.propuesta
and a.nuries = nc.nuries where a.ctadocact <> 0 group by a.sucursalfu, a.propuesta, a.nuries, a.ctadocact, a.iaddivisa, nc.scheme_code) mae



right join

(select i.cod_rub_externo, i.cod_moneda, i.cod_modalidad,
sum(i.sal_actual) as sal_actual, i.nro_cuenta, i.nombre, i.cod_rubro from simgia_invengen i where i.tip_saldo = 'I'
group by i.cod_rub_externo,i.cod_moneda, i.nro_cuenta, i.nombre, i.cod_rubro, cod_modalidad) inv

on inv.nro_cuenta = mae.numero_cuenta_it

left join

(select sum(u.intdev+u.intnodev) saldo_maeicpc , u.ctaactivo cuenta_maeicpc,
FUB_smg_OBT_CTA_IT(u.sucursal,u.propuesta,u.riesgo) numero_cuenta_it
from bbva.maeact_maeicpc u GROUP BY u.ctaactivo, u.sucursal,u.propuesta,u.riesgo) maei on maei.numero_cuenta_it = inv.nro_cuenta

group by inv.cod_modalidad, mae.modalidad_as, mae.nuries, mae.numero_cuenta_it, inv.nro_cuenta, inv.cod_moneda, inv.nombre,maei.cuenta_maeicpc,maei.saldo_maeicpc,
mae.rubro_as, inv.cod_rub_externo, mae.guaranies, inv.sal_actual, mae.iaddivisa, inv.cod_rubro, mae.sucursalfu


--------------------------------------------------a devengar-----------------------------------------------
union all



select mae.modalidad_as,
'A' tip_saldo,
inv.cod_rubro,
mae.sucursalfu,
mae.nuries,
inv.nro_cuenta numero_cuenta_it_it,
mae.numero_cuenta_it as numero_cuenta_it_as,
decode(mae.iaddivisa,'0','GS','5','USD','17','EUR') cod_moneda,
inv.nombre,
mae.rubro_as,
maei.cuenta_maeicpc,
inv.cod_rub_externo,
nvl(mae.guaranies, 0) as saldo_as,
nvl(maei.saldo_maeicpc, 0),
nvl(inv.sal_actual, 0) as saldo_it,
((nvl(mae.guaranies,0) + nvl(maei.saldo_maeicpc, 0)) - nvl(inv.sal_actual,0)) as dif_saldo,
case  when nvl(inv.cod_rub_externo,0) <> mae.rubro_as then 'SI' else 'NO' end diferencia_rubro,
substr(mae.rubro_as, 4, 1) as plazo_as, substr(inv.cod_rub_externo, 4, 1) as plazo_it,
substr(mae.rubro_as, 1, 3) as bcp1_as, substr(inv.cod_rub_externo, 1, 3) as bcp1_it

from

(select FUB_smg_OBT_CTA_IT(a.sucursalfu,a.propuesta,a.nuries) numero_cuenta_it, nc.scheme_code modalidad_as, a.iaddivisa, a.sucursalfu,
sum(IADADEV) guaranies, a.CTADOCPAS rubro_as, a.nuries from
smg_maeact_maecartera a left join smg_loans_numero_cuenta nc on a.SUCURSALFU = nc.sucursalfu and a.PROPUESTA = nc.propuesta
and a.nuries = nc.nuries where a.ctadocpas <> 0 group by a.sucursalfu, a.propuesta, a.nuries, a.CTADOCPAS, a.iaddivisa, nc.scheme_code) mae

left join

(select sum(u.intnodev) saldo_maeicpc , u.ctapasivo cuenta_maeicpc,
FUB_smg_OBT_CTA_IT(u.sucursal,u.propuesta,u.riesgo) numero_cuenta_it
from smg_maeact_maeicpc u GROUP BY u.ctapasivo, u.sucursal,u.propuesta,u.riesgo) maei on maei.numero_cuenta_it = mae.numero_cuenta_it


left join

(select i.cod_rub_externo, i.cod_moneda, i.cod_modalidad,
sum(i.sal_actual) as sal_actual, i.nro_cuenta, i.nombre, i.cod_rubro from simgia_invengen i where i.tip_saldo = 'A'
group by i.cod_rub_externo,i.cod_moneda, i.nro_cuenta, i.nombre, i.cod_rubro, cod_modalidad) inv

on inv.nro_cuenta = mae.numero_cuenta_it
group by mae.modalidad_as, mae.nuries, mae.numero_cuenta_it, inv.nro_cuenta, inv.cod_moneda, inv.nombre,maei.cuenta_maeicpc,maei.saldo_maeicpc,
mae.rubro_as, inv.cod_rub_externo, mae.guaranies, inv.sal_actual, mae.iaddivisa, inv.cod_rubro, mae.sucursalfu

union

select inv.cod_modalidad,
'A' tip_saldo,
inv.cod_rubro,
mae.sucursalfu,
mae.nuries,
inv.nro_cuenta numero_cuenta_it_it,
mae.numero_cuenta_it as numero_cuenta_it_as,
inv.cod_moneda,
inv.nombre,
mae.rubro_as,
maei.cuenta_maeicpc,
inv.cod_rub_externo,
nvl(mae.guaranies, 0) as saldo_as,
nvl(maei.saldo_maeicpc, 0),
nvl(inv.sal_actual, 0) as saldo_it,
((nvl(mae.guaranies,0) + nvl(maei.saldo_maeicpc,0)) - nvl(inv.sal_actual,0)) as dif_saldo,
case  when nvl(inv.cod_rub_externo,0) <> mae.rubro_as then 'SI' else 'NO' end diferencia_rubro,
substr(mae.rubro_as, 4, 1) as plazo_as, substr(inv.cod_rub_externo, 4, 1) as plazo_it,
substr(mae.rubro_as, 1, 3) as bcp1_as, substr(inv.cod_rub_externo, 1, 3) as bcp1_it

from

(select FUB_smg_OBT_CTA_IT(a.sucursalfu,a.propuesta,a.nuries) numero_cuenta_it, nc.scheme_code modalidad_as, a.iaddivisa, a.sucursalfu,
sum(IADADEV) guaranies, a.CTADOCPAS rubro_as, a.nuries from
bbva.maeact_maecartera a left join bbva.loans_numero_cuenta nc on a.SUCURSALFU = nc.sucursalfu and a.PROPUESTA = nc.propuesta
and a.nuries = nc.nuries where a.ctadocpas <> 0 group by a.sucursalfu, a.propuesta, a.nuries, a.CTADOCPAS, a.iaddivisa, nc.scheme_code) mae



right join

(select i.cod_rub_externo, i.cod_moneda, i.cod_modalidad,
sum(i.sal_actual) as sal_actual, i.nro_cuenta, i.nombre, i.cod_rubro from simgia_invengen i where i.tip_saldo = 'A'
group by i.cod_rub_externo,i.cod_moneda, i.nro_cuenta, i.nombre, i.cod_rubro, cod_modalidad) inv

on inv.nro_cuenta = mae.numero_cuenta_it
left join

(select sum(u.intnodev) saldo_maeicpc , u.ctapasivo cuenta_maeicpc,
FUB_smg_OBT_CTA_IT(u.sucursal,u.propuesta,u.riesgo) numero_cuenta_it
from bbva.maeact_maeicpc u GROUP BY u.ctapasivo, u.sucursal,u.propuesta,u.riesgo) maei on maei.numero_cuenta_it =inv.nro_cuenta

group by inv.cod_modalidad, mae.modalidad_as, mae.nuries, mae.numero_cuenta_it, inv.nro_cuenta, inv.cod_moneda, inv.nombre,maei.cuenta_maeicpc,maei.saldo_maeicpc,
mae.rubro_as, inv.cod_rub_externo, mae.guaranies, inv.sal_actual, mae.iaddivisa, inv.cod_rubro, mae.sucursalfu

----------------------------------------------------suspenso----------------------------------------

union all

---maestro maeicpc
select 99 cod_modalidad,
'S' tip_saldo,
inv.cod_rubro,
maei.sucursal,
maei.riesgo,
inv.nro_cuenta numero_cuenta_it_it,
maei.numero_cuenta_it as numero_cuenta_it_as,
decode(maei.divisa,'0','GS','5','USD','17','EUR') cod_moneda,
inv.nombre,
mae.rubro_as,
maei.cuenta_maeicpc,
inv.cod_rub_externo,
nvl(mae.guaranies, 0) as saldo_as,
nvl(maei.saldo_maeicpc, 0),
nvl(inv.sal_actual, 0) as saldo_it,
((nvl(mae.guaranies,0) + nvl(maei.saldo_maeicpc,0)) - nvl(inv.sal_actual,0)) as dif_saldo,
case  when nvl(inv.cod_rub_externo,0) <> mae.rubro_as then 'SI' else 'NO' end diferencia_rubro,
substr(mae.rubro_as, 4, 1) as plazo_as, substr(inv.cod_rub_externo, 4, 1) as plazo_it,
substr(mae.rubro_as, 1, 3) as bcp1_as, substr(inv.cod_rub_externo, 1, 3) as bcp1_it

from

(select sum(u.devsusp) saldo_maeicpc , nc.divisa, u.riesgo, u.sucursal,
to_number(pai_int_f4.FU_OBT_CTA_INT_SUSPENSO(u.rubrocr, nc.divisa)) cuenta_maeicpc,
FUB_smg_OBT_CTA_IT(u.sucursal,u.propuesta,u.riesgo) numero_cuenta_it
from bbva.maeact_maeicpc u
left join (select w.congru, w.divisa from bbva.loans_numero_cuenta w group by w.congru, w.divisa) nc
on u.rubrocr = nc.congru
where u.devsusp > 0
GROUP BY to_number(pai_int_f4.FU_OBT_CTA_INT_SUSPENSO(u.rubrocr, nc.divisa)), nc.divisa,
u.rubrocr, u.sucursal, u.propuesta, u.riesgo) maei

left join

(select FUB_smg_OBT_CTA_IT(a.sucursalfu,a.propuesta,a.nuries) numero_cuenta_it,
a.iaddivisa,
a.sucursalfu,
sum(ctandocact) guaranies,
to_number(pai_int_f4.FU_OBT_CTA_INT_SUSPENSO(a.congru, a.iaddivisa)) rubro_as,
a.nuries
from bbva.maeact_maecartera a
left join (select w.congru, w.divisa from bbva.loans_numero_cuenta w group by w.congru, w.divisa) nc on a.congru = nc.congru
      where a.ctandocact > 0
group by a.sucursalfu, a.propuesta, a.nuries, to_number(pai_int_f4.FU_OBT_CTA_INT_SUSPENSO(a.congru, a.iaddivisa)), a.iaddivisa) mae
 on maei.numero_cuenta_it = mae.numero_cuenta_it

left join

(select i.cod_rub_externo,
i.cod_moneda,
sum(i.sal_actual) as sal_actual,
i.nro_cuenta,
i.nombre,
i.cod_rubro
from simgia_invengen i
where i.tip_saldo = 'S'
group by i.cod_rub_externo,i.cod_moneda, i.nro_cuenta, i.nombre, i.cod_rubro) inv
on inv.nro_cuenta = maei.numero_cuenta_it

group by  maei.riesgo, maei.numero_cuenta_it, inv.nro_cuenta, inv.cod_moneda, inv.nombre,maei.cuenta_maeicpc,maei.saldo_maeicpc,
mae.rubro_as, inv.cod_rub_externo, mae.guaranies, inv.sal_actual, maei.divisa, inv.cod_rubro, maei.sucursal

--maestro maecartera
union

select 99 cod_modalidad,
'S' tip_saldo,
inv.cod_rubro,
mae.sucursalfu,
mae.nuries,
inv.nro_cuenta numero_cuenta_it_it,
mae.numero_cuenta_it numero_cuenta_it_as,
decode(mae.iaddivisa,'0','GS','5','USD','17','EUR') cod_moneda,
inv.nombre,
mae.rubro_as,
maei.cuenta_maeicpc,
inv.cod_rub_externo,
nvl(mae.guaranies, 0)  saldo_as,
nvl(maei.saldo_maeicpc, 0),
nvl(inv.sal_actual, 0)  saldo_it,
((nvl(mae.guaranies,0) + nvl(maei.saldo_maeicpc,0)) - nvl(inv.sal_actual,0)) as dif_saldo,
case  when nvl(inv.cod_rub_externo,0) <> mae.rubro_as then 'SI' else 'NO' end diferencia_rubro,
substr(mae.rubro_as, 4, 1) as plazo_as, substr(inv.cod_rub_externo, 4, 1) as plazo_it,
substr(mae.rubro_as, 1, 3) as bcp1_as, substr(inv.cod_rub_externo, 1, 3) as bcp1_it

from

(select FUB_smg_OBT_CTA_IT(a.sucursalfu,a.propuesta,a.nuries) numero_cuenta_it,
a.iaddivisa,
a.sucursalfu,
sum(ctandocact) guaranies,
to_number(pai_int_f4.FU_OBT_CTA_INT_SUSPENSO(a.congru, a.iaddivisa)) rubro_as,
a.nuries
from bbva.maeact_maecartera a
left join (select w.congru, w.divisa from bbva.loans_numero_cuenta w group by w.congru, w.divisa) nc
on a.congru = nc.congru  where a.ctandocact > 0
group by a.sucursalfu, a.propuesta, a.nuries, to_number(pai_int_f4.FU_OBT_CTA_INT_SUSPENSO(a.congru, a.iaddivisa)),
a.iaddivisa) mae


left join

(select i.cod_rub_externo,
i.cod_moneda,
sum(i.sal_actual) as sal_actual,
i.nro_cuenta,
i.nombre,
i.cod_rubro
from simgia_invengen i
where i.tip_saldo = 'S'
group by i.cod_rub_externo, i.cod_moneda, i.nro_cuenta, i.nombre, i.cod_rubro) inv
on inv.nro_cuenta = mae.numero_cuenta_it

left join

(select sum(u.devsusp) saldo_maeicpc ,
to_number(pai_int_f4.FU_OBT_CTA_INT_SUSPENSO(u.rubrocr, nc.divisa)) cuenta_maeicpc,
FUB_smg_OBT_CTA_IT(u.sucursal,u.propuesta,u.riesgo) numero_cuenta_it
from bbva.maeact_maeicpc u
left join (select w.congru, w.divisa from bbva.loans_numero_cuenta w group by w.congru, w.divisa) nc
on u.rubrocr = nc.congru where u.devsusp > 0
GROUP BY to_number(pai_int_f4.FU_OBT_CTA_INT_SUSPENSO(u.rubrocr, nc.divisa)),
u.rubrocr, u.sucursal,u.propuesta,u.riesgo) maei on maei.numero_cuenta_it = mae.numero_cuenta_it

group by mae.nuries, mae.numero_cuenta_it, inv.nro_cuenta, inv.cod_moneda, inv.nombre,maei.cuenta_maeicpc,maei.saldo_maeicpc,
mae.rubro_as, inv.cod_rub_externo, mae.guaranies, inv.sal_actual, mae.iaddivisa, inv.cod_rubro, mae.sucursalfu

union

----maestro invengen
select 99 cod_modalidad,
'S' tip_saldo,
inv.cod_rubro,
nvl(mae.sucursalfu, maei.sucursal),
nvl(mae.nuries, maei.riesgo),
inv.nro_cuenta numero_cuenta_it_it,
nvl(mae.numero_cuenta_it,maei.numero_cuenta_it) as numero_cuenta_it_as,
inv.cod_moneda,
inv.nombre,
mae.rubro_as,
maei.cuenta_maeicpc,
inv.cod_rub_externo,
nvl(mae.guaranies, 0) as saldo_as,
nvl(maei.saldo_maeicpc, 0),
nvl(inv.sal_actual, 0) as saldo_it,
((nvl(mae.guaranies,0) + nvl(maei.saldo_maeicpc,0)) - nvl(inv.sal_actual,0)) as dif_saldo,
case  when nvl(inv.cod_rub_externo,0) <> mae.rubro_as then 'SI' else 'NO' end diferencia_rubro,
substr(mae.rubro_as, 4, 1) as plazo_as, substr(inv.cod_rub_externo, 4, 1) as plazo_it,
substr(mae.rubro_as, 1, 3) as bcp1_as, substr(inv.cod_rub_externo, 1, 3) as bcp1_it

from

(select FUB_smg_OBT_CTA_IT(a.sucursalfu,a.propuesta,a.nuries) numero_cuenta_it,
a.iaddivisa,
a.sucursalfu,
sum(a.ctandocact) guaranies,
to_number(pai_int_f4.FU_OBT_CTA_INT_SUSPENSO(a.congru, a.iaddivisa)) rubro_as,
a.nuries
from bbva.maeact_maecartera a
left join (select w.congru, w.divisa from bbva.loans_numero_cuenta w group by w.congru, w.divisa) nc on a.congru = nc.congru
      where a.ctandocact > 0
group by  a.sucursalfu, a.propuesta, a.nuries, to_number(pai_int_f4.FU_OBT_CTA_INT_SUSPENSO(a.congru, a.iaddivisa)), a.iaddivisa) mae


right join

(select i.cod_rub_externo,
i.cod_moneda,
sum(i.sal_actual) as sal_actual,
i.nro_cuenta,
i.nombre,
i.cod_rubro
from simgia_invengen i
where i.tip_saldo = 'S'
group by i.cod_rub_externo,i.cod_moneda, i.nro_cuenta, i.nombre, i.cod_rubro) inv
on inv.nro_cuenta = mae.numero_cuenta_it

left join

(select sum(u.devsusp) saldo_maeicpc , u.sucursal, u.riesgo,
to_number(pai_int_f4.FU_OBT_CTA_INT_SUSPENSO(u.rubrocr, nc.divisa)) cuenta_maeicpc,
FUB_smg_OBT_CTA_IT(u.sucursal,u.propuesta,u.riesgo) numero_cuenta_it
from bbva.maeact_maeicpc u
left join (select w.congru, w.divisa from bbva.loans_numero_cuenta w group by w.congru, w.divisa) nc
on u.rubrocr = nc.congru where u.devsusp > 0
GROUP BY to_number(pai_int_f4.FU_OBT_CTA_INT_SUSPENSO(u.rubrocr, nc.divisa)),
u.rubrocr, u.sucursal,u.propuesta,u.riesgo) maei on maei.numero_cuenta_it =inv.nro_cuenta

group by  maei.riesgo, maei.numero_cuenta_it, maei.sucursal, mae.nuries, mae.numero_cuenta_it, inv.nro_cuenta, inv.cod_moneda, inv.nombre,maei.cuenta_maeicpc,maei.saldo_maeicpc,
mae.rubro_as, inv.cod_rub_externo, mae.guaranies, inv.sal_actual, mae.iaddivisa, inv.cod_rubro, mae.sucursalfu


-----------------------------------------------------------iva--------------------------------------------------------------------
union all

---maestro invengen
select inv.cod_modalidad,
'Z' tip_saldo,
inv.cod_rubro,
mae.sucursalfu,
mae.nuries,
inv.nro_cuenta numero_cuenta_it_it,
mae.numero_cuenta_it as numero_cuenta_it_as,
inv.cod_moneda,
inv.nombre,
mae.rubro_as,
0 cuenta_maeicpc,
inv.cod_rub_externo,
nvl(mae.guaranies,0) as saldo_as,
0 saldo_maeicpc,
nvl(inv.sal_actual,0) as saldo_it,
(nvl(mae.guaranies,0) - nvl(inv.sal_actual,0)) as dif_saldo,
case  when nvl(inv.cod_rub_externo,0) <> mae.rubro_as then 'SI' else 'NO' end diferencia_rubro,
substr(mae.rubro_as, 4, 1) as plazo_as, substr(inv.cod_rub_externo, 4, 1) as plazo_it,
substr(mae.rubro_as, 1, 3) as bcp1_as, substr(inv.cod_rub_externo, 1, 3) as bcp1_it

from

(select FUB_smg_OBT_CTA_IT(a.sucursalfu,a.propuesta,a.nuries) numero_cuenta_it, a.sucursalfu, nc.scheme_code modalidad_as,
sum(case when a.IADDIVISA = 0 then a.guaranies else a.CONTRAVALO end) guaranies, a.congru rubro_as, a.nuries from
bbva.maeact_maecartera a left join bbva.loans_numero_cuenta nc on a.SUCURSALFU = nc.sucursalfu and a.PROPUESTA = nc.propuesta
and a.congru = nc.congru and a.nuries = nc.nuries group by a.sucursalfu, a.propuesta, a.nuries, a.congru, a.iaddivisa, nc.scheme_code) mae


right join

(select i.cod_rub_externo, i.cod_moneda, i.cod_modalidad,
sum(i.sal_actual) as sal_actual, i.nro_cuenta, i.nombre, i.cod_rubro from simgia_invengen i where i.tip_saldo = 'Z'
group by i.cod_rub_externo,i.cod_moneda, i.nro_cuenta, i.nombre, i.cod_rubro, cod_modalidad) inv

on inv.nro_cuenta = mae.numero_cuenta_it
group by inv.cod_modalidad, mae.modalidad_as, mae.nuries, mae.numero_cuenta_it, inv.nro_cuenta, inv.cod_moneda, inv.nombre,
mae.rubro_as, inv.cod_rub_externo, mae.guaranies, inv.sal_actual, mae.sucursalfu, inv.cod_rubro
*/
;

