begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into IT.GE_GRU_TRANSACCIONES (COD_GRU_TRANSACCION, DESCRIPCION, CONDICION)
values (114, 'TRANSACCIONES DE CREDITO', 'I');

commit;
