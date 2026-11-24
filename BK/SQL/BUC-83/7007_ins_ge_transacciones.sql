begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_transacciones (COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, DESCRIPCION, VE_CLIENTE, TIPO, ABREVIATURA, RUTINA1, RUTINA2, RUTINA3, COD_TIP_ASIENTO, COD_TASA, BATCH, COD_RETENCION, INTERNO, AFECTA, COD_TIP_ASIENTO2, DETALLADO, COD_TIP_ASI_RESULTADO, TIP_DESPLIEGUE)
values (351, 3, 31, 'DEPOSITO EFECT./CHEQUES C/N/BANCO', 'N', 'C', 'D.EFEC', null, null, null, null, null, 'O', null, 'N', null, null, 'N', null, null);

commit;
