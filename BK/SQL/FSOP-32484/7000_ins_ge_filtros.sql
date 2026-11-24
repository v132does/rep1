begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('TIPO_COBRP', 'Tipo de Cobro', 'S', 1, 'V', null, null, null, 'TIPO_COBRO', null, '
SELECT ''POR CLEARING'' descripcion, ''1'' codigo from dual union
select ''POR CAJA'', ''2'' from dual', null, 'G', 'N', 'S', 'S', 'S', 'N', 'N', null);
/
commit;
