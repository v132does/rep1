Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_procesos_det (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, ACTIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO)
values (10, 421, 'ACTUALIZACION DE SALDO PROMEDIO', 'PRA_ACT_SAL_PROMEDIO', 'S', 'D', 'S', 'S', ',', '"');

commit;