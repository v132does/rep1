begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into it.ge_parametros
  (parametro, descripcion, tab_relacion, referencia, observacion, modificable )
values
  ('MAX_CAN_LIN_ARC_MT940','MAX CANT. LINEAS POR ARCHIVO MT940', 'GE_PAR_DINAMICOS', NULL, 'Canitdad maxima de Lineas por archivo de tipo MT940','N');
commit;
