BEGIN    PRE_INI_APLICACION;    PAE_CNF.G_COD_MODULO := 1; END;
/    
INSERT INTO BA_CONSULTAS (COD_CONSULTA,DESCRIPCION,COD_USUARIO,TIPO,PERMISO,OBSERVACION,DET_SQL,FILTROS,COL_CORTES,COL_SUMAS)
VALUES ('PRO320AUT','Ejecucion Automatica FIN DE DIA CONTABLE',user,'G',NULL,'',
     q'[SELECT fecha, det_error detalle
        FROM ge_log_errores
        WHERE cod_programa = 'PRB_EJE_PRO_320_AUTOMATICO'
        AND fec_insercion > TRUNC(SYSDATE)
        ORDER BY fec_insercion]',
		'',       -- FILTROS
		NULL,     -- COL_CORTES
		NULL      -- COL_SUMAS
);
COMMIT;
