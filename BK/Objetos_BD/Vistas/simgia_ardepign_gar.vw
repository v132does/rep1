create or replace force view it.simgia_ardepign_gar as
select arp."APRIESGO",arp."APSUCUR",arp."APCUENTA",arp."APSUBCTA",rownum APIDENT,arp."APBENEF",arp."APSERVI",arp."APFCHCON",arp."APMONTO",arp."APVENCIM",arp."APFCHULC",arp."APMAYOR",arp."RUB_TRANSACCION0",arp."APREFER",arp."APFCHREG",arp."APESTADO",arp."APCONCTA",arp."RUB_TRANSACCION",arp."APOFIREG",arp."APOPRREG",arp."APSERCDA",arp."TIPO"
from
(select
to_number(nvl(gcc.cod_persona,0)) APRIESGO,
to_number(nvl(substr(gc.nro_cuenta,1,2),0)) APSUCUR,
to_number(nvl(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(gc.nro_cuenta,3,2),gc.cod_moneda),0)) APCUENTA,
to_number(nvl(ah.nro_certificado,0)) APSUBCTA,
0 APBENEF,
0 APSERVI,
to_number(nvl(to_char(pg.fec_inicio,'yyyymmdd'),0)) APFCHCON,
nvl(pgc.monto,0) APMONTO,
to_number(nvl(to_char(pg.fec_vencimiento,'yyyymmdd'),0)) APVENCIM,
0 APFCHULC,
to_number(nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(ah.cod_modulo,
                                                           ah.cod_modalidad,
                                                           603,
                                                           ah.cod_moneda,
                                                           gcc.cod_persona,
                                                           fug_obt_plz_contable(ah.fec_vencimiento - ah.fec_apertura),
                                                           'C',
                                                            ah.estado)),0)) APMAYOR,
fub_obt_rub_transaccion(ah.cod_modulo,
                                                           ah.cod_modalidad,
                                                           603,
                                                           ah.cod_moneda,
                                                           gcc.cod_persona,
                                                           fug_obt_plz_contable(ah.fec_vencimiento - ah.fec_apertura),
                                                           'C',
                                                            ah.estado) rub_transaccion0,
nvl(PAI_INT.FU_SIM_NORM_CADENA(pg.observacion,30),'') APREFER,
to_number(nvl(to_char(pg.fec_insercion,'yymmdd'),0)) APFCHREG,
' ' APESTADO,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(ah.cod_modulo,
                                                           ah.cod_modalidad,
                                                           603,
                                                           ah.cod_moneda,
                                                           gcc.cod_persona,
                                                           fug_obt_plz_contable(ah.fec_vencimiento - ah.fec_apertura),
                                                           'D',
                                                            ah.estado)),0) APCONCTA,
                                                          fub_obt_rub_transaccion(ah.cod_modulo,
                                                           ah.cod_modalidad,
                                                           603,
                                                           ah.cod_moneda,
                                                           gcc.cod_persona,
                                                           fug_obt_plz_contable(ah.fec_vencimiento - ah.fec_apertura),
                                                           'D',
                                                            ah.estado) rub_transaccion,
to_number(nvl(ah.cod_oficina,0)) APOFIREG,
nvl(pg.usu_insercion, ' ') APOPRREG,
nvl(ah.serie, '') APSERCDA,
'cda' tipo




from pr_garantias pg, pr_gar_cash pgc, ge_cuentas gc, /*ge_bloqueos gb,*/ ge_cta_clientes gcc, ah_cta_certificados ah
where pg.nro_garantia = pgc.nro_garantia
and pgc.nro_cta_referencia = gc.nro_cuenta
--and gb.nro_cuenta = gc.nro_cuenta
and gcc.nro_cuenta = gc.nro_cuenta
and gcc.relacion = 'P'
and gc.nro_cuenta = ah.nro_cuenta
and pg.estado = 'C'

union all

select
to_number(nvl(gcc.cod_persona,0)) APRIESGO,
to_number(nvl(substr(gc.nro_cuenta,1,2),0)) APSUCUR,
to_number(nvl(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(gc.nro_cuenta,3,2),gc.cod_moneda),0)) APCUENTA,
to_number(nvl(substr(ahcv.nro_cuenta,5,6),0)) APSUBCTA,
0 APBENEF,
0 APSERVI,
to_number(nvl(to_char(pg.fec_inicio,'yyyymmdd'),0)) APFCHCON,
nvl(pgc.monto,0) APMONTO,
to_number(nvl(to_char(pg.fec_vencimiento,'yyyymmdd'),0)) APVENCIM,
0 APFCHULC,
to_number(nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(ahcv.cod_modulo,
                                                           ahcv.cod_modalidad,
                                                           2604,
                                                           ahcv.cod_moneda,
                                                           gcc.cod_persona,
                                                           fug_obt_plz_contable(ahcv.fec_ult_movimiento - ahcv.fec_apertura),
                                                           'C',
                                                            ahcv.estado)),0)) APMAYOR,
fub_obt_rub_transaccion(ahcv.cod_modulo,
                                                           ahcv.cod_modalidad,
                                                           2604,
                                                           ahcv.cod_moneda,
                                                           gcc.cod_persona,
                                                           fug_obt_plz_contable(ahcv.fec_ult_movimiento - ahcv.fec_apertura),
                                                           'C',
                                                            ahcv.estado) rub_transaccion0,
nvl(PAI_INT.FU_SIM_NORM_CADENA(pg.observacion,30),'') APREFER,
to_number(nvl(to_char(pg.fec_insercion,'yymmdd'),0)) APFCHREG,
' ' APESTADO,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(ahcv.cod_modulo,
                                                           ahcv.cod_modalidad,
                                                           2604,
                                                           ahcv.cod_moneda,
                                                           gcc.cod_persona,
                                                           fug_obt_plz_contable(ahcv.fec_ult_movimiento - ahcv.fec_apertura),
                                                           'D',
                                                            ahcv.estado)),0)APCONCTA,
fub_obt_rub_transaccion(ahcv.cod_modulo,
                                                           ahcv.cod_modalidad,
                                                           2604,
                                                           ahcv.cod_moneda,
                                                           gcc.cod_persona,
                                                           fug_obt_plz_contable(ahcv.fec_ult_movimiento - ahcv.fec_apertura),
                                                           'D',
                                                            ahcv.estado) rub_transaccion,
to_number(nvl(ahcv.cod_oficina,0)) APOFIREG,
nvl(pg.usu_insercion, ' ') APOPRREG,
' ' APSERCDA,
'caja de ahorro' tipo



from pr_garantias pg, pr_gar_cash pgc, ge_cuentas gc,/* ge_bloqueos gb,*/ ge_cta_clientes gcc, ah_cta_vistas ahcv
where pg.nro_garantia = pgc.nro_garantia
and pgc.nro_cta_referencia = gc.nro_cuenta
--and gb.nro_cuenta = gc.nro_cuenta
and gcc.nro_cuenta = gc.nro_cuenta
and gcc.relacion = 'P'
and gc.nro_cuenta = ahcv.nro_cuenta
and pg.estado = 'C'

union all

select
to_number(nvl(gcc.cod_persona,0)) APRIESGO,
to_number(nvl(substr(gc.nro_cuenta,1,2),0)) APSUCUR,
to_number(nvl(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(gc.nro_cuenta,3,2),gc.cod_moneda),0)) APCUENTA,
to_number(nvl(substr(ccc.nro_cuenta,5,6),0)) APSUBCTA,
0 APBENEF,
0 APSERVI,
to_number(nvl(to_char(pg.fec_inicio,'yyyymmdd'),0)) APFCHCON,
nvl(pgc.monto,0) APMONTO,
to_number(nvl(to_char(pg.fec_vencimiento,'yyyymmdd'),0)) APVENCIM,
0 APFCHULC,
to_number(nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(ccc.cod_modulo,
                                                           ccc.cod_modalidad,
                                                           2604,
                                                           ccc.cod_moneda,
                                                           gcc.cod_persona,
                                                           fug_obt_plz_contable(ccc.fec_ult_movimiento - ccc.fec_apertura),
                                                           'C',
                                                            ccc.estado)),0)) APMAYOR,
fub_obt_rub_transaccion(ccc.cod_modulo,
                                                           ccc.cod_modalidad,
                                                           2604,
                                                           ccc.cod_moneda,
                                                           gcc.cod_persona,
                                                           fug_obt_plz_contable(ccc.fec_ult_movimiento - ccc.fec_apertura),
                                                           'C',
                                                            ccc.estado)rub_transaccion0,
nvl(PAI_INT.FU_SIM_NORM_CADENA(pg.observacion,30),'') APREFER,
to_number(nvl(to_char(pg.fec_insercion,'yymmdd'),0)) APFCHREG,
' ' APESTADO,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(ccc.cod_modulo,
                                                           ccc.cod_modalidad,
                                                           2604,
                                                           ccc.cod_moneda,
                                                           gcc.cod_persona,
                                                           fug_obt_plz_contable(ccc.fec_ult_movimiento - ccc.fec_apertura),
                                                           'D',
                                                            ccc.estado)),0) APCONCTA,
                                                          fub_obt_rub_transaccion(ccc.cod_modulo,
                                                           ccc.cod_modalidad,
                                                           2604,
                                                           ccc.cod_moneda,
                                                           gcc.cod_persona,
                                                           fug_obt_plz_contable(ccc.fec_ult_movimiento - ccc.fec_apertura),
                                                           'D',
                                                            ccc.estado)       rub_transaccion,
to_number(nvl(ccc.cod_oficina,0)) APOFIREG,
nvl(pg.usu_insercion, ' ') APOPRREG,
'' APSERCDA,
'cuenta corriente' tipo




from pr_garantias pg, pr_gar_cash pgc, ge_cuentas gc, /*ge_bloqueos gb,*/ ge_cta_clientes gcc, cc_cta_corrientes ccc
where pg.nro_garantia = pgc.nro_garantia
and pgc.nro_cta_referencia = gc.nro_cuenta
--and gb.nro_cuenta = gc.nro_cuenta
and gcc.nro_cuenta = gc.nro_cuenta
and gcc.relacion = 'P'
and gc.nro_cuenta = ccc.nro_cuenta
and pg.estado = 'C'
)arp
;

