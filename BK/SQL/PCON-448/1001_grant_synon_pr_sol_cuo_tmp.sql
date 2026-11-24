--
create or replace public synonym pr_sol_cuo_tmp for it.pr_sol_cuo_tmp;
grant select, insert, update, delete on it.pr_sol_cuo_tmp to it_temporal;
