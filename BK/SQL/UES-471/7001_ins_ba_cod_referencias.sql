begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('TIP_ENTE', 'Débito Automático', 'DA', null, 'Servicio de débito automático', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario AISEDAS', 'AISEDAS', 0, 'AISEDAS', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario AISEDAS', 'AISEDAS_1', 1, 'AISEDAS', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario AISEDAS', 'AISEDAS_2', 2, 'AISEDAS', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario AISEDAS', 'AISEDAS_3', 3, 'AISEDAS', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario AISEDAS', 'AISEDAS_4', 4, 'AISEDAS', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario AISEDAS', 'AISEDAS_5', 5, 'AISEDAS', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario AISEDAS', 'AISEDAS_6', 6, 'AISEDAS', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario AISEDAS', 'AISEDAS_7', 7, 'AISEDAS', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario AISEDAS', 'AISEDAS_8', 8, 'AISEDAS', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_SERVICIO', 'Usuario AISEDAS', 'AISEDAS_9', 9, 'AISEDAS', 'S');

commit;
