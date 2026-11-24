BEGIN
  PRE_INI_APLICACION; 
  PAE_CNF.G_COD_MODULO := 1;
END;
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario bepsa 0', 'BEPSA', '0', 'BEPSA', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario bepsa 1', 'BEPSA_1', '1', 'BEPSA', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario bepsa 2', 'BEPSA_2', '2', 'BEPSA', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario bepsa 3', 'BEPSA_3', '3', 'BEPSA', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario bepsa 4', 'BEPSA_4', '4', 'BEPSA', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario bepsa 5', 'BEPSA_5', '5', 'BEPSA', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario bepsa 6', 'BEPSA_6', '6', 'BEPSA', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario bepsa 7', 'BEPSA_7', '7', 'BEPSA', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario bepsa 8', 'BEPSA_8', '8', 'BEPSA', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario bepsa 9', 'BEPSA_9', '9', 'BEPSA', 'S');

COMMIT;
