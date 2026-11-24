Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/ 

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('GLP_TIP_PRO_MODAL', 'MODALIDAD HAB POR PRODUCTO', to_date('05-07-2024 16:17:41', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', 'AAGUILERA', to_date('05-07-2024 16:17:41', 'dd-mm-yyyy hh24:mi:ss'), '87', 'COD_MAD_DEB_ULT_BLACK', null, 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('GLP_TIP_PRO_MODAL', 'MODALIDAD HAB POR PRODUCTO', to_date('13-05-2024 10:01:58', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', 'AAGUILERA', to_date('13-05-2024 10:01:58', 'dd-mm-yyyy hh24:mi:ss'), '88', 'COD_MAD_DEB_ULT_BLACK', null, 'S');

commit;
