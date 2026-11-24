begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;  
/

insert into it.ba_cod_referencias
   (dominio, significado, val_minimo, val_maximo, abreviatura, activo)
values
   ('USU_MOV_SERVICIO', 'Usuario UAPIIPS', 'UAPIIPS', 0, 'UAPIIPS', 'S');
   
insert into it.ba_cod_referencias
   (dominio, significado, val_minimo, val_maximo, abreviatura, activo)
values
   ('USU_MOV_SERVICIO', 'Usuario UAPIIPS', 'UAPIIPS_1', 1, 'UAPIIPS', 'S');
   
insert into it.ba_cod_referencias
   (dominio, significado, val_minimo, val_maximo, abreviatura, activo)
values
   ('USU_MOV_SERVICIO', 'Usuario UAPIIPS', 'UAPIIPS_2', 2, 'UAPIIPS', 'S');   
      
   
insert into it.ba_cod_referencias
   (dominio, significado, val_minimo, val_maximo, abreviatura, activo)
values
   ('USU_MOV_SERVICIO', 'Usuario UAPIIPS', 'UAPIIPS_3', 3, 'UAPIIPS', 'S');  
   
insert into it.ba_cod_referencias
   (dominio, significado, val_minimo, val_maximo, abreviatura, activo)
values
   ('USU_MOV_SERVICIO', 'Usuario UAPIIPS', 'UAPIIPS_4', 4, 'UAPIIPS', 'S'); 
   
insert into it.ba_cod_referencias
   (dominio, significado, val_minimo, val_maximo, abreviatura, activo)
values
   ('USU_MOV_SERVICIO', 'Usuario UAPIIPS', 'UAPIIPS_5', 5, 'UAPIIPS', 'S');   
   
insert into it.ba_cod_referencias
   (dominio, significado, val_minimo, val_maximo, abreviatura, activo)
values
   ('USU_MOV_SERVICIO', 'Usuario UAPIIPS', 'UAPIIPS_6', 6, 'UAPIIPS', 'S'); 
   
insert into it.ba_cod_referencias
   (dominio, significado, val_minimo, val_maximo, abreviatura, activo)
values
   ('USU_MOV_SERVICIO', 'Usuario UAPIIPS', 'UAPIIPS_7', 7, 'UAPIIPS', 'S'); 

insert into it.ba_cod_referencias
   (dominio, significado, val_minimo, val_maximo, abreviatura, activo)
values
   ('USU_MOV_SERVICIO', 'Usuario UAPIIPS', 'UAPIIPS_8', 8, 'UAPIIPS', 'S');  
    
insert into it.ba_cod_referencias
   (dominio, significado, val_minimo, val_maximo, abreviatura, activo)
values
   ('USU_MOV_SERVICIO', 'Usuario UAPIIPS', 'UAPIIPS_9', 9, 'UAPIIPS', 'S');   
                     
commit; 
