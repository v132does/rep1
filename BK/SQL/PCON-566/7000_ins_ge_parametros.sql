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
  ('COD_MOD_SUM_DIF',
   'MODALIDAD SUMA DIFERENCIADA',
   'GE_PAR_DINAMICOS',
   null,
   user,
   sysdate,
   user,
   sysdate,
   'Se utiliza para identificar las modalidades que debe sumar los cargos de forma diferenciada en exposicion de cuotas',
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
  ('COD_MOD_SUM_DIF',
   '668',
   6,
   668,
   null,
   null,
   user,
   sysdate,
   user,
   sysdate,
   null);

commit;
