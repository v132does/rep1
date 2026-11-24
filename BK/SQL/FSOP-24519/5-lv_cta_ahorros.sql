create or replace view it.lv_cta_ahorros as
select

  C.NRO_CUENTA NRO_CUENTA,
  C.DENOMINACION DENOMINACION,
  C.COD_MODALIDAD COD_MODALIDAD,
  CL.COD_PERSONA COD_PERSONA,
  PAG_GEN.FU_OBT_MON_FUERTE COD_MONEDA,
  C.COD_OFICINA COD_OFICINA,
  PAG_GEN.FU_CON_MON_A_MONEDA(C.COD_MONEDA, PAG_GEN.FU_OBT_MON_FUERTE, C.SAL_TOTAL) SAL_TOTAL,
  PAG_GEN.FU_CON_MON_A_MONEDA(C.COD_MONEDA, PAG_GEN.FU_OBT_MON_FUERTE, round(FUA_OBT_SAL_PROMEDIO(C.COD_MODULO, C.COD_MODALIDAD, C.COD_OFICINA, C.NRO_CUENTA, (trunc(sysdate, 'YEAR') - interval '1' year), (last_day(trunc(sysdate, 'YEAR')) - interval '1' month))), 2) SAL_PROMEDIO,
  C.FEC_APERTURA FEC_APERTURA, C.FEC_ULT_MOVIMIENTO FEC_ULT_MOVIMIENTO,

  case when C.ESTADO = 'B' or C.ESTADO = 'D' or C.ESTADO = 'S' or C.ESTADO = 'T' then 'S' else 'N' end BLOQUEADO,
 C.ESTADO ESTADO

from AH_CTA_VISTAS C,
     GE_CTA_CLIENTES CL
     
where C.NRO_CUENTA = CL.NRO_CUENTA
and C.ESTADO not in('A', 'P', 'X', 'C')
and CL.RELACION = 'P';

-- Create the synonym
create or replace public synonym lv_cta_ahorros
  for IT.lv_cta_ahorros;
