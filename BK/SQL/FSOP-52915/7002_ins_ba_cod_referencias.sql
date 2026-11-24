BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('TIP_DESTINO_RRR', 'Reestructuración', 'E', '25', 'Reestructuración', 'A');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('TIP_DESTINO_RRR', 'Renovación', 'N', '24', 'Renovación', 'A');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('TIP_DESTINO_RRR', 'Refinanciación', 'R', '26', 'Refinanciación', 'A');

COMMIT;
