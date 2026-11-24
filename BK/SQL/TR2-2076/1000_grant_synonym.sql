-- Create the synonym
create or replace public synonym fut_obt_cod_uuid
  for IT.fut_obt_cod_uuid;
-- grant
grant execute on IT.fut_obt_cod_uuid to IT_TEMPORAL;
