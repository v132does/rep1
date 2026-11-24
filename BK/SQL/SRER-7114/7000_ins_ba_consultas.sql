BEGIN  
  PRE_INI_APLICACION;  
  PAE_CNF.G_COD_MODULO := 1;  
END;
/
insert into ba_consultas (COD_CONSULTA, DESCRIPCION, TIPO, OBSERVACION, DET_SQL, FILTROS )
values ('CD_SOL_RUB', 'Solvencia Rubros', 'G', '', 'select Reporte, Clasificacion, RUBRO, DESCRIPCION, SECCION, Pais, ciudad, cod_moneda, ponderacion, orden, categoria, cod_rubro_rpt, ACTIVO, ACCION
from(select ''Banco Pais'' Reporte, '''' Clasificacion, RUBRO, DESCRIPCION, SECCION, '''' Pais,'''' ciudad, '''' cod_moneda, null ponderacion, null orden, '''' categoria, '''' cod_rubro_rpt, '''' ACTIVO, '''' ACCION
from it.cb_rubros_bco_pais
union all
select ''Banco Exterior'' Reporte, '''' Clasificacion, COD_RUBRO, DESCRIPCION, ''''SECCION, PAIS, CIUDAD, COD_MONEDA, null ponderacion, null orden, '''' categoria, '''' cod_rubro_rpt, '''' ACTIVO, '''' ACCION
        from IT.CB_RUBROS_BCO_EXTERIOR
union all
select ''Monto Contigencia'' Reporte, '''' Clasificacion, COD_RUBRO, DESCRIPCION, ''''SECCION, ''''PAIS, ''''CIUDAD, '''' COD_MONEDA,  PONDERACION,  ORDEN, '''' categoria, '''' cod_rubro_rpt, '''' ACTIVO, '''' ACCION
        from it.CB_MTO_CONTG_RUBROS
union all
        select ''Plantilla de Solvencia'' Reporte, CLASIFICACION, COD_RUBRO, DESCRIPCION, ''''SECCION, ''''PAIS, ''''CIUDAD, ''''COD_MONEDA, null PONDERACION, ORDEN, CATEGORIA, COD_RUBRO_RTP, '''' ACTIVO, '''' ACCION
         from IT.SB_SOL_CONFIGURACIONES 
union all 
    select ''Pratimonio Efectivo'' Reporte, '''' CLASIFICACION, COD_RUBRO , DESCRIPCION, SECCION, ''''PAIS, ''''CIUDAD, ''''COD_MONEDA, null PONDERACION, null ORDEN, ''''CATEGORIA, ''''COD_RUBRO_RTP, ACTIVO, '''' ACCION
    from IT.TMP_COD_RUBRO_FILTRO
    )
    order by reporte, orden', '');

COMMIT;
