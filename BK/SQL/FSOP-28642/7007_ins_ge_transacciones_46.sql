begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_transacciones (COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, DESCRIPCION, VE_CLIENTE, TIPO, ABREVIATURA, RUTINA1, RUTINA2, RUTINA3, COD_TIP_ASIENTO, COD_TASA, BATCH, COD_RETENCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, INTERNO, AFECTA, COD_TIP_ASIENTO2, DETALLADO, COD_TIP_ASI_RESULTADO, TIP_DESPLIEGUE)
values (9731, 4, 46, 'TRANSFERENCIA POR CONTACTO', 'S', 'P', 'TRACTA', null, null, null, null, null, 'O', null, 'LMENDOZA', to_date('22-05-2024 14:21:52', 'dd-mm-yyyy hh24:mi:ss'), 'LMENDOZA', to_date('22-05-2024 14:21:52', 'dd-mm-yyyy hh24:mi:ss'), 'N', 'N', null, 'N', null, null);

commit;
/
