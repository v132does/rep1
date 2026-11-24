Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PLA_VIGENCIA_RIESGO', 'Vigencia Riesgo Alto (12 meses / 1 año)', 'ALTO', 12, null, 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PLA_VIGENCIA_RIESGO', 'Vigencia Riesgo Medio (36 meses / 3 años)', 'MEDIO', 36, null, 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PLA_VIGENCIA_RIESGO', 'Vigencia Riesgo Bajo (60 meses / 5 años)', 'BAJO', 60, null, 'S');

COMMIT;
