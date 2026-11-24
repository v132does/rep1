begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;  
/
insert into ge_parametros(parametro, descripcion, tab_relacion, observacion)
     values('CAR_CANCELACION','Cargo x Cancelacion','GE_CTA_DEF_ADICIONALES','Indica si se cobro el cargo en la cancelacion del CDA.'||chr(10)||chr(13)||
                                                     'Valores Posibles S/N  (Si/No)');
commit;
