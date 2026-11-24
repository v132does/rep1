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
  ('COD_MAD_PRESTAMOS',
   'MODALIDADES PRESTAMOS',
   'GE_PAR_DINAMICOS',
   null,
   'IT',
   sysdate,
   'IT',
   sysdate,
   'Parametro creado para identificar modalidades utilizadas en la funcion fup_ver_cal_interes.',
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
  ('COD_MAD_PRESTAMOS',
   ',602,668,663,',
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
