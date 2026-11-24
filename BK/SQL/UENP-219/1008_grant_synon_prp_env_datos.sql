create or replace public synonym prp_env_datos
  for it.prp_env_datos;
  
grant execute on prp_env_datos to it_temporal;
