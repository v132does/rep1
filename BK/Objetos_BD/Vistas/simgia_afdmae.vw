create or replace force view it.simgia_afdmae as
select nvl( PAI_INT.FU_SIM_NORM_CADENA(mdoc.nro_documento,20), '0')  AFDNRO,
'C' AFDTIPOR,
decode(mdoc.cod_moneda,'GS','0','USD','5','EUR','17') AFDMONEDA,
nvl(to_char(mdoc.fec_vencimiento,'yyyymmdd'),0) AFDVTO,
nvl(mdoc.sal_capital,0) AFDMONTO,
nvl(mdoc.cod_oficina,0) AFDSUC,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           801, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gcli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)),0) AFDCUENTA,
/* para capital va 0*/ '0'  AFDFEINI,
/*nvl(mdet.dev_acumulado,0)*/ 0 AFDDEVENG,
/*null aux1, null aux2, mdoc.nro_cuenta aux3,*/
nvl(to_char(trunc(sysdate),'yyyymmdd'),0) AFDFCHCONT,
nvl(mdoc.val_tasa,0) AFDTASA,
mdoc.estado doc_estado, mdet.estado det_estado
from ge_cta_clientes gcli, md_cta_documentos mdoc, md_doc_detalles mdet
where mdoc.cod_modalidad = 117
and mdoc.nro_cuenta= gcli.nro_cuenta
and mdoc.nro_cuenta= mdet.nro_cuenta
and mdet.mto_capital <> 0
and gcli.relacion = 'P'
and mdet.estado <> 'N'

UNION

select nvl(PAI_INT.FU_SIM_NORM_CADENA(mdoc.nro_documento,20),'0') AFDNRO,
'I' AFDTIPOR,
decode(mdoc.cod_moneda,'GS','0','USD','5','EUR','17') AFDMONEDA,
nvl(to_char(mdet.fec_vencimiento,'yyyymmdd'),0) AFDVTO,
nvl(mdet.mto_interes,0) AFDMONTO,
nvl(mdoc.cod_oficina,0) AFDSUC,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           901, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           gcli.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'C',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)),0) AFDCUENTA,
nvl(to_char(PAI_INT.FU_SIM_OBT_FECHAINI(mdet.nro_cuenta,mdet.nro_cuota),'yyyymmdd'),0)  AFDFEINI,
 Case
 when (select min(mdet2.fec_vencimiento)
      from md_cta_documentos mdoc2, md_doc_detalles mdet2
      where mdoc2.cod_modalidad in (117)
      and mdet2.nro_cuenta = mdet.nro_cuenta
      and mdoc2.nro_cuenta = mdet2.nro_cuenta
      and mdet2.mto_interes <> 0
      and mdet2.estado not in ('N')) = mdet.fec_vencimiento then

          nvl((mdoc.sal_interes - mdoc.val_int_devengar),0)

 else
      0
 end AFDDEVENG,
/* (select min(mdet2.fec_vencimiento)
      from md_cta_documentos mdoc2, md_doc_detalles mdet2
      where mdoc2.cod_modalidad in (117)
      and mdet2.nro_cuenta = mdet.nro_cuenta
      and mdoc2.nro_cuenta = mdet2.nro_cuenta
      and mdet2.mto_interes <> 0
      and mdet2.estado <> 'N') aux1,
      mdet.fec_vencimiento aux2,
      mdoc.nro_cuenta aux3,*/
nvl(to_char(trunc(sysdate),'yyyymmdd'),0) AFDFCHCONT,
nvl(mdoc.val_tasa,0) AFDTASA,
mdoc.estado doc_estado, mdet.estado det_estado
from ge_cta_clientes gcli, md_cta_documentos mdoc, md_doc_detalles mdet
where mdoc.cod_modalidad = 117
and mdoc.nro_cuenta= gcli.nro_cuenta
and mdoc.nro_cuenta= mdet.nro_cuenta
and mdet.mto_interes <> 0
and mdet.estado <> 'N'
and gcli.relacion = 'P';

