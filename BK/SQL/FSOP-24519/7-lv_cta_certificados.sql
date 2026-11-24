create or replace view it.lv_cta_certificados as
select
  C.NRO_CUENTA              NRO_CUENTA,
  C.DENOMINACION            DENOMINACION,
  CL.COD_PERSONA            COD_PERSONA,
  PAG_GEN.FU_OBT_MON_FUERTE COD_MONEDA,
  C.COD_OFICINA COD_OFICINA,
  null TIP_DEPOSITO,
  C.FEC_APERTURA            FEC_APERTURA,
  C.ESTADO                  ESTADO, 
  C.FEC_VENCIMIENTO         FEC_VENCIMIENTO,
  decode(C.ESTADO, 'B', 'S', 'N') BLOQUEADO,
  PAG_GEN.FU_CON_MON_A_MONEDA(C.COD_MONEDA, PAG_GEN.FU_OBT_MON_FUERTE, C.SAL_TOTAL) SAL_TOTAL,
  PAG_GEN.FU_CON_MON_A_MONEDA(C.COD_MONEDA, PAG_GEN.FU_OBT_MON_FUERTE, round(FUA_OBT_SAL_PROMEDIO(C.COD_MODULO, C.COD_MODALIDAD, C.COD_OFICINA, C.NRO_CUENTA, (trunc(sysdate, 'YEAR') - interval '1' year), (last_day(trunc(sysdate, 'YEAR')) - interval '1' month))), 2) SAL_PROMEDIO
  

from AH_CTA_CERTIFICADOS C,
     GE_CTA_CLIENTES CL

where C.NRO_CUENTA = CL.NRO_CUENTA
and CL.RELACION    = 'P'
and C.ESTADO not in ('A', 'P', 'X', 'C', 'T');
-- Create the synonym
create or replace public synonym lv_cta_certificados 
  for IT.lv_cta_certificados;
