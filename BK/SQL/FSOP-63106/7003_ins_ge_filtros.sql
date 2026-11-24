Begin 
  dbms_session.set_identifier('FSOP-63106');
  pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
end; 
/
insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('TIP_CAUSA', 'Tipo de Causal', 'S', 20, 'V', null, null, null, 'tipo', null, 'select significado, val_minimo
from ba_cod_referencias
where dominio = ''TIP_CAUSA''
order by val_minimo', null, 'G', 'N', 'N', 'N', 'S', 'N', 'N', null);

commit;
