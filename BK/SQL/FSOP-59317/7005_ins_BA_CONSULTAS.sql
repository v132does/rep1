BEGIN    PRE_INI_APLICACION;    PAE_CNF.G_COD_MODULO := 1; END;
/    
INSERT INTO BA_CONSULTAS (COD_CONSULTA,DESCRIPCION,COD_USUARIO,TIPO,PERMISO,OBSERVACION,DET_SQL,FILTROS,COL_CORTES,COL_SUMAS)
VALUES ('FACMASIVAS','FACTURAS Y NC MASIVAS',user,'P',NULL,'',
     'SELECT b.nro_factura, b.nro_timbrado, b.fecha, b.cod_oficina, b.tip_comprobante, b.tip_venta, b.cod_moneda, b.cod_persona, b.nom_completo, b.nro_documento, b.nro_fac_referencia, 
            c.mto_exento, c.mto_exento_gs, c.mto_gravado_5, c.mto_gra_5_gs, c.mto_gravado_10, c.mto_gra_10_gs, c.impuesto_5, c.impuesto_5_gs, c.impuesto_10, c.impuesto_10_gs
    FROM cb_fac_masivas_his a, cb_lib_ventas b, cb_lib_ventas_det c 
    WHERE a.nro_factura = b.nro_factura
     AND a.fec_factura = b.fecha
     AND a.tip_comprobante = b.tip_comprobante
      AND b.nro_factura = c.nro_factura
      AND b.fecha = c.fecha
      AND c.tip_comprobante = c.tip_comprobante 
      AND (' || CHR(38) || 'P_FILTROS)
      ORDER BY c.nro_factura, c.tip_comprobante, c.fecha, c.nro_secuencia',
		'',       -- FILTROS
		NULL,     -- COL_CORTES
		NULL      -- COL_SUMAS
);
INSERT INTO BA_CONSULTAS (COD_CONSULTA, DESCRIPCION, COD_USUARIO, TIPO, PERMISO, OBSERVACION, DET_SQL, FILTROS, COL_CORTES, COL_SUMAS)
VALUES ('FACMERROR', 'FACTURAS Y NC MASIVAS CON ERROR', user, 'P', NULL, '', 'SELECT cod_programa, det_error, usu_insercion, fecha FROM ge_log_errores a WHERE cod_programa = ''PRB_FAC_MASIVAS'' AND (' || CHR(38) || 'P_FILTROS)', '', NULL, NULL);
COMMIT;
