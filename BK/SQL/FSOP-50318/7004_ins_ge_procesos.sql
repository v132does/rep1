begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
/

insert into ge_procesos (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO, HOR_INICIO, HOR_FIN, COD_USUARIO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ERROR, PERMISO, UBI_DESTINO)
values (192, 'BASE POSITIVA', 1, 'S', 'N', '09:45:17', '06:07:28', 'GASILVA', 'LMENDOZA', to_date('30-06-2025 06:17:43', 'dd-mm-yyyy hh24:mi:ss'), 'LMENDOZA', to_date('01-07-2025 06:17:43', 'dd-mm-yyyy hh24:mi:ss'), null, 'FIELCO_JEFCOBRANZ-JEFE COBRANZAS', null);


commit;
