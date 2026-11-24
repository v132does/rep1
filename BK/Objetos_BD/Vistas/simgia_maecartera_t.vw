create or replace force view it.simgia_maecartera_t as
select to_char(pag_cal.fu_obt_fec_actual(8), 'DDMMYY') fecha,
      0 SUCURSALFU,
      '0' NURIES,
      0 PROPUESTA,
      '0' CONGRU,
      0 NUDOC,
      0 GUARANIES,
      0 CONTRAVALO,
      0 IADDIVISA,
      '0' VENCIM,
      0 CODTASA,
      0 NROLIBRADO,
      0 CTADOCACT, --Frances P y Aleman F
      '0' rubro_act,
      0 CTADOCPAS, --Frances P y Aleman F
      '0' rubro_pas,
      '0' FILLER,

      0 TIPOD,
      to_char(pag_cal.fu_obt_fec_actual(1), 'DDMMYY') FECHAEMISI,
      0 SUCURSALCU,
      0 GASTOSGC,
      '0' VCTOINT,
      0 IADMONTODC,
      0 IADSALDOCP,
      0 IADMETODO,
      0 IADFEINI,
      0 IADDIAS,
      0 IADINTERES, --mto interes
      0 IADADEV, --mto a devengar
      0 IADNROCUO,
      0 IADCODTASA,
      0 CTANDOCACT,
      0 CTANDOCORD,
      0 CTANDOCORH,
      '0' rubro,
      0 transaccion,
      0 transaccion2,
      0 transaccion3,
      0 modalidad,
      '0' tip_amortizacion,
      '0' cod_moneda,
      '0' cat_riesgo,
      '0' nro_cuenta,
      0 cod_ori_fondo,
      '0' tipo
from dual

UNION ALL

select to_char(pag_cal.fu_obt_fec_actual(8), 'DDMMYY') fecha,
      sucursal SUCURSALFU,
      cliente NURIES,
      nvl(to_number(substr(nro_cuenta,-6)),0) PROPUESTA,
      nvl(c.cod_rub_externo,0) CONGRU, --nvl(c.cod_rub_externo,0) CONGRU,
      rownum NUDOC,
      importe_ml GUARANIES,
      --0 intereses,
      importe_me CONTRAVALO,
      decode(b.cod_moneda, 'GS', 0, 'XXX', 1, 'XXX', 2, 'XXX', 3, 'XXX', 4, 'USD', 5, 'XXX', 6, 'CHF', 7, 'XXX', 8, 'XXX', 9, 'GBP', 10,
                                 'XXX', 11, 'XXX', 12, 'XXX', 13, 'JPY', 14, 'ARS', 15, 'XXX', 16, 'EUR', 17, 'UYU', 20, 'CAD', 28) IADDIVISA,
      to_char(fec_vencimiento, 'YYYYMMDD') VENCIM,
      nvl(val_tasa,0) CODTASA,
      0 NROLIBRADO,
      decode(tip_amortizacion, 'F', 0, decode(b.tipo,'afd2',0, nvl(PAI_INT.fu_obt_cta_contable(rubro_act),0))) CTADOCACT, --Frances P y Aleman F
      rubro_act,
      decode(tip_amortizacion, 'F', 0, decode(b.tipo,'afd2',0, nvl(PAI_INT.fu_obt_cta_contable(rubro_pas),0))) CTADOCPAS, --Frances P y Aleman F
      rubro_pas,
      nro_cuenta FILLER,
      --nuevos campos en la vista 20100617 na
      0 TIPOD,
      to_char(b.fec_inicio, 'DDMMYY') FECHAEMISI,
      0 SUCURSALCU,
      nvl(gastos,0) GASTOSGC,
      decode(b.tipo, 'ope_vencidas', '0', to_char(fec_vencimiento, 'YYMMDD')) VCTOINT,
      0 IADMONTODC,
      0 IADSALDOCP,
      0 IADMETODO,
      0 IADFEINI,
      0 IADDIAS,
      nvl(mto_interes,0) IADINTERES, --mto interes
      nvl(mto_adev,0) IADADEV, --mto a devengar
      0 IADNROCUO,
      0 IADCODTASA,
      nvl(dev_suspenso,0) CTANDOCACT,
      to_number( nvl(tip_interes,0) || nvl(destino,0)) CTANDOCORD,
      nvl(nro_cuota,0) CTANDOCORH,
      rubro,
      transaccion,
      transaccion2,
      transaccion3,
      b.cod_modalidad modalidad,
      b.tip_amortizacion,
      b.cod_moneda,
      cat_riesgo,
      b.nro_cuenta,
      b.cod_ori_fondo,
      b.tipo
from cb_rubros c,
      (
-----------------


      ----tarjetas monto utilizado
      select ta.nro_cuenta,
             ta.cod_modalidad,
             ta.cod_oficina sucursal,
             '0' tip_amortizacion,
             gecli.cod_persona as cliente,
             fub_obt_rub_transaccion(ta.cod_modulo,
                               ta.cod_modalidad,
                               decode(ta.cat_automatica,'1',decode(ta.cod_modalidad,55,1507,1506),'2',920,'3',926,'4',929,929), --codigo transaccion
                               ta.cod_moneda,
                               gccli.cod_persona,
                               1,
                               'D',
                               ta.estado,
                               null /*pcp.tip_renovacion*/, gecli.cat_riesgo, null/*pcp.tip_interes*/, gecli.tipo,null,null/*pcp.cod_sec_credito*/) rubro,
             --nvl(ta.sal_facturar,0)+nvl(ta.sal_facturado,0)+nvl(ta.sal_financiado,0)+nvl(ta.sal_cuo_pendientes,0) importe_ml, --en moneda local
             nvl(ta.sal_procesadora,0) importe_ml,
             0 importe_me,
             ta.cod_moneda,
             ta.fec_vct_ult_cierre fec_vencimiento,
             decode(ta.cat_automatica,'1',1506,'2',920,'3',926,'4',929,929) transaccion,---codigo transaccion
             '0' rubro_act,
             0 transaccion2,
             '0' rubro_pas,
             0 transaccion3,
             ta.usu_insercion,
             0 nro_solicitud,
             ta.fec_apertura as fec_inicio,--fecha inicio
             0 nro_cuota,
             0 gastos,
             0 mto_interes,
             0 mto_adev,
             gecli.cat_riesgo,
             'tarj_utilizado' tipo,
             0 dev_suspenso,
             0 cod_ori_fondo,
             0 val_tasa,
             0 destino,
             0 tip_interes,
             to_number(substr(ta.nro_cuenta,3,1)||substr(ta.nro_cuenta,5,5)) nro_tarjeta_as

      from ta_cta_tarjetas ta, ge_cta_clientes gccli, ge_clientes gecli
        where ta.nro_cuenta = gccli.nro_cuenta--vencidas con cta cliente
        and gecli.cod_persona=gccli.cod_persona--clientes con cta cliente
        and gccli.relacion = 'P'
        and ta.estado <> 'C'
        --and ta.cod_modalidad <> 55

union all

      ----tarjetas monto no utilizado
      select ta.nro_cuenta,
             ta.cod_modalidad,
             ta.cod_oficina sucursal,
             '0' tip_amortizacion,
             gecli.cod_persona as cliente,
             '410106170200199' rubro,
             --(nvl(ta.lin_credito,0)+nvl(ta.lin_cuotas,0))-(nvl(ta.sal_facturar,0)+nvl(ta.sal_facturado,0)+nvl(ta.sal_financiado,0)+nvl(ta.sal_cuo_pendientes,0)) importe_ml, --en moneda local
             (nvl(ta.lin_credito,0)+nvl(ta.lin_cuotas,0))-nvl(ta.sal_procesadora,0) importe_ml,
             0 importe_me,
             ta.cod_moneda,
             ta.fec_vct_ult_cierre fec_vencimiento,
             0 transaccion,---codigo transaccion
             '0' rubro_act,
             0 transaccion2,
             '0' rubro_pas,
             0 transaccion3,
             ta.usu_insercion,
             0 nro_solicitud,
             ta.fec_apertura as fec_inicio,--fecha inicio
             0 nro_cuota,
             0 gastos,
             0 mto_interes,
             0 mto_adev,
             gecli.cat_riesgo,
             'tarj_noutilizado' tipo,
             0 dev_suspenso,
             0 cod_ori_fondo,
             0 val_tasa,
             0 destino,
             0 tip_interes,
             to_number(substr(ta.nro_cuenta,3,1)||substr(ta.nro_cuenta,5,5)) nro_tarjeta_as
      from ta_cta_tarjetas ta, ge_cta_clientes gccli, ge_clientes gecli
        where ta.nro_cuenta = gccli.nro_cuenta--vencidas con cta cliente
        and gecli.cod_persona=gccli.cod_persona--clientes con cta cliente
        and gccli.relacion = 'P'
        and ta.estado <> 'C'
        --and ta.cod_modalidad <> 55


  ) b
where c.cod_rubro(+) = b.rubro
;

