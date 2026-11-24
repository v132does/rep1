BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_Transacciones_det (COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, COD_TRA_HIJO, COD_MOD_HIJO, COD_MAD_HIJO, NRO_ORDEN, OBLIGATORIO)
values (353, 9, 91, 490, 4, 41, 3, 'S');

COMMIT;
