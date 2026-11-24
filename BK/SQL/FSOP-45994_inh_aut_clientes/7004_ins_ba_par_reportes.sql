BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('CLRECAUT', 'FEC_PROCES', 'a', null, 'F', 1, 'S', 'S', 'S');

insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('REC_ORIGEN', 'Origen Rechazo', 'S', 3, 'V', null, null, null, 'ORIGEN', null, 'SELECT ''Caja'',''C'' FROM dual
UNION
SELECT ''Pantalla'',''L'' FROM dual', 'Origen del Rechazo de Cheque.', 'R', 'N', 'N', 'S', 'N', 'N', null, null);

insert into ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('CLRECAUT', 'REC_ORIGEN', 'a', null, 'F', 2, 'S', 'S', 'N');

COMMIT;
