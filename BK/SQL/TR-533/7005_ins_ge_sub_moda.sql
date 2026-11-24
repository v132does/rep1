Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_sub_modalidades (COD_MODULO, COD_MODALIDAD, COD_SUB_MODALIDAD, DESCRIPCION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (5, 54, 1, 'GENERAL', null, 'AAGUILERA', to_date('30-04-2024 10:52:35', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('30-04-2024 10:52:35', 'dd-mm-yyyy hh24:mi:ss'));

commit;
