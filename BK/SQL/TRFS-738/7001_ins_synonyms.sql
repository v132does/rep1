-- Create the synonym 
create or replace public synonym paw_tranf_migration
  for IT.paw_tranf_migration;


-- granted to roles
grant execute on IT.paw_tranf_migration to IT_TEMPORAL;