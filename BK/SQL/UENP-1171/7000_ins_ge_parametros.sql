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
  ('MTO_MAX_AUM_RECALCULO',
   'MONTO MAXIMO DE AUMENTO RECALCULO.',
   'GE_PAR_DINAMICOS',
   null,
   'IT',
   sysdate,
   'IT',
   sysdate,
   'Parametro creado para identificar en gs. el monto maximo de aumento al momento del recalculo de cargos en la solicitud de préstamos.',
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
  ('MTO_MAX_AUM_RECALCULO',
   '20',
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
