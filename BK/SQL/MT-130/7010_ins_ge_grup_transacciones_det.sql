begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (16, 1127, 9, 91);

commit;
