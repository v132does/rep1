--
create or replace public synonym pr_sol_car_tmp for it.pr_sol_car_tmp;
grant select, insert, update, delete on it.pr_sol_car_tmp to it_temporal;
