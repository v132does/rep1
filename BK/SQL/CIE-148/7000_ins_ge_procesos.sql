Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_procesos (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO, HOR_INICIO, HOR_FIN, COD_USUARIO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ERROR, PERMISO, UBI_DESTINO)
values (14, 'GENERA ASIENTOS AUT. DEL CIERRE', 1, 'N', 'N', null, null, null, 'JNICORA', to_date('27-03-2025 10:09:04', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('27-03-2025 15:56:07', 'dd-mm-yyyy hh24:mi:ss'), null, null, null);

COMMIT;