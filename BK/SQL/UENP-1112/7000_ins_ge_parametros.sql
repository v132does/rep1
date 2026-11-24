begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros
  (parametro,
   descripcion,
   tab_relacion,
   referencia,
   usu_insercion,
   fec_insercion,
   usu_modificacion,
   fec_modificacion,
   observacion,
   pro_verificacion,
   permiso,
   modificable,
   val_defecto)
values
  ('COD_CAR_SEGUROS',
   'CODIGOS DE CARGOS DE SEGUROS SOLIC.',
   'GE_PAR_DINAMICOS',
   null,
   'IT',
   sysdate,
   'IT',
   sysdate,
   'Parametro creado para identificar los cargos de seguros utilizados en la creacion de solicitudes.',
   null,
   null,
   'N',
   null);
 
commit;


insert into ge_par_dinamicos
  (parametro,
   val_parametro,
   cod_modulo,
   cod_modalidad,
   cod_oficina,
   cod_moneda,
   usu_insercion,
   fec_insercion,
   usu_modificacion,
   fec_modificacion,
   cod_sub_modalidad)
values
  ('COD_CAR_SEGUROS',
   ',736,1270,1521,',
   null,
   null,
   null,
   null,
   'IT',
   sysdate,
   'IT',
   sysdate,
   null);
   
commit;
