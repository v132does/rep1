begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('AFE_CTA_AHORRO_BAJO_RIESGO', 'AFECTA A CTAS DE AHORRO BAJO RIESGO', 'GE_PAR_CAUSALES', 'I', 'IT', to_date('09-04-2009 12:11:03', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('22-04-2012 21:29:45', 'dd-mm-yyyy hh24:mi:ss'), 'Utilizado como dato adicional de causas de inhibición', null, null, 'N', null);

