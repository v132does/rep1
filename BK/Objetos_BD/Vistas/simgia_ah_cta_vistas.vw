create or replace force view it.simgia_ah_cta_vistas as
select to_number(substr(acv.nro_cuenta,1,2)) sucursal,
to_number(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(acv.nro_cuenta,3,2),acv.cod_moneda)) cuenta,
to_number(substr(acv.nro_cuenta,5,6)) subcuenta,

acv."NRO_CUENTA",acv."DIG_VERIFICADOR",acv."COD_MODULO",acv."COD_MODALIDAD",acv."COD_OFICINA",acv."COD_MONEDA",acv."DENOMINACION",acv."FRE_EXTRACTO",acv."CAN_FIR_REQUERIDAS",acv."CAN_FIR_REGISTRADAS",acv."FEC_APERTURA",acv."TIP_CAPITALIZACION",acv."TAS_PERSONALIZADA",acv."COD_TASA",acv."RET_PERSONALIZADA",acv."SAL_MINIMO",acv."COD_USU_PROMOTOR",acv."EST_BATCH",acv."ESTADO",acv."NRO_FOLIO",acv."FEC_ULT_EXTRACTO",acv."SAL_ULT_EXTRACTO",acv."FEC_CAM_ESTADO",acv."FEC_ULT_MOVIMIENTO",acv."HOR_ULT_MOVIMIENTO",acv."FEC_ULT_CAPITALIZACION",acv."SAL_ULT_CAPITALIZACION",acv."SAL_RET_BATCH", to_number(acv.SAL_RETENIDO) sal_retenido, acv."SAL_BLO_BATCH",to_number(acv."SAL_BLOQUEADO") sal_bloqueado,acv."SAL_TOT_BATCH", to_number(acv."SAL_TOTAL") sal_total,acv."TRA_PROHIBIDA",acv."CTA_COMBINADA",acv."AUT_PENDIENTE",acv."MTO_DEB_PENDIENTES",acv."MTO_CRE_PENDIENTES",acv."MTO_CRE_A_CONFIRMAR",acv."COD_ENTE",acv."MTO_APERTURA",acv."COD_CANAL",acv."COD_CAMPANA",acv."REG_FIRMA",acv."USU_INSERCION",acv."FEC_INSERCION",acv."USU_MODIFICACION",acv."FEC_MODIFICACION",acv."COD_CAU_CANCELACION",acv."NRO_REF_EXTERNO",acv."COD_BANCO",acv."COD_SUB_MODALIDAD",
       /*case
        when ccc.nro_cta_cte is null then
             pai_int.FU_OBT_CTA_CONTABLE(fub_obt_rub_contable(acv.cod_modulo, acv.nro_cuenta, null))
        else*/
             pai_int.FU_OBT_CTA_CONTABLE(fub_obt_rub_transaccion(acv.cod_modulo,
                                                           acv.cod_modalidad,
                                                           682,
                                                           acv.cod_moneda,
                                                           gcc.cod_persona,
                                                            '1',
                                                           decode(acv.cta_combinada,'S','C','D')))
       /*end */cod_rub_externo,
       fub_obt_rub_transaccion(acv.cod_modulo,
                                                           acv.cod_modalidad,
                                                           682,
                                                           acv.cod_moneda,
                                                           gcc.cod_persona,
                                                            '1',
                                                           decode(acv.cta_combinada,'S','C','D')) cod_rubro,
       nvl((select sum(a.monto) from ge_bloqueos a where a.cod_causa = 245 and a.nro_cuenta = acv.nro_cuenta and a.fec_fin is null),0) MTO_EMBARGO
from ah_cta_vistas acv, cc_cta_combinadas ccc, ge_cta_clientes gcc, ge_clientes gc
where acv.nro_cuenta = ccc.nro_cta_ahorro(+)
and   acv.nro_cuenta = gcc.nro_cuenta
and   gc.cod_persona(+)=gcc.cod_persona
and   gcc.relacion like 'P'
--Desarrollado por Simgia, programador Juan Bauer.
;

