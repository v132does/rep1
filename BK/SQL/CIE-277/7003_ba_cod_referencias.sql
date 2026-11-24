begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end; 
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('NRO_ORD_DEPURADA', 'NRO DE ORDEN DE GRUPO 1 TABLAS DEPURADAS', '1', '1', null, 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('NRO_ORD_DEPURADA', 'NRO DE ORDEN DE GRUPO 2 TABLAS DEPURADAS', '2', '3', null, 'S');

commit;