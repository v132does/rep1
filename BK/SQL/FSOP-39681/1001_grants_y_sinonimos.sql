grant select, insert, update, delete on IT.SV_CON_SIPAP to IT_TEMPORAL;
grant select, insert, update, delete on IT.SB_EXT_MT940 to IT_TEMPORAL;
create or replace public synonym SV_CON_SIPAP for IT.SV_CON_SIPAP;
create or replace public synonym SB_EXT_MT940 for IT.SB_EXT_MT940;
