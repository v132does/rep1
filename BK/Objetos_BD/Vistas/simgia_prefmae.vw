create or replace force view it.simgia_prefmae as
select nvl(gcli.cod_persona,0) PREFNUMCLI,
decode(mdoc.cod_modalidad,118,'P',109,'C','') PREFTIPOPR,
nvl(PAI_INT.FU_SIM_NORM_CADENA(mdoc.nro_documento,20),'SEQ'|| rownum) PREFNRO,
'C' PREFTIPOR,
'3' PREFTIPOCL,
decode(mdoc.cod_moneda,'GS','0','USD','5','EUR','17') PREFMONEDA,
nvl(to_char(mdet.fec_vencimiento,'YYYYMMDD'),0) PREFVTO,
nvl(mdet.sal_capital,0) PREFMONTO,
nvl(mdoc.cod_oficina,0) PREFSUC,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           711, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gcli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)),0) PREFCUENTA,
nvl(to_char(PAI_INT.FU_SIM_OBT_FECHAINI(mdet.nro_cuenta,mdet.nro_cuota),'yyyymmdd'),0) PREFFEINI,
/*nvl(mdet.dev_acumulado,0) PREFDEVENG,*/

0 PREFDEVENG,
nvl(to_char(trunc(sysdate),'yyyymmdd'),0) PREFCHCONT,
nvl(mdoc.val_tasa,0) PREFTASA,
--check 1
mdoc.fec_ult_pago doc_ult_pago, mdet.fec_ult_pago det_ult_pago, mdet.mto_capital,
mdoc.estado doc_estado, mdet.estado det_estado,
--check 2
(select min(mdet3.fec_vencimiento)
      from md_cta_documentos mdoc3, md_doc_detalles mdet3
      where mdoc3.cod_modalidad in (109,118)
      and mdet3.nro_cuenta= mdet.nro_cuenta
      and mdet3.mto_capital <> 0
      and mdet3.estado not in ('N','S') ) venc_gral,
mdet.fec_vencimiento venc_registro,
--check 3
(select max(mv3.fec_ult_devengado)
                                     from md_devengados mv3
                                     where mv3.nro_cuenta = mdet.nro_cuenta) fec_ult_dev2

from ge_cta_clientes gcli, md_cta_documentos mdoc, md_doc_detalles mdet
where gcli.relacion = 'P'
and mdoc.nro_cuenta= gcli.nro_cuenta
and mdoc.cod_modalidad in (109,118)
and mdoc.nro_cuenta= mdet.nro_cuenta
and mdet.mto_capital <> 0
and mdet.estado not in ('N','S')

UNION

select nvl(gcli.cod_persona,0) PREFNUMCLI,
decode(mdoc.cod_modalidad,118,'P',109,'C','') PREFTIPOPR,
nvl(PAI_INT.FU_SIM_NORM_CADENA(mdoc.nro_documento,15), 'SEQ'|| rownum) PREFNRO,
'I' PREFTIPOR,
'3' PREFTIPOCL,
decode(mdoc.cod_moneda,'GS','0','USD','5','EUR','17') PREFMONEDA,
nvl(to_char(mdet.fec_vencimiento,'YYYYMMDD'),0) PREFVTO,
nvl(mdet.mto_interes,0) PREFMONTO,
nvl(mdoc.cod_oficina,0) PREFSUC,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           719, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gcli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/* (tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)),0) PREFCUENTA,
nvl(to_char(PAI_INT.FU_SIM_OBT_FECHAINI(mdet.nro_cuenta,mdet.nro_cuota),'yyyymmdd'),0) PREFFEINI,
/*nvl(mdet.dev_acumulado,0) PREFDEVENG,*/
Case
 when (select min(mdet2.fec_vencimiento)
      from md_cta_documentos mdoc2, md_doc_detalles mdet2
      where mdoc2.cod_modalidad in (109,118)
      and mdet2.nro_cuenta = mdet.nro_cuenta
      and mdoc2.nro_cuenta = mdet2.nro_cuenta
      and mdet2.mto_interes <> 0
      and mdet2.estado not in ('N','S')) = mdet.fec_vencimiento then

          nvl((mdoc.sal_interes - mdoc.val_int_devengar),0)

 else
      0
 end PREFDEVENG,
nvl(to_char(trunc(sysdate),'yyyymmdd'),0) PREFCHCONT,
nvl(mdoc.val_tasa,0) PREFTASA,
--check 1
mdoc.fec_ult_pago doc_ult_pago, mdet.fec_ult_pago det_ult_pago, mdet.mto_capital,
mdoc.estado doc_estado, mdet.estado det_estado,
--check 2
(select min(mdet3.fec_vencimiento)
      from md_cta_documentos mdoc3, md_doc_detalles mdet3
      where mdoc3.cod_modalidad in (109,118)
      and mdet3.nro_cuenta= mdet.nro_cuenta
      and mdet3.mto_interes <> 0
      and mdet3.estado not in ('N','S')) venc_gral,
mdet.fec_vencimiento venc_registro,
--check 3
(select max(mv3.fec_ult_devengado)
                                     from md_devengados mv3
                                     where mv3.nro_cuenta = mdet.nro_cuenta) fec_ult_dev2

from ge_cta_clientes gcli, md_cta_documentos mdoc, md_doc_detalles mdet
where gcli.relacion = 'P'
and mdoc.nro_cuenta= gcli.nro_cuenta
and mdoc.cod_modalidad in (109,118)
and mdoc.nro_cuenta= mdet.nro_cuenta
and mdet.mto_interes <> 0
and mdet.estado not in ('N','S')
;

