create or replace force view it.bv_finanzas as
select i.cod_rubro, r.cod_rub_externo, r.descripcion, i.cod_moneda,i.cod_modalidad, i.cod_oficina, i.tip_saldo,
       e.cod_persona, fue_obt_nom_persona(e.cod_persona) nombre, d.nro_cuenta,
       decode(substr(i.cod_rubro,1,1),6,0,7,0,d.sal_actual) sal_actual,
       decode(substr(i.cod_rubro,1,1),6,d.sal_actual,7,d.sal_actual, -- RB 02/07/2012. Para cuentas de resultado no debe multiplicar por la cotización ya esta expresado en guaranies.
       decode(i.cod_moneda,'GS', d.sal_actual, round(d.sal_actual * fug_obt_cotizacion(i.cod_moneda),0))) sal_mon_local,
       p.val_tasa, p.fec_inicio, p.fec_vencimiento, fub_obt_sal_promedio(p.nro_cuenta, p.cod_modulo, pag_cal.FU_OBT_FEC_ACTUAL(1)) sal_promedio
from cb_sal_inventarios i, cb_sal_inventarios_det d, pr_cta_prestamos p, cb_rubros r, ge_cta_clientes e
where i.nro_referencia=d.nro_referencia
and d.nro_cuenta=p.nro_cuenta
and p.nro_cuenta=e.nro_cuenta
and e.relacion='P'
and i.cod_rubro=r.cod_rubro(+)
and d.sal_actual <> 0
/* Ahorros */
union all
select i.cod_rubro, r.cod_rub_externo, r.descripcion, i.cod_moneda,i.cod_modalidad, i.cod_oficina, i.tip_saldo,
       e.cod_persona, fue_obt_nom_persona(e.cod_persona) nombre, d.nro_cuenta,
       decode(substr(i.cod_rubro,1,1),6,0,7,0,d.sal_actual) sal_actual,
       decode(substr(i.cod_rubro,1,1),6,d.sal_actual,7,d.sal_actual, -- RB 02/07/2012. Para cuentas de resultado no debe multiplicar por la cotización ya esta expresado en guaranies.
       decode(i.cod_moneda,'GS', d.sal_actual, round(d.sal_actual * fug_obt_cotizacion(i.cod_moneda),0))) sal_mon_local,
       fug_obt_val_tasa(p.cod_modulo, p.cod_modalidad, p.cod_oficina, p.nro_cuenta, p.cod_moneda, p.sal_total, p.tas_personalizada, p.cod_tasa, null,
       pag_cal.FU_OBT_FEC_ACTUAL(3)),
       p.fec_apertura, null, fub_obt_sal_promedio(p.nro_cuenta, p.cod_modulo, pag_cal.FU_OBT_FEC_ACTUAL(1)) sal_promedio
from cb_sal_inventarios i, cb_sal_inventarios_det d, ah_cta_vistas p, cb_rubros r, ge_cta_clientes e
where i.nro_referencia=d.nro_referencia
and d.nro_cuenta=p.nro_cuenta
and p.nro_cuenta=e.nro_cuenta
and e.relacion='P'
and i.cod_rubro=r.cod_rubro(+)
and d.sal_actual <> 0
/* Ctas.Ctes. */
union all
select i.cod_rubro, r.cod_rub_externo, r.descripcion, i.cod_moneda,i.cod_modalidad, i.cod_oficina, i.tip_saldo,
       e.cod_persona, fue_obt_nom_persona(e.cod_persona) nombre, d.nro_cuenta,
       decode(substr(i.cod_rubro,1,1),6,0,7,0,d.sal_actual) sal_actual,
       decode(substr(i.cod_rubro,1,1),6,d.sal_actual,7,d.sal_actual, -- RB 02/07/2012. Para cuentas de resultado no debe multiplicar por la cotización ya esta expresado en guaranies.
       decode(i.cod_moneda,'GS', d.sal_actual, round(d.sal_actual * fug_obt_cotizacion(i.cod_moneda),0))) sal_mon_local,
       (CASE
         WHEN substr(i.cod_rubro,1,1) = 2 THEN
           0  -- RB 30/08/2012 Para cuentas pasivas la cotizacion debe ser cero.
         ELSE
           fug_obt_val_tasa(p.cod_modulo, p.cod_modalidad, p.cod_oficina, p.nro_cuenta, p.cod_moneda, p.sal_total, p.tas_personalizada, 911, null,pag_cal.FU_OBT_FEC_ACTUAL(3))
       END)as val_tasa,
       p.fec_apertura, null, fub_obt_sal_promedio(p.nro_cuenta, p.cod_modulo, pag_cal.FU_OBT_FEC_ACTUAL(1)) sal_promedio
from cb_sal_inventarios i, cb_sal_inventarios_det d, cc_cta_corrientes p, cb_rubros r, ge_cta_clientes e
where i.nro_referencia=d.nro_referencia
and d.nro_cuenta=p.nro_cuenta
and p.nro_cuenta=e.nro_cuenta
and e.relacion='P'
and i.cod_rubro=r.cod_rubro(+)
and d.sal_actual <> 0
/* CDA */
union all
select i.cod_rubro, r.cod_rub_externo, r.descripcion, i.cod_moneda,i.cod_modalidad, i.cod_oficina, i.tip_saldo,
       e.cod_persona, fue_obt_nom_persona(e.cod_persona) nombre, d.nro_cuenta,
       decode(substr(i.cod_rubro,1,1),6,0,7,0,d.sal_actual) sal_actual,
       decode(substr(i.cod_rubro,1,1),6,d.sal_actual,7,d.sal_actual, -- RB 02/07/2012. Para cuentas de resultado no debe multiplicar por la cotización ya esta expresado en guaranies.
       decode(i.cod_moneda,'GS', d.sal_actual, round(d.sal_actual * fug_obt_cotizacion(i.cod_moneda),0))) sal_mon_local,
       fug_obt_val_tasa(p.cod_modulo, p.cod_modalidad, p.cod_oficina, p.nro_cuenta, p.cod_moneda, p.sal_total, p.tas_personalizada, p.cod_tasa, null,
       pag_cal.FU_OBT_FEC_ACTUAL(3)),
       p.fec_apertura, p.fec_vencimiento, fub_obt_sal_promedio(p.nro_cuenta, p.cod_modulo, pag_cal.FU_OBT_FEC_ACTUAL(1)) sal_promedio
from cb_sal_inventarios i, cb_sal_inventarios_det d, ah_cta_certificados p, cb_rubros r, ge_cta_clientes e
where i.nro_referencia=d.nro_referencia
and d.nro_cuenta=p.nro_cuenta
and p.nro_cuenta=e.nro_cuenta
and e.relacion='P'
and i.cod_rubro=r.cod_rubro(+)
and d.sal_actual <> 0
and p.cod_modalidad <> 36 -- Saco BONOS xq aun no cuadra
/* Mesa de Dinero */
union all
select i.cod_rubro, r.cod_rub_externo, r.descripcion, i.cod_moneda,i.cod_modalidad, i.cod_oficina, i.tip_saldo,
       e.cod_persona, fue_obt_nom_persona(e.cod_persona) nombre, d.nro_cuenta,
       decode(substr(i.cod_rubro,1,1),6,0,7,0,d.sal_actual) sal_actual,
       decode(substr(i.cod_rubro,1,1),6,d.sal_actual,7,d.sal_actual, -- RB 02/07/2012. Para cuentas de resultado no debe multiplicar por la cotización ya esta expresado en guaranies.
       decode(i.cod_moneda,'GS', d.sal_actual, round(d.sal_actual * fug_obt_cotizacion(i.cod_moneda),0))) sal_mon_local,
       p.val_tasa, p.fec_inicio, p.fec_vencimiento, fub_obt_sal_promedio(p.nro_cuenta, p.cod_modulo, pag_cal.FU_OBT_FEC_ACTUAL(1)) sal_promedio
from cb_sal_inventarios i, cb_sal_inventarios_det d, md_cta_documentos p, cb_rubros r, ge_cta_clientes e
where i.nro_referencia=d.nro_referencia
and d.nro_cuenta=p.nro_cuenta
and p.nro_cuenta=e.nro_cuenta
and e.relacion='P'
and i.cod_rubro=r.cod_rubro(+)
and d.sal_actual <> 0
;

