begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/

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
  ('SIG_NROCTA',
   '66300000',
   6,
   663,
   null,
   null,
   user,
   sysdate,
   user,
   sysdate,
   null);

commit;
