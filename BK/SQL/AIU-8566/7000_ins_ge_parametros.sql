begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('HAB_CTA_CDA_DESMATERIALIZADO', 'HAB. APR. CTA. CDA DESMATERIALIZADO', 'GE_PAR_DINAMICOS', 'Se utiliza para habilitar y deshabilitar el boton de apertura de cuenta del producto cda desmaterializado. (S-> Si, N-> No)',NULL);
commit;
