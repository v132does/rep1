BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('TIP_FOR_RECHAZADO', 'Cheques Rechazados for formalistica', sysdate, user, user, sysdate, 'CHE_RECHBC', 'GS', 'PRODEP', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('TIP_FOR_RECHAZADO', 'Cheques Rechazados for formalistica USD', sysdate, user, user, sysdate, 'CHE_RECHBC_USD', 'USD', 'PRODEP', 'S');

COMMIT;
