Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
--Monto minimo sin CU
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('TAR_MTO_MIN_SIN_CU', 'MONTO MINIMO OFERTA SIN CU', 'GE_PAR_DINAMICOS', null, 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), 'Monto minimo de la oferta sin CU', null, null, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('TAR_MTO_MIN_SIN_CU', '500000', null, null, null, null, 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), null);
select to_number(fug_obt_pardinamico('TAR_MTO_MIN_SIN_CU')) from dual


--Para ejecucion del job
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('MIN_ACT_SIN_CU', 'INTERVALO DE EJECUCION SIN CU', 'GE_PAR_DINAMICOS', null, 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), 'intervalo de ejecucion de asing limite sin cu', null, null, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('MIN_ACT_SIN_CU', '30', null, null, null, null, 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), null);


--estado final
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('EST_ACT_CU_TC', 'ESTADO POR ACTIVACION CU TC', 'GE_PAR_DINAMICOS', null, 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), 'Estado final en parametro por activacion de CU TC', null, null, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('EST_ACT_CU_TC', 'S', null, null, null, null, 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;