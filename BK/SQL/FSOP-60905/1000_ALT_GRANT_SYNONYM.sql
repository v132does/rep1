CREATE OR REPLACE PUBLIC SYNONYM prp_gen_pre_apr_des_com_car FOR IT.prp_gen_pre_apr_des_com_car;--prp_gen_pre_apr_des_com_car
CREATE OR REPLACE PUBLIC SYNONYM prp_gen_sol_com_cartera FOR IT.prp_gen_sol_com_cartera;

GRANT ALL ON prp_gen_pre_apr_des_com_car TO IT_TEMPORAL;
GRANT ALL ON prp_gen_sol_com_cartera TO IT_TEMPORAL;
