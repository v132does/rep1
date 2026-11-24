-- Grant/Revoke object privileges 
grant select, insert, update, delete on it.ge_men_cli_mt940_v1 to IT_TEMPORAL;
create public synonym ge_men_cli_mt940_v1 for it.ge_men_cli_mt940_v1;