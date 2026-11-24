Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL)
values ('TIP_MON', 'Tipo Moneda', 'S', 1, 'V', null, null, 'CC_CHE_REMITIDOS', 'TIP_DATO', null, ' select  pag_gen.fu_obt_mon_local descripcion, ''1''  codigo  from dual
 union
 select pag_gen.fu_obt_mon_fuerte, ''2'' from dual', 'Ingrese moneda', 'R', 'N', 'N', 'S', 'S', 'N', 'N');

COMMIT;
