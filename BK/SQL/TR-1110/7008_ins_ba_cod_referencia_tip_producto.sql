Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('GLP_TIP_PRODUCTOS', 'CREDICENTRO ULTRABLACK CREDITO', to_date('07-05-2024 14:33:16', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', 'AAGUILERA', to_date('07-05-2024 14:34:42', 'dd-mm-yyyy hh24:mi:ss'), 'GP_CRE_COMBO_ULT_BLACK', '88', 'gp_tip_prod_cre_ult_black', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('GLP_TIP_PRODUCTOS', 'CREDICENTRO ULTRABLACK DEBITO', to_date('07-05-2024 14:33:15', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', 'AAGUILERA', to_date('07-05-2024 14:34:42', 'dd-mm-yyyy hh24:mi:ss'), 'GP_DEB_COMBO_ULT_BLACK', '87', 'gp_tip_prod_deb_ult_black', 'S');

commit;
