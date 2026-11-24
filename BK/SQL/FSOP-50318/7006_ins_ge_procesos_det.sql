begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
/

insert into ge_procesos_det (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, HOR_INICIO, HOR_FIN, COD_USUARIO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ERROR, DIR_DESTINATARIO, ACTIVO, FORMATO, CLAVE, CON_COPIA, NOM_ARCHIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO, VAR_SUSTITUCION)
values (192, 1, 'PROCESO MENSUAL BASE POSITIVA', 'PRG_GEN_EQU_DATOS', 'N', 'D', null, null, null, 'LMENDOZA', to_date('30-06-2025 06:29:39', 'dd-mm-yyyy hh24:mi:ss'), 'LMENDOZA', to_date('01-07-2025 06:29:39', 'dd-mm-yyyy hh24:mi:ss'), null, null, 'S', null, null, null, null, 'S', ',', '"', null);

commit;
