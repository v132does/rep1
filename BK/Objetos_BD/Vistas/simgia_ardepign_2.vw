create or replace force view it.simgia_ardepign_2 as
select arp."APRIESGO",arp."APSUCUR",arp."APCUENTA",arp."APSUBCTA",rownum APIDENT,arp."APBENEF",arp."APSERVI",arp."APFCHCON",arp."APMONTO",arp."APVENCIM",arp."APFCHULC",arp."APMAYOR",arp."RUB_TRANSACCION0",arp."APREFER",arp."APFCHREG",arp."APESTADO",arp."APCONCTA",arp."RUB_TRANSACCION",arp."APOFIREG",arp."APOPRREG",arp."APSERCDA",arp."TIPO"
from
(
--cta vista
select distinct

to_number(nvl(gcc.cod_persona,0)) APRIESGO,
to_number(nvl(substr(gcc.nro_cuenta,1,2),0)) APSUCUR,
to_number(nvl(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(ah.nro_cuenta,3,2),ah.cod_moneda),0)) APCUENTA,
to_number(nvl(substr(ah.nro_cuenta,5,6),0)) APSUBCTA,
0 APBENEF,
0 APSERVI,
to_number(nvl(to_char(gb.fec_inicio,'yyyymmdd'),0)) APFCHCON,
nvl(gb.monto,0) APMONTO,
to_number(nvl(to_char(pgc.fec_vencimiento,'yyyymmdd'),0)) APVENCIM,
0 APFCHULC,
to_number(nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(ah.cod_modulo,ah.cod_modalidad,2604,ah.cod_moneda,
                                                           gcc.cod_persona,fug_obt_plz_contable(ah.fec_ult_movimiento - ah.fec_apertura),
                                                           'C',ah.estado)),0)) APMAYOR,
fub_obt_rub_transaccion(ah.cod_modulo,ah.cod_modalidad,2604,ah.cod_moneda,
                        gcc.cod_persona,fug_obt_plz_contable(ah.fec_ult_movimiento - ah.fec_apertura),
                        'C',ah.estado) rub_transaccion0,
nvl(PAI_INT.FU_SIM_NORM_CADENA(gb.observacion,30),'') APREFER,
to_number(nvl(to_char(gb.fec_insercion,'yymmdd'),0)) APFCHREG,
' ' APESTADO,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(ah.cod_modulo,ah.cod_modalidad,2604,ah.cod_moneda,                                                           gcc.cod_persona,
                                                           fug_obt_plz_contable(ah.fec_ult_movimiento - ah.fec_apertura),
                                                           'D', ah.estado)),0) APCONCTA,
fub_obt_rub_transaccion(ah.cod_modulo,ah.cod_modalidad,2604,ah.cod_moneda,gcc.cod_persona,
                        fug_obt_plz_contable(ah.fec_ult_movimiento - ah.fec_apertura),'D',ah.estado) rub_transaccion,
to_number(nvl(ah.cod_oficina,0)) APOFIREG,
nvl(gb.usu_insercion, ' ') APOPRREG,
' ' APSERCDA,
'vista' tipo

from pr_garantias pg, pr_gar_cash pgc, ge_bloqueos gb, ge_cta_clientes gcc, ah_cta_vistas ah
where pg.nro_garantia = pgc.nro_garantia--garantias con cash
and pg.estado in ('C','V',/*'N',*/'T')--garantias
and pgc.nro_cta_referencia = gb.nro_cuenta--cash con bloqueos
and gb.cod_causa = '230'--bloqueos
and pgc.nro_cta_referencia = ah.nro_cuenta---cash con vista
and gcc.nro_cuenta=ah.nro_cuenta--cta cliente con vistas
and gcc.relacion = 'P'--relacion cliente
and pgc.nro_cta_referencia=gcc.nro_cuenta---cash con cta cliente



UNION ALL
---cheques certificados
select distinct

to_number(nvl(gcc.cod_persona,0)) APRIESGO,
to_number(nvl(substr(ahh.nro_cuenta,1,2),0)) APSUCUR,
to_number(nvl(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(ahh.nro_cuenta,3,2),ahh.cod_moneda),0)) APCUENTA,
to_number(nvl(ahh.nro_certificado,0)) APSUBCTA,
0 APBENEF,
0 APSERVI,
to_number(nvl(to_char(gb.fec_inicio,'yyyymmdd'),0)) APFCHCON,
nvl(gb.monto,0) APMONTO,
to_number(nvl(to_char(pg.fec_vencimiento,'yyyymmdd'),0)) APVENCIM,
0 APFCHULC,
to_number(nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(ahh.cod_modulo,ahh.cod_modalidad,603,ahh.cod_moneda,
                                                           gcc.cod_persona,fug_obt_plz_contable(ahh.fec_vencimiento - ahh.fec_apertura),
                                                           'C',ahh.estado)),0)) APMAYOR,
fub_obt_rub_transaccion(ahh.cod_modulo,ahh.cod_modalidad,603,ahh.cod_moneda,
                        gcc.cod_persona,fug_obt_plz_contable(ahh.fec_vencimiento- ahh.fec_apertura),
                        'C',ahh.estado) rub_transaccion0,
nvl(PAI_INT.FU_SIM_NORM_CADENA(gb.observacion,30),'') APREFER,
to_number(nvl(to_char(gb.fec_insercion,'yymmdd'),0)) APFCHREG,
' ' APESTADO,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(ahh.cod_modulo,ahh.cod_modalidad,603,ahh.cod_moneda,                                                           gcc.cod_persona,
                                                           fug_obt_plz_contable(ahh.fec_vencimiento - ahh.fec_apertura),
                                                           'D', ahh.estado)),0) APCONCTA,
fub_obt_rub_transaccion(ahh.cod_modulo,ahh.cod_modalidad,603,ahh.cod_moneda,gcc.cod_persona,
                        fug_obt_plz_contable(ahh.fec_vencimiento - ahh.fec_apertura),'D',ahh.estado) rub_transaccion,
to_number(nvl(ahh.cod_oficina,0)) APOFIREG,
nvl(gb.usu_insercion, ' ') APOPRREG,
nvl(ahh.serie,'') APSERCDA,
'certificado' tipo


from pr_garantias pg, pr_gar_cash pgc,ge_bloqueos gb, ge_cta_clientes gcc, ah_cta_certificados ahh
where pg.nro_garantia = pgc.nro_garantia--garantias con cash
and pg.estado in ('C','V',/*'N',*/'T')--garantias
and gcc.relacion = 'P'--relacion cliente
and pgc.nro_cta_referencia = gb.nro_cuenta--cash con bloqueos
and pgc.nro_cta_referencia = ahh.nro_cuenta--cash con certificados
and gb.cod_causa = '230'--bloqueos
and gcc.nro_cuenta=ahh.nro_cuenta--cta cliente con vistas
and pgc.nro_cta_referencia=gcc.nro_cuenta---cash con cta cliente


UNION ALL
--ctas corrientes
select distinct

to_number(nvl(gcc.cod_persona,0)) APRIESGO,
to_number(nvl(substr(ccc.nro_cuenta,1,2),0)) APSUCUR,
to_number(nvl(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(ccc.nro_cuenta,3,2),ccc.cod_moneda),0)) APCUENTA,
to_number(nvl(substr(ccc.nro_cuenta,5,6),0)) APSUBCTA,
0 APBENEF,
0 APSERVI,
to_number(nvl(to_char(gb.fec_inicio,'yyyymmdd'),0)) APFCHCON,
nvl(gb.monto,0) APMONTO,
to_number(nvl(to_char(pg.fec_vencimiento,'yyyymmdd'),0)) APVENCIM,
0 APFCHULC,
to_number(nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(ccc.cod_modulo,ccc.cod_modalidad,2604,ccc.cod_moneda,
                                                           gcc.cod_persona,fug_obt_plz_contable(ccc.fec_ult_movimiento - ccc.fec_apertura),
                                                           'C',ccc.estado)),0)) APMAYOR,
fub_obt_rub_transaccion(ccc.cod_modulo,ccc.cod_modalidad,2604,ccc.cod_moneda,
                        gcc.cod_persona,fug_obt_plz_contable(ccc.fec_ult_movimiento- ccc.fec_apertura),
                        'C',ccc.estado) rub_transaccion0,
nvl(PAI_INT.FU_SIM_NORM_CADENA(gb.observacion,30),'') APREFER,
to_number(nvl(to_char(gb.fec_insercion,'yymmdd'),0)) APFCHREG,
' ' APESTADO,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(ccc.cod_modulo,ccc.cod_modalidad,2604,ccc.cod_moneda,                                                           gcc.cod_persona,
                                                           fug_obt_plz_contable(ccc.fec_ult_movimiento - ccc.fec_apertura),
                                                           'D', ccc.estado)),0) APCONCTA,
fub_obt_rub_transaccion(ccc.cod_modulo,ccc.cod_modalidad,2604,ccc.cod_moneda,gcc.cod_persona,
                        fug_obt_plz_contable(ccc.fec_ult_movimiento - ccc.fec_apertura),'D',ccc.estado) rub_transaccion,
to_number(nvl(ccc.cod_oficina,0)) APOFIREG,
nvl(gb.usu_insercion, ' ') APOPRREG,
'' APSERCDA,
'ctas corrientes' tipo

from pr_garantias pg, pr_gar_cash pgc, ge_bloqueos gb, ge_cta_clientes gcc, cc_cta_corrientes ccc
where pg.nro_garantia = pgc.nro_garantia--garantias con cash
and gcc.relacion = 'P'--relacion cliente
and pg.estado in ('C','V',/*'N',*/'T')--garantias
and pgc.nro_cta_referencia = gb.nro_cuenta--cash con bloqueos
and pgc.nro_cta_referencia = ccc.nro_cuenta--cash con certificados
and ccc.nro_cuenta=gb.nro_cuenta
and gb.cod_causa = '230'--bloqueos
and gcc.cod_persona=pg.cod_persona---cta cliente con garantias
and pgc.nro_cta_referencia=gcc.nro_cuenta---cash con cta cliente
)arp
;

