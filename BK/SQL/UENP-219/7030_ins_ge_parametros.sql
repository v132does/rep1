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
  ('WBS_URL_INT_CHE_ROGA',
   'ENVIA DATOS A WS DESDE WF',
   'GE_PAR_DINAMICOS',
   null,
   'Indica el url del servicio de banner',
   null,
   null,
   user,
   sysdate,
   user,
   sysdate);

commit;
