create or replace force view it.simgia_cc_cta_corrientes as
select to_number(substr(ccco.nro_cuenta,1,2)) sucursal,
to_number(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(ccco.nro_cuenta,3,2),ccco.cod_moneda)) cuenta,
to_number(substr(ccco.nro_cuenta,5,6)) subcuenta,


ccco."COD_MODULO",ccco."COD_MODALIDAD",ccco."COD_OFICINA",ccco."NRO_CUENTA",ccco."DIG_VERIFICADOR",ccco."COD_MONEDA",ccco."DENOMINACION",ccco."CAN_FIR_REQUERIDAS",ccco."CAN_FIR_REGISTRADAS",ccco."FEC_APERTURA",ccco."RET_PERSONALIZADA",ccco."TAS_PERSONALIZADA",ccco."SAL_MINIMO",ccco."AUT_PENDIENTE",ccco."ACU_SOBREGIRO",ccco."TRA_PROHIBIDA",ccco."CTA_COMBINADA",ccco."COD_USU_PROMOTOR",ccco."ESTADO",ccco."FEC_ULT_EXTRACTO",ccco."SAL_ULT_EXTRACTO",ccco."NRO_FOLIO",ccco."FEC_CAM_ESTADO",ccco."FEC_ULT_MOVIMIENTO",ccco."HOR_ULT_MOVIMIENTO",ccco."SAL_RET_BATCH", to_number(ccco."SAL_RETENIDO") sal_retenido ,ccco."SAL_BLO_BATCH",to_number(ccco."SAL_BLOQUEADO") sal_bloqueado,ccco."SAL_TOT_BATCH", to_number(ccco."SAL_TOTAL") sal_total,ccco."NOM_CHEQUERA",ccco."MTO_APERTURA",ccco."COD_CANAL",ccco."COD_CAMPANA",ccco."USU_INSERCION",ccco."FEC_INSERCION",ccco."USU_MODIFICACION",ccco."FEC_MODIFICACION",ccco."EST_BATCH",ccco."FRE_EXTRACTO",ccco."MTO_CRE_PENDIENTES",ccco."MTO_CRE_A_CONFIRMAR",ccco."COD_ENTE",ccco."MTO_DEB_PENDIENTES",ccco."REG_FIRMA",ccco."EN_JUICIO",ccco."FEC_JUICIO",ccco."COD_ENT_JUICIO",ccco."COD_CAU_CANCELACION",ccco."DIA_ATRASO",ccco."MAX_ATRASO",ccco."PRO_ATRASO",ccco."MTO_MORA",ccco."MTO_SOB_SUSPENSO",ccco."COD_BANCO",ccco."COD_SUB_MODALIDAD",

    pai_int.FU_OBT_CTA_CONTABLE(fub_obt_rub_transaccion(ccco.cod_modulo,
                            ccco.cod_modalidad,
                            602,
                            ccco.cod_moneda,
                            gcc.cod_persona,
                            '1',
                            'C')) cod_rub_externo,
                            fub_obt_rub_transaccion(ccco.cod_modulo,
                            ccco.cod_modalidad,
                            602,
                            ccco.cod_moneda,
                            gcc.cod_persona,
                            '1',
                            'C') cod_rubro,

    /*pai_int.FU_OBT_CTA_CONTABLE(pai_int.simgia_func_obt_rubro_contable(405,ccco.cod_moneda,'C',gc.cod_sec_contable, gc.residente)) cod_rub_externo,
    pai_int.simgia_func_obt_rubro_contable(405,ccco.cod_moneda,'C',gc.cod_sec_contable, gc.residente) cod_rubro,*/

    nvl((select sum(a.monto) from ge_bloqueos a where a.cod_causa = 245 and a.nro_cuenta = ccco.nro_cuenta and a.fec_fin is null),0) MTO_EMBARGO
from cc_cta_corrientes ccco,  ge_cta_clientes gcc, ge_clientes gc--, cb_rubros r
where   ccco.nro_cuenta = gcc.nro_cuenta(+)
and     gc.cod_persona(+) = gcc.cod_persona
and     gcc.relacion like 'P'
--and r.cod_rubro = pai_int.simgia_func_obt_rubro_contable(405,ccco.cod_moneda,'C',gc.cod_sec_contable, gc.residente)
;

