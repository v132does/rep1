begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
--
delete ge_gru_transacciones_det where cod_gru_transaccion = 804;

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 245, 9, 91);

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 250, 9, 91);

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 352, 9, 91);

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 361, 9, 91);

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 362, 9, 91);

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 246, 9, 91);

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 241, 9, 91);

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 242, 9, 91);

commit;
