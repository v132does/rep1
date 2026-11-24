create or replace public synonym GE_ONB_CTA_LOG
  for IT.GE_ONB_CTA_LOG;
  
grant select, update, delete, insert on IT.GE_ONB_CTA_LOG to IT_TEMPORAL;
