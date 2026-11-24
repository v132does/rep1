create or replace force view it.simgia_maeicpc as
select gctacli.cod_persona RIESGO,
to_char(mddet.fec_vencimiento,'yyyymmdd') VTO,
mddet.nro_cuota DOCNRO,
mdoc.cod_oficina SUCURSAL,
--mddet.mto_interes INTERES, --orig
decode(mdoc.cod_modalidad,104,mddet.sal_interes,mddet.mto_interes) INTERES, --prueba1
--mddet.sal_interes INTERES, --prueba2
to_char(PAI_INT.FU_SIM_OBT_FECHAINI_DOC_DET(mddet.nro_cuenta, mddet.nro_cuota), 'yyyymmdd') FEINI,
nvl(PAI_INT.FU_SIM_OBT_MTO_MDEV(mddet.nro_cuenta, PAI_INT.FU_SIM_OBT_FECHAINI_DOC_DET(mddet.nro_cuenta, mddet.nro_cuota)),0) INTDEV,
--(mddet.mto_interes - nvl(PAI_INT.FU_SIM_OBT_MTO_MDEV(mddet.nro_cuenta, PAI_INT.FU_SIM_OBT_FECHAINI_DOC_DET(mddet.nro_cuenta, mddet.nro_cuota)),0)) INTNODEV, --orig
(decode(mdoc.cod_modalidad,104,mddet.sal_interes,mddet.mto_interes) - nvl(PAI_INT.FU_SIM_OBT_MTO_MDEV(mddet.nro_cuenta, PAI_INT.FU_SIM_OBT_FECHAINI_DOC_DET(mddet.nro_cuenta, mddet.nro_cuota)),0)) INTNODEV, --prueba1
--(mddet.sal_interes - nvl(PAI_INT.FU_SIM_OBT_MTO_MDEV(mddet.nro_cuenta, PAI_INT.FU_SIM_OBT_FECHAINI_DOC_DET(mddet.nro_cuenta, mddet.nro_cuota)),0)) INTNODEV, --prueba2
--to_char(mddet.fec_insercion, 'yymmdd') FECHCONT,
to_char(pag_cal.fu_obt_fec_actual(1), 'yymmdd') FECHCONT, -- 2010-01-29 a pedido del Sr. Victor Palomar
'1'  PERIODO,
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
                                                            mdoc.cod_sit_contable) RUBROCR_rub_transaccion,
'1' INDDOCUM,
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
                                                            mdoc.cod_sit_contable) CTAACTIVO_rub_transaccion,
'' CTAORDAT,
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
                                                            mdoc.cod_sit_contable) CTAPASIVO_rub_transaccion,
'0' COBADL,
substr(gctacli.nro_cuenta, 5, 6) PROPUESTA,
'0' ESTADO,
'' INDPAGO,
'50' SERVICIO,
'ITGF' FILLER,
mdoc.nro_cuenta, mdoc.cod_modalidad, mdoc.cod_sit_contable, mdoc.estado estado_it, mddet.estado estado_det

from ge_cta_clientes gctacli, md_doc_detalles mddet, md_cta_documentos mdoc
where gctacli.nro_cuenta = mddet.nro_cuenta
and mddet.nro_cuenta = mdoc.nro_cuenta
and (mdoc.cod_modalidad in (104,124) or (mdoc.val_bas_repo is null and mdoc.fec_ven_repo is not null))
and mddet.estado not in ('N','S')
and mddet.mto_interes > 0

union

select gctacli.cod_persona RIESGO,
to_char(mdoc.fec_vencimiento,'yyyymmdd') VTO,
1 DOCNRO,
mdoc.cod_oficina SUCURSAL,
--mdoc.mto_interes INTERES, --orig
decode(mdoc.cod_modalidad,104,mdoc.sal_interes,mdoc.mto_interes) INTERES, --prueba1
--mdoc.sal_interes INTERES, --prueba2
to_char(mdoc.fec_inicio, 'yyyymmdd') FEINI,
nvl(PAI_INT.FU_SIM_OBT_MTO_MDEV(mdoc.nro_cuenta, mdoc.fec_inicio),0) INTDEV,
--(mdoc.mto_interes - nvl(PAI_INT.FU_SIM_OBT_MTO_MDEV(mdoc.nro_cuenta, mdoc.fec_inicio),0)) INTNODEV, --orig
(decode(mdoc.cod_modalidad,104,mdoc.sal_interes,mdoc.mto_interes) - nvl(PAI_INT.FU_SIM_OBT_MTO_MDEV(mdoc.nro_cuenta, mdoc.fec_inicio),0)) INTNODEV, --prueba1
--(mdoc.sal_interes - nvl(PAI_INT.FU_SIM_OBT_MTO_MDEV(mdoc.nro_cuenta, mdoc.fec_inicio),0)) INTNODEV,--prueba2
--to_char(mdoc.fec_insercion, 'yymmdd') FECHCONT,
to_char(pag_cal.fu_obt_fec_actual(1), 'yymmdd') FECHCONT, -- 2010-01-29 a pedido del Sr. Victor Palomar
'1'  PERIODO,
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
                                                            mdoc.cod_sit_contable) RUBROCR_rub_transaccion,
'1' INDDOCUM,
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
                                                            mdoc.cod_sit_contable)CTAACTIVO_rub_transaccion,
'' CTAORDAT,
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
                                                            mdoc.cod_sit_contable) CTAPASIVO_rub_transaccion,
'0' COBADL,
substr(gctacli.nro_cuenta, 5, 6) PROPUESTA,
'0' ESTADO,
'' INDPAGO,
'50' SERVICIO,
'ITGF' FILLER,
mdoc.nro_cuenta, mdoc.cod_modalidad, mdoc.cod_sit_contable, mdoc.estado estado_it, '' estado_det
from ge_cta_clientes gctacli, md_cta_documentos mdoc
where gctacli.nro_cuenta = mdoc.nro_cuenta
and (mdoc.cod_modalidad in (104,124) or (mdoc.val_bas_repo is null and mdoc.fec_ven_repo is not null))
and mdoc.estado not in ('N','S')
and mdoc.mto_interes > 0
and mdoc.nro_cuenta not in ( select mddocdet.nro_cuenta
                             from md_doc_detalles mddocdet
                             where  mddocdet.nro_cuenta = mdoc.nro_cuenta)
;

