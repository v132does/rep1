begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('TRA_INT_USUARIO', 'USER PARA TRANSF. INTERNAS', to_date('26-12-2024 15:42:12', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', 'BROLON', to_date('26-12-2024 15:42:12', 'dd-mm-yyyy hh24:mi:ss'), 'TRANINT', 'TRANINT', null, 'S');

commit;
