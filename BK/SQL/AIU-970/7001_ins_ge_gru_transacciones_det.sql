begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_gru_transacciones_det (cod_gru_transaccion, cod_transaccion, cod_modulo, cod_modalidad)
     values (91,602,3,31);
commit;
