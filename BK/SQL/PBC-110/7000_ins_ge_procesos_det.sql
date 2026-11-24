begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into GE_PROCESOS_DET (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, HOR_INICIO, HOR_FIN, COD_USUARIO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ERROR, DIR_DESTINATARIO, ACTIVO, FORMATO, CLAVE, CON_COPIA, NOM_ARCHIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO, VAR_SUSTITUCION)
values (10, 422, 'ACUMULADO DEVENGADO DIARIO', 'PRG_ACT_DEV_DIARIO', 'S', 'D', null, null, null, 'IT', to_date(sysdate, 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date(sysdate, 'dd-mm-yyyy hh24:mi:ss'), null, null, 'S', null, null, null, null, 'S', ',', '"', null);
commit;
