-- Drop indexes 
drop index IT.IND_AHCTAALIAS_NRO_CTA;
-- Create/Recreate indexes 
create index IT.IN_ACTALIAS_NRO_CTA_ALIAS on IT.AH_CTA_ALIAS_VI (NRO_CTA_ALIAS);
