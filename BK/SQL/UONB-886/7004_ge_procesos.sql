begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_procesos (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO, HOR_INICIO, HOR_FIN, COD_USUARIO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ERROR, PERMISO, UBI_DESTINO)
values (800, 'PER_CUMPLIMIENTO', 1, 'N', 'P', '17:04:34', '17:04:35', 'CURIARTE', 'CURIARTE', to_date('26-06-2024 13:36:14', 'dd-mm-yyyy hh24:mi:ss'), 'CURIARTE', to_date('26-06-2024 17:04:35', 'dd-mm-yyyy hh24:mi:ss'), null, 'FIELCO_SUPANALIST-ANALISTA DE CONSUMO SENIOR', null);

commit;
