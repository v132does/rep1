create or replace force view it.bv_estratifiacion as
select x.fecha,x.concepto,x.tipo,x.plz_hasta,x.cod_moneda, x.mto_hasta, x.cantidad,x.monto
from(
select t.fecha,t.concepto,'Sector Privado'tipo,t.plz_hasta,t.cod_moneda, t.mto_hasta, sum(t.cantidad)cantidad,sum(nvl(t.monto,0))monto
from sb_estratificaciones_dep t where t.cod_moneda='GS'
and t.cod_sec_contable in('N','F')
and t.concepto='CUENTAS CORRIENTES'
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all
---AHORRO A LA VISTA
select t.fecha,t.concepto,'Sector Privado'tipo,t.plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t where t.cod_moneda='GS'
and t.cod_sec_contable in ('N','F')
and t.concepto = 'AHORRO A LA VISTA'
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all
---CERTIFICADOS DE DEPOSITO
select t.fecha,t.concepto, 'Sector Privado'tipo,'90'plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda='GS'
and t.cod_sec_contable in ('N','F')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and (t.plz_hasta = 90 or t.plz_hasta <90)
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,'90'
--order by t.mto_hasta
union all
select t.fecha,t.concepto,'Sector Privado'tipo,t.plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda='GS'
and t.cod_sec_contable in ('N','F')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and t.plz_hasta=180
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all
select t.fecha,t.concepto,'Sector Privado'tipo,t.plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda='GS'
and t.cod_sec_contable in ('N','F')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and t.plz_hasta=360
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all
select t.fecha,t.concepto,'Sector Privado'tipo,'>360'plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda='GS'
and t.cod_sec_contable in ('N','F')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and t.plz_hasta>360
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,'>360'
--order by t.mto_hasta
union all

--SECTOR PRIVADO MONEDA EXTRANJERA
--cuentas corrientes
select t.fecha,t.concepto,'Sector Privado'tipo,t.plz_hasta,t.cod_moneda, t.mto_hasta, sum(t.cantidad)cantidad,sum(nvl(t.monto,0))monto
from sb_estratificaciones_dep t where t.cod_moneda<>'GS'
and t.cod_sec_contable in('N','F')
and t.concepto='CUENTAS CORRIENTES'
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all
---AHORRO A LA VISTA
select t.fecha,t.concepto,'Sector Privado'tipo,t.plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t where t.cod_moneda<>'GS'
and t.cod_sec_contable in ('N','F')
and t.concepto = 'AHORRO A LA VISTA'
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all
---CERTIFICADOS DE DEPOSITO
select t.fecha,t.concepto,'Sector Privado'tipo,'90'plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda<>'GS'
and t.cod_sec_contable in ('N','F')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and (t.plz_hasta = 90 or t.plz_hasta <90)
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,'90'
--order by t.mto_hasta
union all

select t.fecha,t.concepto,'Sector Privado'tipo,t.plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda<>'GS'
and t.cod_sec_contable in ('N','F')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and t.plz_hasta=180
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all

select t.fecha,t.concepto,'Sector Privado'tipo,t.plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda<>'GS'
and t.cod_sec_contable in ('N','F')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and t.plz_hasta=360
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all

select t.fecha,t.concepto,'Sector Privado'tipo,'>360'plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda<>'GS'
and t.cod_sec_contable in ('N','F')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and t.plz_hasta>360
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,'>360'
--order by t.mto_hasta
union all
----Publico
--SECTOR PUBLICO MONEDA LOCAL
--cuentas corrientes
select t.fecha,t.concepto,'Sector Publico'tipo,t.plz_hasta,t.cod_moneda, t.mto_hasta, sum(t.cantidad)cantidad,sum(nvl(t.monto,0))monto
from sb_estratificaciones_dep t where t.cod_moneda='GS'
and t.cod_sec_contable in('P')
and t.concepto='CUENTAS CORRIENTES'
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all
---AHORRO A LA VISTA
select t.fecha,t.concepto,'Sector Publico'tipo,t.plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t where t.cod_moneda='GS'
and t.cod_sec_contable in ('P')
and t.concepto = 'AHORRO A LA VISTA'
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all
---CERTIFICADOS DE DEPOSITO
select t.fecha,t.concepto,'Sector Publico'tipo,'90'plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda='GS'
and t.cod_sec_contable in ('P')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and (t.plz_hasta = 90 or t.plz_hasta <90)
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,'90'
--order by t.mto_hasta
union all

select t.fecha,t.concepto,'Sector Publico'tipo,t.plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda='GS'
and t.cod_sec_contable in ('P')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and t.plz_hasta=180
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all

select t.fecha,t.concepto,'Sector Publico'tipo,t.plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda='GS'
and t.cod_sec_contable in ('P')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and t.plz_hasta=360
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all

select t.fecha,t.concepto,'Sector Publico'tipo,'>360'plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda='GS'
and t.cod_sec_contable in ('P')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and t.plz_hasta>360
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,'>360'
--order by t.mto_hasta
union all

--SECTOR PUBLICO MONEDA EXTRANJERA
--cuentas corrientes
select t.fecha,t.concepto,'Sector Publico'tipo,t.plz_hasta,t.cod_moneda, t.mto_hasta, sum(t.cantidad)cantidad,sum(nvl(t.monto,0))monto
from sb_estratificaciones_dep t where t.cod_moneda<>'GS'
and t.cod_sec_contable in('P')
and t.concepto='CUENTAS CORRIENTES'
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all
---AHORRO A LA VISTA
select t.fecha,t.concepto,'Sector Publico'tipo,t.plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t where t.cod_moneda<>'GS'
and t.cod_sec_contable in ('P')
and t.concepto = 'AHORRO A LA VISTA'
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all
---CERTIFICADOS DE DEPOSITO
select t.fecha,t.concepto,'Sector Publico'tipo,'90'plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda<>'GS'
and t.cod_sec_contable in ('P')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and (t.plz_hasta = 90 or t.plz_hasta <90)
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,'90'
--order by t.mto_hasta
union all

select t.fecha,t.concepto,'Sector Publico'tipo,t.plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda<>'GS'
and t.cod_sec_contable in ('P')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and t.plz_hasta=180
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all

select t.fecha,t.concepto,'Sector Publico'tipo,t.plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda<>'GS'
and t.cod_sec_contable in ('P')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and t.plz_hasta=360
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,t.plz_hasta
--order by t.mto_hasta
union all

select t.fecha,t.concepto,'Sector Publico'tipo,'>360'plz_hasta,t.cod_moneda,t.mto_hasta,sum(t.cantidad)cantidad,sum(t.monto)monto
from sb_estratificaciones_dep t
where t.cod_moneda<>'GS'
and t.cod_sec_contable in ('P')
and t.concepto = 'CERTIFICADOS DE DEPOSITO'
and t.plz_hasta>360
group by t.fecha,t.concepto,t.mto_hasta,t.cod_moneda,'>360')x
order by 5,2
;

