Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('AFINIDAD', 'Mastercard Ultra Black GP', to_date('11-10-2023 15:15:42', 'dd-mm-yyyy hh24:mi:ss'), 'PARRUA', 'PARRUA', to_date('11-10-2023 15:15:42', 'dd-mm-yyyy hh24:mi:ss'), '0603', null, 'MCUBLGP', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('SUB_AFINIDAD', 'Mastercard Ultra Black', to_date('11-10-2023 15:15:54', 'dd-mm-yyyy hh24:mi:ss'), 'PARRUA', 'PARRUA', to_date('11-10-2023 15:15:54', 'dd-mm-yyyy hh24:mi:ss'), '088', '0603', 'MCUB', 'S');
commit;
