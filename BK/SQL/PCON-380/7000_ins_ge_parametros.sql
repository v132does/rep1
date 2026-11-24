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
  ('COD_MOD_EXCLUIR',
   'MODALIDAD PARA EXCLUIR',
   'GE_PAR_DINAMICOS',
   null,
   user,
   sysdate,
   user,
   sysdate,
   'Se utiliza para excluir modalidades en el control de Deudor no verificado durante el proceso de desembolso',
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
  ('COD_MOD_EXCLUIR',
   'S',
   6,
   602,
   null,
   null,
   user,
   sysdate,
   user,
   sysdate,
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
  ('COD_MOD_EXCLUIR',
   'S',
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
