begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_CIERRE', 'Usuario Mov. Cierre 3', 'MOVCIERRE3', '3', 'MOVCIERRE', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_CIERRE', 'Usuario Mov. Cierre 4', 'MOVCIERRE4', '4', 'MOVCIERRE', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_CIERRE', 'Usuario Mov. Cierre 5', 'MOVCIERRE5', '5', 'MOVCIERRE', 'S');

commit;