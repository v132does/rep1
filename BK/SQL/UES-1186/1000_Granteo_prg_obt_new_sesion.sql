-- create the synonym 
create or replace public synonym prg_get_new_session for it.prg_get_new_session;
grant execute on it.prg_get_new_session to it_temporal;
