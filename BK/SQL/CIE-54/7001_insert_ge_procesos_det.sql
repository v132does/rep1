begin
  pre_ini_aplicacion;
  pae_cnf.G_COD_MODULO :=1;
  end;
  /
insert into ge_procesos_det (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, HOR_INICIO, HOR_FIN, COD_USUARIO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ERROR, DIR_DESTINATARIO, ACTIVO, FORMATO, CLAVE, CON_COPIA, NOM_ARCHIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO, VAR_SUSTITUCION)
values (311, 151, 'INFORME DIARIO CIDESA', 'PRB_INF_DIA_CIDESA', 'N', 'D', null, null, null, 'IT', to_date('30-10-2024 15:02:02', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('30-10-2024 15:02:02', 'dd-mm-yyyy hh24:mi:ss'), null, null, 'S', null, null, null, null, 'S', ',', '"', null);

insert into ge_procesos_det (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, HOR_INICIO, HOR_FIN, COD_USUARIO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ERROR, DIR_DESTINATARIO, ACTIVO, FORMATO, CLAVE, CON_COPIA, NOM_ARCHIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO, VAR_SUSTITUCION)
values (311, 152, 'ARCHIVO DIARIO CIDESA', 'PA_REP_AUT.PR_ARCH_CIDESA', 'N', 'D', null, null, null, 'IT', to_date('30-10-2024 15:02:02', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('30-10-2024 15:02:02', 'dd-mm-yyyy hh24:mi:ss'), null, null, 'S', null, null, null, null, 'S', ',', '"', null);

commit;
