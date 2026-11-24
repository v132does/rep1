BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('GRU_ECO_CO', 'Grupo Economico', 'N', 3, 'V', null, null, null, 'COD_GRU_ECONOMICO', 13, 'Select to_char(a.cod_gru_economico)||''-''||TRIM(a.descripcion), to_char(a.cod_gru_economico) 
from ge_gru_economicos a
order by a.cod_gru_economico', user, sysdate, user, sysdate, 'Grupo Economico del Cliente', 'G', 'S', 'S', 'S', 'S', 'N', 'N', null);
commit;
