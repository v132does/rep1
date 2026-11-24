Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('GLP_TIP_PRO_RELACION', 'RELACION PRODUCTO DEB/CRE', to_date('09-05-2024 10:48:26', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', 'AAGUILERA', to_date('09-05-2024 10:48:26', 'dd-mm-yyyy hh24:mi:ss'), '87', '88', 'gptip_prod_rel_deb_cred', 'S');

commit;
