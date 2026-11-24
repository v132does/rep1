create or replace force view it.bv_cuo_prest_clientes as
select
fub_obt_rubro_cuota(c.nro_cuenta,'C') as cod_rubro,
r.cod_rub_externo,
r.descripcion,
r.cod_moneda,
p.cod_modalidad,
p.cod_oficina,
cl.cod_persona,
fue_obt_nom_persona(cl.cod_persona) as nombre,
c.nro_cuenta,
c.sal_capital,
round(c.sal_capital * fug_obt_cotizacion(r.cod_moneda),0) sal_mon_local,
p.val_tasa,
c.nro_cuota,
fup_obt_fec_ini_cuota(c.nro_cuenta, c.nro_cuota) fec_inicio,
c.fec_vencimiento,

c.sal_interes,
fub_obt_rubro_cuota(c.nro_cuenta,'I') as cod_rubro_int

from pr_cuotas c
left outer join cb_rubros r on (r.cod_rubro=fub_obt_rubro_cuota(c.nro_cuenta,'C'))
left outer join pr_cta_prestamos p on (p.nro_cuenta=c.nro_cuenta)
left outer join ge_cta_clientes cl on (cl.nro_cuenta=c.nro_cuenta and cl.relacion='P')
where c.estado<>'N'
order by c.nro_cuenta,c.nro_cuota


/*COD_RUBRO	COD_RUB_EXTERNO	DESCRIPCION	COD_MONEDA	COD_MODALIDAD	COD_OFICINA	TIP_SALDO	COD_PERSONA	NOMBRE
NRO_CUENTA	SAL_ACTUAL	SAL_MON_LOCAL	VAL_TASA	FEC_INICIO	FEC_VENCIMIENTO	SAL_PROMEDIO
*/;

