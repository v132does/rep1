BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA)
values ('COD_CAR_DIFERIDO', 'CARGOS DIFERIDOS', '2', '2', 'CARGO');

COMMIT;
