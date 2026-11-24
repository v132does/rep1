Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
INSERT INTO GE_PROCESOS (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO)
VALUES (65, 'RIESGO_PLA', '1', 'N', 'P');

commit;
