BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_gru_transacciones (COD_GRU_TRANSACCION, DESCRIPCION, CONDICION)
values (22, 'GRUPO TRANSACCIONES IMPRESION FACTURA CREDITO', 'I');

COMMIT;
