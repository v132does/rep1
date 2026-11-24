-- Create the synonym 
create or replace public synonym PRG_VAL_COB_IPS_CLIENTE
  for IT.PRG_VAL_COB_IPS_CLIENTE;

grant execute on IT.PRG_VAL_COB_IPS_CLIENTE to IT_TEMPORAL;
