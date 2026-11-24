create or replace view it.lv_cta_corrientes as
select
  C.NRO_CUENTA              NRO_CUENTA,
  CL.COD_PERSONA,
  C.DENOMINACION            DENOMINACION,
  C.COD_MODALIDAD           COD_MODALIDAD,
  PAG_GEN.FU_OBT_MON_FUERTE COD_MONEDA,
  C.COD_OFICINA             COD_OFICINA,
  C.FEC_APERTURA            FEC_APERTURA,
  C.FEC_ULT_MOVIMIENTO      FEC_ULT_MOVIMIENTO,

 case when C.ESTADO = 'B' or C.ESTADO = 'D' or C.ESTADO = 'S' or C.ESTADO = 'T' then 'S'
   else 'N' end BLOQUEADO,

  C.ESTADO ESTADO

  from CC_CTA_CORRIENTES C,
       GE_CTA_CLIENTES CL
  where C.NRO_CUENTA = CL.NRO_CUENTA
  and C.ESTADO NOT IN ('A', 'P', 'X', 'C')
  and CL.RELACION = 'P';
