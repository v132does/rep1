Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros
  (parametro, descripcion, tab_relacion, observacion)
values
  ('POR_TOP_GAS_ADM',
   'PORCENTAJE TOPE CALCULO TAN TAE',
   'GE_PAR_DINAMICOS',
   'Tope de gastos administrativos que no se consideran interés a los efectos de calculo de TAN y TAE de creditos de hasta 25 salarios mínimos mensuales, valor de 25% del monto desembolsado. (antes era 15%)');

insert into ge_par_dinamicos
  (parametro, val_parametro)
values
  ('POR_TOP_GAS_ADM', '25');

commit;
