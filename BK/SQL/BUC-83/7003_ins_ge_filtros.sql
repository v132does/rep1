begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('BLO_FEC', 'Fecha de Bloqueo', 'F', 10, 'R', null, null, null, 'fec_bloqueo', null, null, 'Ingrese la fecha de inicio del bloqueo,', 'G', 'N', 'S', 'S', 'S', 'N', null, null);

commit;
