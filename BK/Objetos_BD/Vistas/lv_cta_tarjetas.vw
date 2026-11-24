create or replace view it.lv_cta_tarjetas as
select
  C.NRO_CUENTA    NRO_CUENTA,
  C.COD_MODALIDAD COD_MODALIDAD,
  CL.COD_PERSONA  COD_PERSONA,
  C.AFINIDAD      AFINIDAD,
  C.COD_OFICINA   COD_OFICINA,

  case when to_number(to_char(C.FEC_SOLICITUD, 'yyyy')) < 1593 and C.FEC_SOLICITUD is not null then to_date(to_char(C.FEC_SOLICITUD, 'dd/mm') || '/2010', 'dd/mm/yyyy')
    else C.FEC_SOLICITUD end FEC_SOLICITUD,

  C.ESTADO                  ESTADO,
  C.NRO_LINEA               NRO_LINEA,
  PAG_GEN.FU_OBT_MON_FUERTE COD_MONEDA,
  PAG_GEN.FU_CON_MON_A_MONEDA(C.COD_MONEDA, PAG_GEN.FU_OBT_MON_FUERTE,  (nvl(C.SAL_FACTURAR, 0) + nvl(C.SAL_FACTURADO, 0) + nvl(C.SAL_FINANCIADO, 0) + nvl(C.SAL_CUO_PENDIENTES, 0))) DEU_TARJETA


from TA_CTA_TARJETAS C,
     GE_CTA_CLIENTES CL

where C.NRO_CUENTA = CL.NRO_CUENTA
and CL.RELACION = 'P'
and C.ESTADO != 'C';
