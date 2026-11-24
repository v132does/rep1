begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; pae_cnf.G_PROGRAMA := 'GPPROFIN'; end; 
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_CIERRE', 'Usuario Mov. Cierre 7', 'MOVCIERRE7', '7', 'MOVCIERRE', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_CIERRE', 'Usuario Mov. Cierre 8', 'MOVCIERRE8', '8', 'MOVCIERRE', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_CIERRE', 'Usuario Mov. Cierre 9', 'MOVCIERRE9', '9', 'MOVCIERRE', 'S');

commit;
