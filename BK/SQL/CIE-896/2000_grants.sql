grant execute on IT.PRA_CAP_CTA_VIS_PREVIO to IT_TEMPORAL;
create or replace public synonym PRA_CAP_CTA_VIS_PREVIO
  for IT.PRA_CAP_CTA_VIS_PREVIO;

grant select, insert, update, delete on IT.ah_cta_capitalizadas to IT_TEMPORAL;
create or replace public synonym ah_cta_capitalizadas
  for IT.ah_cta_capitalizadas;

grant execute on IT.PRA_CTA_VIS_NO_CAPITALIZAN to IT_TEMPORAL;
create or replace public synonym PRA_CTA_VIS_NO_CAPITALIZAN
  for IT.PRA_CTA_VIS_NO_CAPITALIZAN;
  
grant execute on IT.PRA_CAP_CTA_PREVIO_CIERRE to IT_TEMPORAL;
create or replace public synonym PRA_CAP_CTA_PREVIO_CIERRE
  for IT.PRA_CAP_CTA_PREVIO_CIERRE;