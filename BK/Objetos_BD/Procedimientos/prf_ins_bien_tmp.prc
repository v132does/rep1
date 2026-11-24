CREATE OR REPLACE PROCEDURE IT.PRF_INS_BIEN_TMP(p_cod_bien af_bienes_tmp.cod_bien%TYPE) IS
BEGIN
   INSERT INTO af_bienes_tmp
      (cod_bien, cod_articulo, descripcion, cod_oficina, cod_area, nro_serie, val_compra,
       cod_moneda, fec_compra, cod_ent_proveedor, nro_factura, tipo, coeficiente,
       fec_vto_depreciacion, rev_anterior, rev_actual, dep_anterior, dep_anual, dep_mensual,
       rev_depreciacion, dep_actual, dep_acumulada, val_neto, fec_proceso, tip_proceso, estado,
       fec_enajenacion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
       dep_mensual_normal, rev_ano_anterior, rev_ano_acumulado, dep_ano_acu_anterior,
       por_val_res_bien, por_val_dep_bien)
      SELECT cod_bien,
             cod_articulo,
             descripcion,
             cod_oficina,
             cod_area,
             nro_serie,
             val_compra,
             cod_moneda,
             fec_compra,
             cod_ent_proveedor,
             nro_factura,
             tipo,
             coeficiente,
             fec_vto_depreciacion,
             rev_anterior,
             rev_actual,
             dep_anterior,
             dep_anual,
             dep_mensual,
             rev_depreciacion,
             0 dep_actual,
             dep_acumulada,
             val_neto,
             fec_proceso,
             tip_proceso,
             estado,
             fec_enajenacion,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             dep_mensual_normal,
             rev_ano_anterior,
             rev_ano_acumulado,
             dep_ano_acu_anterior,
             por_val_res_bien,
             por_val_dep_bien
        FROM af_bienes
       WHERE cod_bien = p_cod_bien;
END;
/

