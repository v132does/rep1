create or replace public synonym GE_ONB_VERIFICADOS
  for IT.GE_ONB_VERIFICADOS;
  
grant select, update, delete, insert on IT.GE_ONB_VERIFICADOS to IT_TEMPORAL;
