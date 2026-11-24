begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
/
--
insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('NRO_REFE', 'Nro. Referencia', 'S', 30, 'R', null, null, null, 'NRO_REFERENCIA', null, null, 'RBARRIOS', to_date('28-12-2023 09:49:03', 'dd-mm-yyyy hh24:mi:ss'), 'RBARRIOS', to_date('28-12-2023 09:50:52', 'dd-mm-yyyy hh24:mi:ss'), null, 'G', 'N', 'S', 'S', 'S', 'N', null, null);

commit;
/