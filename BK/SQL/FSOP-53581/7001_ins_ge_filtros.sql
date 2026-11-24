BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

INSERT INTO ge_filtros 
            (COD_CAMPO,
            DESCRIPCION,
            TIP_CAMPO,
            LON_CAMPO,
            TIP_DATO,
            NOM_TAB_ASOCIADA,
            NOM_REFERENCIA,
            OBSERVACION,
            AFE_CONSULTAS)
values('FE_FEC_LOG',
       'Filtro de fecha de inserción para GE_LOG_ERRORES',
       'F',
       20,
       'R',
       'GE_LOG_ERRORES',
       'TRUNC(FEC_INSERCION)',
       'El valor se usa para filtrar que dias traer de la tabla de LOG',
       'S');

INSERT INTO ge_filtros 
            (COD_CAMPO,
            DESCRIPCION,
            TIP_CAMPO,
            LON_CAMPO,
            TIP_DATO,
            NOM_TAB_ASOCIADA,
            NOM_REFERENCIA,
            OBSERVACION,
            AFE_CONSULTAS)
values('FE_FEC_REC',
       'Filtro de fecha de modificación de CB_DOC_ELEC_CAB',
       'F',
       20,
       'R',
       'CB_LIB_VENTAS',
       'FECHA',
       'El valor se usa para filtrar los comprobantes modificados en esta fecha',
       'S'); 

commit;
