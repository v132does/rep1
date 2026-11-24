Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_MAD_DEB_BLACK', 'Cod. Modalidad TD GP Black', 'GE_PAR_DINAMICOS', null, 'AAGUILERA', to_date('07-05-2024 14:25:17', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('07-05-2024 14:25:17', 'dd-mm-yyyy hh24:mi:ss'), 'Cod. Modalidad TD GP Black', null, null, 'N', null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('COD_MAD_DEB_BLACK', 'S', 3, 31, null, null, 'MIGRA', to_date('17-09-2023 09:24:42', 'dd-mm-yyyy hh24:mi:ss'), 'PARRUA', to_date('28-09-2023 11:38:35', 'dd-mm-yyyy hh24:mi:ss'), 1);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('COD_MAD_DEB_BLACK', 'S', 3, 334, null, null, 'MIGRA', to_date('17-09-2023 09:24:42', 'dd-mm-yyyy hh24:mi:ss'), 'PARRUA', to_date('28-09-2023 11:38:35', 'dd-mm-yyyy hh24:mi:ss'), 1);
commit;
