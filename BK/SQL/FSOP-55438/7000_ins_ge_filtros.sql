Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('NUM_DOC_CL', 'Nro. Documento Cliente', 'S', 40, 'R', null, null, null, 'NRO_DOC_CLIENTE', null, null, 'G', 'N', 'N', 'S', 'S', 'N', null, null);

commit;
