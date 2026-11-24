begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('TRANINT_CAN_MIN_USU', '1', null, null, null, null, 'BROLON', to_date('26-12-2024 18:02:10', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('26-12-2024 18:02:10', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('TRANINT_CAN_MAX_USU', '30', null, null, null, null, 'BROLON', to_date('26-12-2024 18:02:10', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('27-12-2024 15:34:34', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
