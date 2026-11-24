Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into GE_MODALIDADES (COD_MODULO, COD_MODALIDAD, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_GRU_CRUZAMIENTO, SIGLA, COD_PRO_CONTABLE, TIPO)
values (5, 55, 'MASTERCARD CREDIT ULTRABLACK-GLOBAL', 'AAGUILERA', to_date('29-04-2024 14:27:42', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('29-04-2024 14:27:42', 'dd-mm-yyyy hh24:mi:ss'), null, 'TC', null, 'A');

commit;
