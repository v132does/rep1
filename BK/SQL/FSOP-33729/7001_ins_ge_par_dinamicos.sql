begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('CAN_CTA_CAN_CHE', '60', null, null, null, null, 'IT', to_date('16-07-2024 09:40:57', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('16-07-2024 10:52:34', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
