begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/

insert into ge_parametros
  (parametro,
   descripcion,
   tab_relacion,
   referencia,
   observacion,
   pro_verificacion,
   permiso,
   usu_insercion,
   fec_insercion,
   usu_modificacion,
   fec_modificacion)
values
  ('COD_RUB_CHE_ROGA',
   'RUBRO ECONOMICO CHE ROGA.',
   'GE_PAR_DINAMICOS',
   null,
   'CODIGO DE RUBRO ECONOMICO CHE ROGA.',
   null,
   null,
   user,
   sysdate,
   user,
   sysdate);
commit;

insert into ge_parametros
  (parametro,
   descripcion,
   tab_relacion,
   referencia,
   observacion,
   pro_verificacion,
   permiso,
   usu_insercion,
   fec_insercion,
   usu_modificacion,
   fec_modificacion)
values
  ('COD_MOD_CHE_ROGA',
   'MODALIDAD CHE ROGA.',
   'GE_PAR_DINAMICOS',
   null,
   'CODIGO DE MODALIDAD CHE ROGA.',
   null,
   null,
   user,
   sysdate,
   user,
   sysdate);
commit;
insert into ge_parametros
  (parametro,
   descripcion,
   tab_relacion,
   referencia,
   observacion,
   pro_verificacion,
   permiso,
   usu_insercion,
   fec_insercion,
   usu_modificacion,
   fec_modificacion)
values
  ('DIR_MAIL_OPERATIVO',
   'MAIL DEL OPERATIVO CHE ROGA.',
   'GE_PAR_DINAMICOS',
   null,
   'EMAIL DESTINO DE GENERACION OFERTA CHE ROGA.',
   null,
   null,
   user,
   sysdate,
   user,
   sysdate);
commit;   

insert into ge_parametros
  (parametro,
   descripcion,
   tab_relacion,
   referencia,
   observacion,
   pro_verificacion,
   permiso,
   usu_insercion,
   fec_insercion,
   usu_modificacion,
   fec_modificacion)
values
  ('PRE_COD_CAU_CHE_ROGA',
   'COD. CAUSA BLOQ. SALDO CHE-ROG.',
   'GE_PAR_DINAMICOS',
   null,
   'Parametro de causa para el bloqueo de saldo de prestamos cheroga.',
   null,
   null,
   user,
   sysdate,
   user,
   sysdate);

commit;
 

