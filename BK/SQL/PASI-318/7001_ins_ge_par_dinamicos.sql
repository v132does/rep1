Begin pre_ini_aplicacion; end; 
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('PRE_DIG_COD_CAMPANA', '54', 6, 602, null, null, 'IT', to_date('26-11-2024 10:31:32', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('26-11-2024 10:31:32', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('PRE_DIG_COD_CAMPANA', '81', 6, 705, null, null, 'IT', to_date('26-11-2024 10:34:51', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('26-11-2024 10:34:51', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
