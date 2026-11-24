begin
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
end;
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
  ('COD_MOD_TOT_SEG_VID',
   'MODALIDADES CALCULO SEG 1521.',
   'GE_PAR_DINAMICOS',
   null,
   user,
   sysdate,
   user,
   sysdate,
   'Parametro para identificar modalidades que utilizan calculo diferenciado en el EPPROCOR para seguro 1521.',
   null,
   null,
   'N',
   null);

commit;
