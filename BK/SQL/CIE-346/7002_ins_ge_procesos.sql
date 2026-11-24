Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_procesos (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO, HOR_INICIO, HOR_FIN, ERROR, PERMISO, UBI_DESTINO)
values (326, 'ACT. BATCH ORIGEN DE FONDOS.', 1, 'N', 'N', null, null, null,null,null);


  
insert into ge_procesos_det (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, HOR_INICIO, HOR_FIN, COD_USUARIO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ERROR, DIR_DESTINATARIO, ACTIVO, FORMATO, CLAVE, CON_COPIA, NOM_ARCHIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO, VAR_SUSTITUCION)
values (326, 1, 'ACT. BATCH ORIGEN DE FONDOS.', 'PRP_ACT_ORI_FONDOS', 'N', 'D', null, null, null, 'IT', to_date('30-10-2024 15:02:02', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('30-10-2024 15:02:02', 'dd-mm-yyyy hh24:mi:ss'), null, null, 'S', null, null, null, null, 'S', ',', '"', null);

commit;