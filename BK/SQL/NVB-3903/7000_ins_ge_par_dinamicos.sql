begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
delete from ge_par_dinamicos a
  where a.parametro = 'MTO_RET_PROVEEDOR';
/
commit;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('MTO_RET_PROVEEDOR', '1134001', null, null, null, null, 'IT', to_date('17-09-2023 09:24:42', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('20-12-2023 17:58:51', 'dd-mm-yyyy hh24:mi:ss'), null);
/
commit;
