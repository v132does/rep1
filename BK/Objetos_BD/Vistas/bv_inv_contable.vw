create or replace force view it.bv_inv_contable as
select i.cod_rubro, r.cod_rub_externo, r.descripcion, i.cod_moneda,i.cod_modalidad, i.cod_oficina, i.tip_saldo,
       e.cod_persona, fue_obt_nom_persona(e.cod_persona) nombre, d.nro_cuenta, d.sal_actual,
       decode(i.cod_moneda,pag_gen.FU_OBT_MON_LOCAL, d.sal_actual, round(d.sal_actual * fug_obt_cotizacion(i.cod_moneda),0)) sal_mon_local,
       NULL val_tasa,p.fec_apertura fec_inicio, NULL fec_vencimiento, fub_obt_sal_promedio(p.nro_cuenta, p.cod_modulo, pag_cal.FU_OBT_FEC_ACTUAL(2)) sal_promedio
from cb_sal_inv_contables i, cb_sal_inv_contables_det d, cc_cta_bancarias p, cb_rubros r, ge_cta_clientes e
where i.nro_referencia=d.nro_referencia
and d.nro_cuenta=p.nro_cuenta
and p.nro_cuenta=e.nro_cuenta
and e.relacion='P'
and i.cod_rubro=r.cod_rubro(+);

