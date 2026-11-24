create or replace view it.lv_cta_clientes as
select
  COD_PERSONA,
  NRO_CUENTA,
  DIG_VERIFICADOR,
  COD_OFICINA,
  COD_MODULO,
  COD_MODALIDAD,
  RELACION,
  USU_INSERCION,
  FEC_INSERCION,
  USU_MODIFICACION,
  FEC_MODIFICACION,
  EST_RELACION

from GE_CTA_CLIENTES
where COD_MODULO in(3, 4, 5, 6, 7);
-- Create the synonym
create or replace public synonym lv_cta_clientes
  for IT.lv_cta_clientes;
