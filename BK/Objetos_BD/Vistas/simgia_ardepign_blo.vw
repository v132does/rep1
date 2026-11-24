CREATE OR REPLACE FORCE VIEW IT.SIMGIA_ARDEPIGN_BLO AS
select arp."APRIESGO",arp."APSUCUR",arp."APCUENTA",arp."APSUBCTA",rownum APIDENT,arp."APBENEF",arp."APSERVI",arp."APFCHCON",arp."APMONTO",arp."APVENCIM",arp."APFCHULC",arp."APMAYOR",arp."RUB_TRANSACCION0",arp."APREFER",arp."APFCHREG",arp."APESTADO",arp."APCONCTA",arp."RUB_TRANSACCION",arp."APOFIREG",arp."APOPRREG",arp."APSERCDA",arp."TIPO"
from
(

SELECT to_number(nvl((Select gc.cod_persona
from ge_cta_clientes gc
where gc.nro_cuenta= ah.nro_cuenta
and gc.cod_modulo= ah.cod_modulo
and gc.cod_modalidad= ah.cod_modalidad
and gc.relacion = 'P'),0)) APRIESGO,
to_number(nvl(substr(ge.nro_cuenta,1,2),0)) APSUCUR,
to_number(nvl(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(ge.nro_cuenta,3,2),ah.cod_moneda),0)) APCUENTA,
to_number(nvl(ah.nro_certificado,0)) APSUBCTA,
0 APBENEF,
0 APSERVI,
to_number(nvl(to_char(ge.fec_inicio,'yyyymmdd'),0)) APFCHCON,
nvl(ge.monto,0) APMONTO,
to_number(nvl(to_char(gc.fec_vencimiento ,'yyyymmdd'),0)) APVENCIM,
0 APFCHULC,

to_number(nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(3,
                                                           33,
                                                           603,
                                                           ah.cod_moneda,
                                                           e.cod_persona,
                                                           fug_obt_plz_contable(ah.fec_vencimiento - ah.fec_apertura),
                                                           'C',
                                                            ah.estado)),0)) APMAYOR,
fub_obt_rub_transaccion(3,
                                                           33,
                                                           603,
                                                           ah.cod_moneda,
                                                           e.cod_persona,
                                                           fug_obt_plz_contable(ah.fec_vencimiento - ah.fec_apertura),
                                                           'C',
                                                            ah.estado) RUB_TRANSACCION0,
nvl(PAI_INT.FU_SIM_NORM_CADENA(ge.observacion,30),'') APREFER,
to_number(nvl(to_char(ge.fec_insercion,'yymmdd'),0)) APFCHREG,
' ' APESTADO,
nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(3,
                                                           33,
                                                           603,
                                                           ah.cod_moneda,
                                                           e.cod_persona,
                                                           fug_obt_plz_contable(ah.fec_vencimiento - ah.fec_apertura),
                                                           'D',
                                                            ah.estado)),0) APCONCTA,
fub_obt_rub_transaccion(3,
                                                           33,
                                                           603,
                                                           ah.cod_moneda,
                                                           e.cod_persona,
                                                           fug_obt_plz_contable(ah.fec_vencimiento - ah.fec_apertura),
                                                           'D',
                                                            ah.estado) RUB_TRANSACCION,
to_number(nvl((Select ah.cod_oficina
from ah_cta_certificados ah
where ah.nro_cuenta= ge.nro_cuenta),0)) APOFIREG,
nvl(ge.usu_insercion,'') APOPRREG,
nvl((Select a.serie
from ah_cta_certificados a
where a.nro_cuenta= ge.nro_cuenta),'') APSERCDA,
'cda bloqueos' tipo
From ge_bloqueos ge , ah_cta_certificados ah, ge_cta_clientes e, pr_gar_cash gc
where ge.nro_cuenta= ah.nro_cuenta
   and ge.nro_cuenta = gc.nro_cta_referencia(+)
   and (exists(select 1 from pr_garantias g where gc.nro_garantia = g.nro_garantia and g.estado = 'C') or gc.nro_garantia is null)
   and ge.cod_causa in (230,231,227)
and ge.nro_cuenta = e.nro_cuenta
and e.relacion = 'P'
--and ge.cod_causa IN (227)
and ge.cod_causa IN (227,230,231)
)arp
;

