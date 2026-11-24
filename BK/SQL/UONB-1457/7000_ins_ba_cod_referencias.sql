begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('ONB_OCUPACIONES', 'JUBILADO', '7', '749911', null, 'S');
 
commit;
