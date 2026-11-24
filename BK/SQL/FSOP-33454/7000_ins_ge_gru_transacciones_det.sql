
begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
/

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (16, 375, 9, 91, 'IT', to_date('12-07-2024 09:28:33', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('12-07-2024 09:28:33', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (16, 374, 9, 91, 'IT', to_date('12-07-2024 09:28:33', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('12-07-2024 09:28:33', 'dd-mm-yyyy hh24:mi:ss'));

commit;
/