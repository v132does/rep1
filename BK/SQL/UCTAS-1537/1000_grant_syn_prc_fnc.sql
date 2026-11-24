create or replace public synonym prg_obt_per_inh_bcp_servicios for it.prg_obt_per_inh_bcp_servicios;
create or replace public synonym fue_env_bcp_post for it.fue_env_bcp_post;
grant execute on it.prg_obt_per_inh_bcp_servicios to it_temporal;
grant execute on it.fue_env_bcp_post to it_temporal;
