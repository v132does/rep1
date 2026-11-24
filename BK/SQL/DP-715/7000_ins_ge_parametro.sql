begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GP_LIMITE_BC', 'LIMITE BULK COLLECT', 'GE_PAR_DINAMICOS', null, 'IT', to_date('04-12-2025 14:02:23', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('04-12-2025 14:02:23', 'dd-mm-yyyy hh24:mi:ss'), 'Tamaño BULK COLLECT para volcado de datos dentro del proceso PRT_DEB_AUT_GP', null, null, 'N', null);
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GP_LOTE', 'TAMAÑO LOTE PARA PROCESAR COBROS GP', 'GE_PAR_DINAMICOS', null, 'IT', to_date('04-12-2025 13:59:02', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('04-12-2025 14:00:12', 'dd-mm-yyyy hh24:mi:ss'), 'Tamaño del lote para aplicar commit dentro del proceso PRT_DEB_AUT_GP', null, null, 'N', null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('GP_LIMITE_BC', '6000', null, null, null, null, 'IT', to_date('04-12-2025 14:02:30', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('04-12-2025 14:02:30', 'dd-mm-yyyy hh24:mi:ss'), null);
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('GP_LOTE', '2000', null, null, null, null, 'IT', to_date('04-12-2025 14:00:22', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('09-12-2025 14:23:01', 'dd-mm-yyyy hh24:mi:ss'), null);

