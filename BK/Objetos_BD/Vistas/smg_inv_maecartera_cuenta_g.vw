create or replace force view it.smg_inv_maecartera_cuenta_g as
select
'G' tip_saldo,
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
'G' tip_saldo,
mae.sucursalfu,
mae.nuries,
inv.nro_cuenta numero_cuenta_it_it,
mae.numero_cuenta_it as numero_cuenta_it_as,
decode(mae.iaddivisa,'0','GS','5','USD','17','EUR') cod_moneda,
inv.nombre,
mae.rubro_as,
inv.cod_rub_externo cod_rub_externo,
nvl(mae.guaranies,0) as saldo_as,
nvl(inv.sal_actual,0) as saldo_it,
(nvl(mae.guaranies,0) - nvl(inv.sal_actual,0)) as dif_saldo,
case  when nvl(inv.cod_rub_externo,0) <> nvl(mae.rubro_as,0) then 'SI' else 'NO' end diferencia_rubro

from
(select  FUB_smg_OBT_CTA_IT(a.sucursalfu,a.propuesta,a.nuries) numero_cuenta_it, a.sucursalfu,
sum(case when a.IADDIVISA = 0 then a.guaranies else a.CONTRAVALO end) guaranies, a.congru rubro_as, a.nuries, a.iaddivisa from
bbva.maeact_maecartera a where a.congru in ('257002000532','257002000540','257002000605','257002000613')
 group by a.sucursalfu, a.propuesta, a.nuries, a.congru, a.iaddivisa
 order by a.congru, FUB_smg_OBT_CTA_IT(a.sucursalfu,a.propuesta,a.nuries) desc) mae

left join

(select i.cod_rub_externo, i.cod_moneda,
i.sal_actual  sal_actual, i.nro_cuenta, i.nombre, i.cod_rubro from simgia_invengen i where i.tip_saldo = 'G'
order by i.cod_rub_externo, i.nro_cuenta desc) inv

on inv.nro_cuenta = mae.numero_cuenta_it

union

select
'G' tip_saldo,
mae.sucursalfu,
mae.nuries,
inv.nro_cuenta numero_cuenta_it_it,
mae.numero_cuenta_it as numero_cuenta_it_as,
decode(mae.iaddivisa,'0','GS','5','USD','17','EUR') cod_moneda,
inv.nombre,
mae.rubro_as,
inv.cod_rub_externo cod_rub_externo,
nvl(mae.guaranies,0) as saldo_as,
nvl(inv.sal_actual,0) as saldo_it,
(nvl(mae.guaranies,0) - nvl(inv.sal_actual,0)) as dif_saldo,
case  when nvl(inv.cod_rub_externo,0) <> nvl(mae.rubro_as,0) then 'SI' else 'NO' end diferencia_rubro

from

(select FUB_smg_OBT_CTA_IT(a.sucursalfu,a.propuesta,a.nuries) numero_cuenta_it, a.sucursalfu,
sum(case when a.IADDIVISA = 0 then a.guaranies else a.CONTRAVALO end) guaranies, a.congru rubro_as, a.nuries, a.iaddivisa from
bbva.maeact_maecartera a where a.congru in ('257002000532','257002000540','257002000605','257002000613')
group by a.sucursalfu, a.propuesta, a.nuries, a.congru, a.iaddivisa order by a.congru desc) mae

right join

(select i.cod_rub_externo, i.cod_moneda,
i.sal_actual  sal_actual, i.nro_cuenta, i.nombre, i.cod_rubro from simgia_invengen i where i.tip_saldo = 'G'
order by i.cod_rub_externo desc) inv

on inv.nro_cuenta = mae.numero_cuenta_it;*/;

