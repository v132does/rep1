create or replace view it.lv_cta_cambios as
select
  CL.COD_PERSONA  COD_PERSONA,
  C.COD_MONEDA    COD_MONEDA,
  C.MTO_LIMITE    MTO_LIM_MON_FUERTE,
  C.MTO_UTILIZADO MTO_UTI_MON_FUERTE,
  C.DENOMINACION  DENOMINACION,
  C.NRO_CUENTA    NRO_CUENTA,
  C.ESTADO        ESTADO

from LC_CTA_CAMBIOS C,
     GE_CTA_CLIENTES CL
     
where C.NRO_CUENTA = CL.NRO_CUENTA
and CL.RELACION = 'P'
and C.ESTADO not in('C', 'A');
-- Create the synonym
create or replace public synonym lv_cta_cambios 
  for IT.lv_cta_cambios;
