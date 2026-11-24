insert into ba_consultas (COD_CONSULTA, DESCRIPCION, COD_USUARIO, TIPO, PERMISO, OBSERVACION, DET_SQL, FILTROS, COL_CORTES, COL_SUMAS, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('CD_PRE_CIE', 'Consulta control pre - cierre', null, 'G', null, 'Reporte de verificaciones previos al cierre operativo', 'select codigo, descripcion, observacion, clave, prioridad
    from gv_con_pre_cierre', null, null, null, 'IT', to_date('11-12-2024 13:59:47', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('11-12-2024 16:38:17', 'dd-mm-yyyy hh24:mi:ss'));

commit;