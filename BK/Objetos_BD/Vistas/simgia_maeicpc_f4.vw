create or replace force view it.simgia_maeicpc_f4 as
select
    '0' RIESGO,
    '0' VTO,
    0 DOCNRO,
    0 SUCURSAL,
    0 INTERES,
    '0' FEINI,
    0 INTDEV,
    0 INTNODEV,
    to_char(pag_cal.fu_obt_fec_actual(1), 'yymmdd') FECHCONT,
    '0' periodo,
    0 modalidad,
    0 cod_modulo,
    0  feecha,
    '0' cod_persona,
    0 cod_sec_credito,
    '0' tip_interes,
    '0' tip_renovacion,
    0 transaccion,
    '0' RUBROCR,
    '0' RUBROCR_rub_it,
    '0' INDDOCUM,
    0 transaccion2,
    '0' CTAACTIVO,
    '0' CTAACTIVO_rub_it,
    '0' CTAORDACT,
    0 transaccion3,
    '0' CTAPASIVO,
    '0' CTAPASIVO_rub_it,
    '0' COBADL,
    '0' PROPUESTA,
    '0' ESTADO,
    '0' INDPAGO,
    '50' SERVICIO,
    '0' FILLER,
    0 DEVSUSP,
    '0' nro_cuenta,
    0 cod_modalidad,
    '0' cod_sit_contable, --null cod_sit_contable,
    '0' estado_it,
    '0' estado_det,
    0 sal_interes,
    0 sal_int_documentado,
    0 mto_interes,
    0 dev_acumulado,
    0 nro_cuota,
    '0' cod_moneda,
    '0' rubro_susp
from dual

UNION ALL

select
    gctacli.cod_persona RIESGO,
    to_char(cuo.fec_vencimiento,'yyyymmdd') VTO,
    ROWNUM DOCNRO,
    pcp.cod_oficina SUCURSAL,
    nvl(cuo.sal_interes,0) + nvl(cuo.sal_int_documentado,0) INTERES,
    nvl(to_char(PAI_INT_F4.FU_SIM_OBT_FECHAINI_PR_CUOTA(pcp.nro_cuenta, cuo.nro_cuota), 'yyyymmdd'),'0') FEINI,
    /*
    INTDEV: dev_no_cobrado
    INTNODEV: (sal_interes+sal_int_documentado) ¿ dev_no_cobrado
    Control: INTDEV + INTNODEV = en ITGF ((sal_interes+sal_int_documentado))
    */
    nvl(cuo.dev_no_cobrado,0) + nvl(cuo.dev_suspenso,0) INTDEV,
    (nvl(cuo.sal_interes,0) + nvl(cuo.sal_int_documentado,0)) - (nvl(cuo.dev_no_cobrado,0) + nvl(cuo.dev_suspenso,0)) INTNODEV,


    to_char(pag_cal.fu_obt_fec_actual(1), 'yymmdd') FECHCONT, -- 2010-01-29 a pedido del Sr. Victor Palomar
    '1'  PERIODO,
    pcp.cod_modalidad modalidad,
    pcp.cod_modulo,
    pcp.fec_vencimiento - pcp.fec_inicio feecha,
    gctacli.cod_persona,
    pcp.cod_sec_credito,
    pcp.tip_interes,
    nvl(pcp.tip_renovacion,'0') tip_renovacion,
    PAP_PRE.FU_OBT_TRA_CONCEPTO('CA',pcp.estado,pcp.tipo,pcp.tip_interes,pcp.tip_renovacion) transaccion,

    nvl(PAI_INT.fu_obt_cta_contable(fub_obt_rub_transaccion(pcp.cod_modulo,
                 pcp.cod_modalidad,
                 PAP_PRE.FU_OBT_TRA_CONCEPTO('CA',pcp.estado,pcp.tipo,pcp.tip_interes,pcp.tip_renovacion),
                 pcp.cod_moneda,
                 gctacli.cod_persona,
                 fug_obt_plz_contable(pcp.fec_vencimiento - pcp.fec_inicio),
                 'C',
                 pcp.estado,
                 pcp.tip_renovacion, gecli.cat_riesgo, pcp.tip_interes, pcp.tipo,null,pcp.cod_sec_credito)),0) RUBROCR,

    fub_obt_rub_transaccion(pcp.cod_modulo,
                 pcp.cod_modalidad,
                 PAP_PRE.FU_OBT_TRA_CONCEPTO('CA',pcp.estado,pcp.tipo,pcp.tip_interes,pcp.tip_renovacion),
                 pcp.cod_moneda,
                 gctacli.cod_persona,
                 fug_obt_plz_contable(pcp.fec_vencimiento - pcp.fec_inicio),
                 'C',
                 pcp.estado,
                 pcp.tip_renovacion, gecli.cat_riesgo, pcp.tip_interes, pcp.tipo,null,pcp.cod_sec_credito) RUBROCR_rub_it,

    '1' INDDOCUM,
    PAP_PRE.FU_OBT_TRA_CONCEPTO(case when pcp.tip_interes = 'V' then 'IN' when pcp.tip_interes = 'A' then 'IA' end,pcp.estado,pcp.tipo,pcp.tip_interes,pcp.tip_renovacion) transaccion2,
    nvl(PAI_INT.fu_obt_cta_contable(fub_obt_rub_transaccion(pcp.cod_modulo,
                 pcp.cod_modalidad,
                 PAP_PRE.FU_OBT_TRA_CONCEPTO(case when pcp.tip_interes = 'V' then 'IN' when pcp.tip_interes = 'A' then 'IA' end,pcp.estado,pcp.tipo,pcp.tip_interes,pcp.tip_renovacion),
                 pcp.cod_moneda,
                 gctacli.cod_persona,
                 fug_obt_plz_contable(pcp.fec_vencimiento - pcp.fec_inicio),
                 'C',
                  pcp.estado,
                  pcp.tip_renovacion, gecli.cat_riesgo, pcp.tip_interes, pcp.tipo,null,pcp.cod_sec_credito)),0) CTAACTIVO,

    fub_obt_rub_transaccion(pcp.cod_modulo,
                 pcp.cod_modalidad,
                 PAP_PRE.FU_OBT_TRA_CONCEPTO(case when pcp.tip_interes = 'V' then 'IN' when pcp.tip_interes = 'A' then 'IA' end,pcp.estado,pcp.tipo,pcp.tip_interes,pcp.tip_renovacion),
                 pcp.cod_moneda,
                 gctacli.cod_persona,
                 fug_obt_plz_contable(pcp.fec_vencimiento - pcp.fec_inicio),
                 'C',
                  pcp.estado,
                  pcp.tip_renovacion, gecli.cat_riesgo, pcp.tip_interes, pcp.tipo,null,pcp.cod_sec_credito) CTAACTIVO_rub_it,

    to_char(nvl( cuo.nro_cuota,0)) CTAORDACT,
    903 transaccion3,
    nvl(PAI_INT.fu_obt_cta_contable(fub_obt_rub_transaccion(pcp.cod_modulo,
                 pcp.cod_modalidad,
                903,
                 pcp.cod_moneda,
                 gctacli.cod_persona,
                 fug_obt_plz_contable(pcp.fec_vencimiento - pcp.fec_inicio),
                 'D',
                  pcp.estado,
                  pcp.tip_renovacion, gecli.cat_riesgo, pcp.tip_interes, pcp.tipo,null,pcp.cod_sec_credito)),0) CTAPASIVO,

    fub_obt_rub_transaccion(pcp.cod_modulo,
                 pcp.cod_modalidad,
                 903,
                 pcp.cod_moneda,
                 gctacli.cod_persona,
                 fug_obt_plz_contable(pcp.fec_vencimiento - pcp.fec_inicio),
                 'D',
                 pcp.estado,
                 pcp.tip_renovacion, gecli.cat_riesgo, pcp.tip_interes, pcp.tipo,null,pcp.cod_sec_credito) CTAPASIVO_rub_it,

    '0' COBADL,
     to_char(substr(pcp.nro_cuenta,-6)) PROPUESTA,
    '0' ESTADO,
    ' ' INDPAGO,
    '50' SERVICIO,
    pcp.nro_cuenta FILLER,
    case
    when (cuo.sal_capital > 0 ) then
         0
    else
         nvl(cuo.dev_suspenso,0)
    end DEVSUSP,
    pcp.nro_cuenta,
    pcp.cod_modalidad,
    '0' cod_sit_contable, --null cod_sit_contable,
    pcp.estado estado_it,
    pcp.estado estado_det,
    cuo.sal_interes,
    cuo.sal_int_documentado,
    cuo.mto_interes,
    cuo.dev_acumulado,
    cuo.nro_cuota,
    pcp.cod_moneda,
    nvl(PAI_INT.fu_obt_cta_contable(fub_obt_rub_transaccion(pcp.cod_modulo,
           pcp.cod_modalidad,
           947, --codigo transaccion
           pcp.cod_moneda,
           gctacli.cod_persona,
           fug_obt_plz_contable(pcp.fec_vencimiento - pcp.fec_inicio),
           'C',
           pcp.estado,
           pcp.tip_renovacion, gecli.cat_riesgo, pcp.tip_interes, pcp.tipo,null,pcp.cod_sec_credito)),0) rubro_susp
from pr_cta_prestamos pcp, pr_cuotas cuo, ge_cta_clientes gctacli, pr_solicitudes solic, ge_clientes gecli

where pcp.nro_cuenta = cuo.nro_cuenta
and pcp.nro_cuenta = gctacli.nro_cuenta
and pcp.nro_solicitud=solic.nro_solicitud
and gecli.cod_persona = gctacli.cod_persona
and solic.tip_amortizacion IN ('F','C') --Frances P y Aleman F o C
and gctacli.relacion = 'P'
and cuo.estado not in ('N','I')
and (nvl(cuo.sal_interes,0) + nvl(cuo.sal_int_documentado,0) +
nvl(cuo.dev_no_cobrado,0) + nvl(cuo.dev_suspenso,0) +
(nvl(cuo.sal_interes,0) + nvl(cuo.sal_int_documentado,0)) - (nvl(cuo.dev_no_cobrado,0) + nvl(cuo.dev_suspenso,0))) <> 0

UNION ALL

(
select gctacli.cod_persona RIESGO,
to_char(mddet.fec_vencimiento,'yyyymmdd') VTO,
to_number(to_char((100 + ROWNUM)) || lpad(mddet.nro_cuota,3,'0')) DOCNRO,
mdoc.cod_oficina SUCURSAL,
decode(mdoc.cod_modalidad,104,mddet.sal_interes,mddet.mto_interes) INTERES,
to_char(PAI_INT.FU_SIM_OBT_FECHAINI_DOC_DET(mddet.nro_cuenta, mddet.nro_cuota), 'yyyymmdd') FEINI,
nvl(PAI_INT.FU_SIM_OBT_MTO_MDEV(mddet.nro_cuenta, PAI_INT.FU_SIM_OBT_FECHAINI_DOC_DET(mddet.nro_cuenta, mddet.nro_cuota)),0) INTDEV,
(decode(mdoc.cod_modalidad,104,mddet.sal_interes,mddet.mto_interes) - nvl(PAI_INT.FU_SIM_OBT_MTO_MDEV(mddet.nro_cuenta, PAI_INT.FU_SIM_OBT_FECHAINI_DOC_DET(mddet.nro_cuenta, mddet.nro_cuota)),0)) INTNODEV,
to_char(pag_cal.fu_obt_fec_actual(1), 'yymmdd') FECHCONT, -- 2010-01-29 a pedido del Sr. Victor Palomar
'1'  PERIODO,
mdoc.cod_modalidad modalidad,
mdoc.cod_modulo,
mdoc.fec_vencimiento - mdoc.fec_inicio feecha,
gctacli.cod_persona,
0 cod_sec_credito,
'0' tip_interes,
'0' tip_renovacion,
711 transaccion,
pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           711, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gctacli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)) RUBROCR,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           711, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gctacli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable) RUBROCR_rub_it,
'1' INDDOCUM,
case
    when mdoc.cod_sit_contable=10000001 then 811
    when mdoc.cod_sit_contable<>10000001 then 719
end transaccion2,
pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           case
                                                           when mdoc.cod_sit_contable=10000001 then 811
                                                           when mdoc.cod_sit_contable<>10000001 then 719
                                                           end, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gctacli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)) CTAACTIVO,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           case
                                                           when mdoc.cod_sit_contable=10000001 then 811
                                                           when mdoc.cod_sit_contable<>10000001 then 719
                                                           end, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gctacli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable) CTAACTIVO_rub_it,
'' CTAORDAT,
901 transaccion3,
pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           901, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gctacli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)) CTAPASIVO,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           901, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gctacli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable) CTAPASIVO_rub_it,
'0' COBADL,
substr(gctacli.nro_cuenta, 5, 6) PROPUESTA,
'0' ESTADO,
'' INDPAGO,
'50' SERVICIO,
'ITGF' FILLER,
0 DEVSUSP,
mdoc.nro_cuenta,
mdoc.cod_modalidad,
mdoc.cod_sit_contable,
mdoc.estado estado_it,
mddet.estado estado_det,
mddet.sal_interes,
0 sal_int_documentado,
mddet.mto_interes,
mddet.dev_acumulado,
mddet.nro_cuota,
mdoc.cod_moneda,
'0' rubro_susp
from ge_cta_clientes gctacli, md_doc_detalles mddet, md_cta_documentos mdoc
where gctacli.nro_cuenta = mddet.nro_cuenta
and mddet.nro_cuenta = mdoc.nro_cuenta
and (mdoc.cod_modalidad in (104,124) or (mdoc.val_bas_repo is null and mdoc.fec_ven_repo is not null))
and mddet.estado not in ('N','S')
and mddet.mto_interes > 0

union

select gctacli.cod_persona RIESGO,
to_char(mdoc.fec_vencimiento,'yyyymmdd') VTO,
to_number(to_char((100 + ROWNUM)) || '000') DOCNRO,
mdoc.cod_oficina SUCURSAL,
decode(mdoc.cod_modalidad,104,mdoc.sal_interes,mdoc.mto_interes) INTERES,
to_char(mdoc.fec_inicio, 'yyyymmdd') FEINI,
nvl(PAI_INT.FU_SIM_OBT_MTO_MDEV(mdoc.nro_cuenta, mdoc.fec_inicio),0) INTDEV,
(decode(mdoc.cod_modalidad,104,mdoc.sal_interes,mdoc.mto_interes) - nvl(PAI_INT.FU_SIM_OBT_MTO_MDEV(mdoc.nro_cuenta, mdoc.fec_inicio),0)) INTNODEV, --prueba1
to_char(pag_cal.fu_obt_fec_actual(1), 'yymmdd') FECHCONT, -- 2010-01-29 a pedido del Sr. Victor Palomar
'1'  PERIODO,
mdoc.cod_modalidad modalidad,
mdoc.cod_modulo,
mdoc.fec_vencimiento - mdoc.fec_inicio feecha,
gctacli.cod_persona,
0 cod_sec_credito,
'0' tip_interes,
'0' tip_renovacion,
711 transaccion,
pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           711, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gctacli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)) RUBROCR,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           711, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gctacli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable) RUBROCR_rub_it,
'1' INDDOCUM,
case
    when mdoc.cod_sit_contable=10000001 then 811
    when mdoc.cod_sit_contable<>10000001 then 719
end transaccion2,
pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           case
                                                           when mdoc.cod_sit_contable=10000001 then 811
                                                           when mdoc.cod_sit_contable<>10000001 then 719
                                                           end, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gctacli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable))CTAACTIVO,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           case
                                                           when mdoc.cod_sit_contable=10000001 then 811
                                                           when mdoc.cod_sit_contable<>10000001 then 719
                                                           end, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gctacli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)CTAACTIVO_rub_it,
'' CTAORDAT,
901 transaccion3,
pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           901, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gctacli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)) CTAPASIVO,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           901, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gctacli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable) CTAPASIVO_rub_it,
'0' COBADL,
substr(gctacli.nro_cuenta, 5, 6) PROPUESTA,
'0' ESTADO,
'' INDPAGO,
'50' SERVICIO,
'ITGF' FILLER,
0 DEVSUSP,
mdoc.nro_cuenta,
mdoc.cod_modalidad,
mdoc.cod_sit_contable,
mdoc.estado estado_it,
'0' estado_det,
0 sal_interes,
0 sal_int_documentado,
0 mto_interes,
0 dev_acumulado,
0 nro_cuota,
mdoc.cod_moneda,
'0' rubro_susp
from ge_cta_clientes gctacli, md_cta_documentos mdoc
where gctacli.nro_cuenta = mdoc.nro_cuenta
and (mdoc.cod_modalidad in (104,124) or (mdoc.val_bas_repo is null and mdoc.fec_ven_repo is not null))
and mdoc.estado not in ('N','S')
and mdoc.mto_interes > 0
and mdoc.nro_cuenta not in ( select mddocdet.nro_cuenta
                             from md_doc_detalles mddocdet
                             where  mddocdet.nro_cuenta = mdoc.nro_cuenta)
                             )
;

