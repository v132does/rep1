create or replace force view it.bv_cuo_prest_recibidos as
select
fub_obt_rubro_cuota(md.nro_cuenta,'C') as cod_rubro,
r.cod_rub_externo,
r.descripcion,
r.cod_moneda,
m.cod_modalidad,
m.cod_oficina,
cl.cod_persona,
fue_obt_nom_persona(cl.cod_persona) as nombre,
md.nro_cuenta,
md.sal_capital,
round(md.sal_capital * fug_obt_cotizacion(m.cod_moneda),0) sal_mon_local,
m.val_tasa,
md.nro_cuota,
fum_obt_fec_ini_cuota(md.nro_cuenta, md.nro_cuota) fec_inicio,
md.fec_vencimiento,

md.sal_interes,
fub_obt_rubro_cuota(md.nro_cuenta,'I') as cod_rubro_int

from md_doc_detalles md
left outer join cb_rubros r on (r.cod_rubro=fub_obt_rubro_cuota(md.nro_cuenta,'C'))
left outer join md_cta_documentos m on (m.nro_cuenta=md.nro_cuenta)
left outer join ge_cta_clientes cl on (cl.nro_cuenta=md.nro_cuenta)

where m.cod_modalidad in (109,110,112,115,117,118)
and md.estado<>'N'
order by md.nro_cuenta,md.nro_cuota;

