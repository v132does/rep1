--Sinonimos
create or replace public synonym ta_con_tra_dia_cab_gp_tmp for it.ta_con_tra_dia_cab_gp_tmp;
create or replace public synonym ta_con_tra_dia_det_gp_tmp for it.ta_con_tra_dia_det_gp_tmp;
create or replace public synonym ta_con_tra_dia_res_gp_tmp for it.ta_con_tra_dia_res_gp_tmp;
-----------
create or replace public synonym ta_con_tra_dia_cab_gp for it.ta_con_tra_dia_cab_gp;
create or replace public synonym ta_con_tra_dia_det_gp for it.ta_con_tra_dia_det_gp;
create or replace public synonym ta_con_tra_dia_res_gp for it.ta_con_tra_dia_res_gp;

--Granteos
grant all on ta_con_tra_dia_cab_gp_tmp to IT_TEMPORAL;
grant all on ta_con_tra_dia_det_gp_tmp to IT_TEMPORAL;
grant all on ta_con_tra_dia_res_gp_tmp to IT_TEMPORAL;
----------
grant all on ta_con_tra_dia_cab_gp to IT_TEMPORAL;
grant all on ta_con_tra_dia_det_gp to IT_TEMPORAL;
grant all on ta_con_tra_dia_res_gp to IT_TEMPORAL;
