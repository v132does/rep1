BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END; 
/

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('USU_AIR_T2001', 'Usuario Airflow T2001', 'GE_PAR_DINAMICOS', null, null, to_date('04-01-2024 14:59:20', 'dd-mm-yyyy hh24:mi:ss'), null, to_date('04-01-2024 14:59:20', 'dd-mm-yyyy hh24:mi:ss'), 'Usuariopor defecto del Airflow para procesar el Archivo GP T2001', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('USU_AIR_T3052', 'Usuario Airflow T3052', 'GE_PAR_DINAMICOS', null, null, to_date('04-01-2024 15:00:45', 'dd-mm-yyyy hh24:mi:ss'), null, to_date('04-01-2024 15:00:45', 'dd-mm-yyyy hh24:mi:ss'), 'Usuariopor defecto del Airflow para procesar el Archivo GP T3052', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('USU_AIR_T3022', 'Usuario Airflow T3022', 'GE_PAR_DINAMICOS', null, null, to_date('04-01-2024 15:00:45', 'dd-mm-yyyy hh24:mi:ss'), null, to_date('04-01-2024 15:00:45', 'dd-mm-yyyy hh24:mi:ss'), 'Usuariopor defecto del Airflow para procesar el Archivo GP T3022', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('USU_AIR_T2010', 'Usuario Airflow T2010', 'GE_PAR_DINAMICOS', null, null, to_date('04-01-2024 15:00:45', 'dd-mm-yyyy hh24:mi:ss'), null, to_date('04-01-2024 15:00:45', 'dd-mm-yyyy hh24:mi:ss'), 'Usuariopor defecto del Airflow para procesar el Archivo GP T2010', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('USU_AIR_T1016', 'Usuario Airflow T1016', 'GE_PAR_DINAMICOS', null, null, to_date('04-01-2024 15:00:46', 'dd-mm-yyyy hh24:mi:ss'), null, to_date('04-01-2024 15:00:46', 'dd-mm-yyyy hh24:mi:ss'), 'Usuariopor defecto del Airflow para procesar el Archivo GP T1016', null, null, 'N', null);
--
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('USU_AIR_T2001', 'AIRFLOW', null, null, null, null, null, to_date('04-01-2024 15:04:25', 'dd-mm-yyyy hh24:mi:ss'), null, to_date('04-01-2024 15:04:25', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('USU_AIR_T3052', 'AIRFLOW', null, null, null, null, null, to_date('04-01-2024 15:04:25', 'dd-mm-yyyy hh24:mi:ss'), null, to_date('04-01-2024 15:04:25', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('USU_AIR_T3022', 'AIRFLOW', null, null, null, null, null, to_date('04-01-2024 15:04:26', 'dd-mm-yyyy hh24:mi:ss'), null, to_date('04-01-2024 15:04:26', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('USU_AIR_T2010', 'AIRFLOW', null, null, null, null, null, to_date('04-01-2024 15:04:26', 'dd-mm-yyyy hh24:mi:ss'), null, to_date('04-01-2024 15:04:26', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('USU_AIR_T1016', 'AIRFLOW', null, null, null, null, null, to_date('04-01-2024 15:04:26', 'dd-mm-yyyy hh24:mi:ss'), null, to_date('04-01-2024 15:04:26', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
