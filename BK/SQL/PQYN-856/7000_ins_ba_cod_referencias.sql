BEGIN
  PRE_INI_APLICACION; 
  PAE_CNF.G_COD_MODULO := 1;
END;
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario UPAY 0', 'UPAY', '0', 'UPAY', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario UPAY 1', 'UPAY_1', '1', 'UPAY', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario UPAY 2', 'UPAY_2', '2', 'UPAY', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario UPAY 3', 'UPAY_3', '3', 'UPAY', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario UPAY 4', 'UPAY_4', '4', 'UPAY', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario UPAY 5', 'UPAY_5', '5', 'UPAY', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario UPAY 6', 'UPAY_6', '6', 'UPAY', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario UPAY 7', 'UPAY_7', '7', 'UPAY', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario UPAY 8', 'UPAY_8', '8', 'UPAY', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario UPAY 9', 'UPAY_9', '9', 'UPAY', 'S');

COMMIT;
