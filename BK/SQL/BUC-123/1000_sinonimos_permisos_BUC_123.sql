-- Create the synonym 
create or replace public synonym BA_PER_INF_BASICAS
  for IT.BA_PER_INF_BASICAS;
  
-- Grant/Revoke object privileges 
grant select, insert, update, delete on IT.BA_PER_INF_BASICAS to IT_TEMPORAL;
