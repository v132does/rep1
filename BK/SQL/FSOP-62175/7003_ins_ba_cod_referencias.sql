Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, ABREVIATURA, ACTIVO)
values ('COD_MON_UMBRAL', 'GUARANIES', 'GS', 'Guaranies', 'S');

commit;
