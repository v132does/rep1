---synonym---
create or replace public synonym typ_referencias for IT.typ_referencias;
create or replace public synonym typ_referencia for IT.typ_referencia;
create or replace public synonym s_nro_men_rec_sipap for IT.s_nro_men_rec_sipap;
create or replace public synonym s_nro_men_env_sipap for IT.s_nro_men_env_sipap;
create or replace public synonym fug_act_men_env_sipap for IT.fug_act_men_env_sipap;
create or replace public synonym ge_men_rec_sipap for IT.ge_men_rec_sipap;
create or replace public synonym ge_men_env_sipap for IT.ge_men_env_sipap;
--- granteo ---

grant execute on it.typ_referencia to IT_TEMPORAL;
grant execute on it.typ_referencias to IT_TEMPORAL;
grant execute on it.fug_act_men_env_sipap to IT_TEMPORAL;
grant select on it.s_nro_men_env_sipap to IT_TEMPORAL;
grant select on it.s_nro_men_rec_sipap to IT_TEMPORAL;
grant select,update on it.ge_men_env_sipap to IT_TEMPORAL;
grant select,update on it.ge_men_rec_sipap to IT_TEMPORAL;
