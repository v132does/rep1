begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ba_tab_def_adicionales (TAB_RELACION, PARAMETRO, ETIQUETA, TIP_CAMPO, TIP_DATO, OBLIGATORIO, MODIFICABLE, VAL_DEFECTO, LON_MAXIMA, REFERENCIA, OBSERVACION, TIPO, NRO_ORDEN)
values ('CC_CHE_DEVUELTOS', 'COD_CAU_SECUNDARIA', 'COD_CAU_SECUNDARIA', 'T', 'A', 'N', 'S', null, 200, null, null, '2,3,4,5,7', 1);

commit;
