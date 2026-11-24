begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('SNP_SPI_USUARIOS', 'USER PARA TRANSF. CORPS', to_date('10-08-2024 22:22:24', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', 'BROLON', to_date('02-10-2024 13:21:46', 'dd-mm-yyyy hh24:mi:ss'), 'OPE_IT', 'OPE_IT', null, 'S');

commit;
