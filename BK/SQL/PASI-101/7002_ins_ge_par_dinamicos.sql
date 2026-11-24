Begin pre_ini_aplicacion; end; 
/
insert into GE_PAR_DINAMICOS (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('PRE_COD_CAU_BLO_CTA', '929', 6, 602, null, null, 'IT', to_date('07-10-2024 15:00:54', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('07-10-2024 15:00:54', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into GE_PAR_DINAMICOS (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('PRE_COD_CAU_BLO_CTA', '927', 6, 705, null, null, 'IT', to_date('07-10-2024 15:08:46', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('07-10-2024 15:08:46', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
