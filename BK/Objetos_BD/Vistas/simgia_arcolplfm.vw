create or replace force view it.simgia_arcolplfm as
select nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           711, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)),0) RMCUENTA,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           711, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable) rb_1,
rownum RMREFER,
nvl(mdoc.monto,0) RMONTO,
nvl(to_char(mdoc.fec_inicio,'yymmdd'),0) RMFCHCON,
nvl(to_char(mdoc.fec_vencimiento,'yymmdd'),0) RMFCHVTO,
nvl(mdet.plazo,0) RMPLAZO,
nvl(mdoc.val_tasa,0) RMTASA,
nvl(mdoc.mto_interes,0) RMINTERES,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           919, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable)),0) RMCINTDEV,
fub_obt_rub_transaccion(mdoc.cod_modulo,
                                                           mdoc.cod_modalidad,
                                                           919, /*codigo transaccion*/
                                                           mdoc.cod_moneda,
                                                           mdoc.cod_persona,
                                                           fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',/*(tipo movimiento)*/
                                                            mdoc.estado, null, null, null, null,
                                                            mdoc.cod_sit_contable) rb_2,
nvl(mdoc.dev_acumulado,0) RMINTDEV,
0 RMCALTA,
0 RMCBAJA,
nvl(to_char(mdoc.fec_ult_devengado,'yymmdd'),0) RMFULDEV,
nvl(to_char(mdoc.fec_insercion,'yymmdd'),0) RMFCHREG,
0  RMCODBCO,
nvl(mdoc.usu_insercion,'') RMOPER, mdoc.nro_cuenta, mdoc.cod_modalidad, mdoc.cod_sit_contable
from md_cta_documentos mdoc, md_doc_detalles mdet
where  mdoc.cod_modalidad = 144
-- pruebas mdoc.cod_modalidad = 114
-- produccion mdoc.cod_modalidad = 144
and mdoc.nro_cuenta= mdet.nro_cuenta
and mdoc.estado not in ('N')
;

