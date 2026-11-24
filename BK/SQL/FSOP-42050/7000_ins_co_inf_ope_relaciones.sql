begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
/

insert into co_inf_ope_relaciones (COD_MODULO, COD_INF_OPERACION, RELACION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_MODALIDAD)
values (15, 1, 'P', 'LMENDOZA', to_date('06-11-2024 16:10:47', 'dd-mm-yyyy hh24:mi:ss'), 'LMENDOZA', to_date('06-11-2024 16:16:46', 'dd-mm-yyyy hh24:mi:ss'), null);


commit;

