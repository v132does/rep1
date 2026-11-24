BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END; 
/
insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (9, 704, 6, 673, user, sysdate, user, sysdate);

/*
-- Estos ya existen en PROD
insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (9, 704, 6, 661, user, sysdate, user, sysdate);

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (9, 704, 6, 872, user, sysdate, user, sysdate);

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (9, 704, 6, 995, user, sysdate, user, sysdate);
*/

commit;
