begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into it.ge_par_transacciones (COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, PARAMETRO, VAL_PARAMETRO)
values (101, 10, 149, 'COD_TRA_SWIFT_MT940', 'MSC');

insert into it.ge_par_transacciones (COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, PARAMETRO, VAL_PARAMETRO)
values (102, 10, 149, 'COD_TRA_SWIFT_MT940', 'MSC');

insert into it.ge_par_transacciones (COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, PARAMETRO, VAL_PARAMETRO)
values (360, 10, 149, 'COD_TRA_SWIFT_MT940', 'MSC');
/
commit;
/
