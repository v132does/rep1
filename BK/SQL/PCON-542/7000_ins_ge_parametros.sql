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
  ('COD_MOD_SUM_CARGO',
   'MODALIDAD SUMA CARGO',
   'GE_PAR_DINAMICOS',
   null,
   user,
   sysdate,
   user,
   sysdate,
   'Se utiliza para identificar las modalidades con TX 703 que deben sumar el cargo en PMDESEMB.',
   null,
   null,
   null,
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
  ('COD_MOD_SUM_CARGO',
   'S',
   6,
   645,
   null,
   null,
   user,
   sysdate,
   user,
   sysdate,
   null);

commit;
