begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
--
delete from ge_par_dinamicos d where d.parametro =  'MTO_CHE_RET_CERO' and d.cod_moneda = 'USD';


insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('MTO_CHE_RET_CERO', '1000000000', null, null, null, 'USD', 'IT', to_date('19-12-2023 11:29:57', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('19-12-2023 15:07:05', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;