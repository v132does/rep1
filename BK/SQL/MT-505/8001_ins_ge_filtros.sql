BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('ESTADO_CH', 'Estado de Cheque', 'S', 1, 'V', null, null, null, 'EST_CHEQUE', null, 'select  ''Ingresado TED'', ''I''  from dual  union
select  ''Depositado caja'', ''D''  from dual union   
select ''Rechazado caja'', ''R'' from dual union 
select  ''No ingresado al sistema'', ''N''  from dual', 'IT', to_date('08-01-2025 15:53:14', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('08-01-2025 16:12:31', 'dd-mm-yyyy hh24:mi:ss'), 'Tipos de Planillas de Envio', 'G', 'S', 'S', 'S', 'S', 'S', 'N', null);

commit;