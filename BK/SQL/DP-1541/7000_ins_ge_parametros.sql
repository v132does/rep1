Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
-- 1
insert into ge_parametros
  (parametro, descripcion, tab_relacion, observacion)
values
  ('FEC_INI_NUE_TAE',
   'FECHA INICIO NUEVO CALCULO TAE',
   'GE_PAR_DINAMICOS',
   'Se utiliza para identificar la fecha de implementacion del calculo de la nueva formula TAE utilizada en el pas_bcp');

insert into ge_par_dinamicos
  (parametro, val_parametro)
values
  ('FEC_INI_NUE_TAE', TO_CHAR(TRUNC(SYSDATE), 'DD/MM/YYYY'));

commit;
-- 2
insert into ge_parametros
  (parametro, descripcion, tab_relacion, observacion)
values
  ('COD_MOD_DES_DOC',
   'CODIGO DE MODALIDADES DESC DOCU',
   'GE_PAR_DINAMICOS',
   'Se utiliza para identificar las modalidades de descuento de documentos, tiene un calculo espececial en la formula TAE utilizada en el pas_bcp');

insert into ge_par_dinamicos
  (parametro, val_parametro,cod_modulo, cod_modalidad)
values
  ('COD_MOD_DES_DOC', 608,6,608);
  
insert into ge_par_dinamicos
  (parametro, val_parametro,cod_modulo, cod_modalidad)
values
  ('COD_MOD_DES_DOC', 62,6,62);

commit;
