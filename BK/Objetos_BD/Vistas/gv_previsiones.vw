CREATE OR REPLACE FORCE VIEW IT.GV_PREVISIONES AS
SELECT c.cod_modulo, c.cod_modalidad, c.cod_oficina, c.nro_cuenta,ge.cod_sec_contable, ge.cod_tip_deudor, ge.residente,
          fup_obt_categoria(ge.cat_automatica,ge.cat_subjetiva) cat_riesgo,v.fecha,
          c.cod_moneda, nvl(c.sal_tot_batch,0)-nvl(c.sal_ret_batch,0)-nvl(c.sal_blo_batch,0) saldo, v.linea,
          r.can_dias dias_mora, nvl(r.sit_deuda,c.est_batch) estado, nvl(v.monto,0) mto_prevision,
          nvl(v.tot_pri_prevision,0) tot_pri_prevision
      from cc_previsiones v, cc_cta_corrientes c, ge_clientes ge, ge_cta_clientes gc, cc_sobregiros_res r
      where c.nro_cuenta= v.nro_cuenta
      and ge.cod_persona = gc.cod_persona
      and gc.nro_cuenta = c.nro_cuenta
      and gc.relacion = 'P'
      and v.fecha = (select max(b.fecha) from cc_previsiones  b where c.nro_cuenta = b.nro_cuenta)
      and r.nro_cuenta(+)=c.nro_cuenta
union all
SELECT c.cod_modulo, c.cod_modalidad, c.cod_oficina, c.nro_cuenta,ge.cod_sec_contable, ge.cod_tip_deudor, ge.residente,
          fup_obt_categoria(ge.cat_automatica,ge.cat_subjetiva) cat_riesgo,v.fecha,
          c.cod_moneda,
          NVL(c.SAL_FACTURAR,0)+NVL(c.SAL_FACTURADO,0)+NVL(c.SAL_FINANCIADO,0)+NVL(c.SAL_CUO_PENDIENTES,0) SALDO,
          NVL(c.LIN_CREDITO,0)+NVL(c.LIN_CUOTAS,0) LINEA_DE_CREDITO,
          c.dia_mora, decode(c.cat_automatica,'1','C',
                          '2','V','3','G','4','M','M') estado, nvl(v.monto,0) mto_prevision,
          nvl(v.tot_pri_prevision,0) tot_pri_prevision
      from ta_previsiones v, ta_cta_tarjetas c, ge_clientes ge, ge_cta_clientes gc
      where c.nro_cuenta= v.nro_cuenta
      and ge.cod_persona = gc.cod_persona
      and gc.nro_cuenta = c.nro_cuenta
      and gc.relacion = 'P'
      and v.fecha = (select max(b.fecha) from ta_previsiones  b where c.nro_cuenta = b.nro_cuenta)
union all
SELECT c.cod_modulo, c.cod_modalidad, c.cod_oficina, c.nro_cuenta,ge.cod_sec_contable, ge.cod_tip_deudor, ge.residente,
          fup_obt_categoria(ge.cat_automatica,ge.cat_subjetiva) cat_riesgo,v.fecha,
          c.cod_moneda, nvl(v.sal_capital,0)+nvl(v.dev_no_cobrado,0) SALDO, 0 LINEA_DE_CREDITO,
          c.dia_atraso, c.est_batch, nvl(v.monto,0) mto_prevision,
          nvl(v.tot_pri_prevision,0) tot_pri_prevision
      from pr_previsiones v, pr_cta_prestamos c, ge_clientes ge, ge_cta_clientes gc
      where c.nro_cuenta= v.nro_cuenta
      and ge.cod_persona = gc.cod_persona
      and gc.nro_cuenta = c.nro_cuenta
      and gc.relacion = 'P'
      and v.fecha = (select max(b.fecha) from pr_previsiones  b where c.nro_cuenta = b.nro_cuenta)
union all
SELECT c.cod_modulo, c.cod_modalidad, c.cod_oficina, c.nro_cuenta,ge.cod_sec_contable, ge.cod_tip_deudor, ge.residente,
          fup_obt_categoria(ge.cat_automatica,ge.cat_subjetiva) cat_riesgo,v.fecha,
          c.cod_moneda, nvl(v.saldo,0) SALDO, 0 LINEA_DE_CREDITO,
          c.dia_atraso, c.est_batch, nvl(v.monto,0) mto_prevision,
          nvl(v.tot_pri_prevision,0) tot_pri_prevision
      from ov_previsiones v, ov_cta_vencidas c, ge_clientes ge, ge_cta_clientes gc
      where c.nro_cuenta= v.nro_cuenta
      and ge.cod_persona = gc.cod_persona
      and gc.nro_cuenta = c.nro_cuenta
      and gc.relacion = 'P'
      and v.fecha = (select max(b.fecha) from ov_previsiones  b where c.nro_cuenta = b.nro_cuenta);

