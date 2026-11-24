create or replace public synonym fug_obt_tae_ade_com for it.fug_obt_tae_ade_com;
grant execute on fug_obt_tae_ade_com to it, it_temporal;

create or replace public synonym pr_cal_tasas for it.pr_cal_tasas;
grant select, delete, update, insert on pr_cal_tasas to it, it_temporal;
