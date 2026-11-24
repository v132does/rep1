create or replace public synonym cb_aut_asientos for it.cb_aut_asientos;

grant select, insert, update, delete on cb_aut_asientos to it_temporal;
