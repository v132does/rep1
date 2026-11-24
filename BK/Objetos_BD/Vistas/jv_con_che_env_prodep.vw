CREATE OR REPLACE FORCE VIEW IT.JV_CON_CHE_ENV_PRODEP AS
SELECT i.fecha,
         i.nro_referencia ref_prodep,
         i.nro_documento nro_boleta,
         i.cod_oficina,
         i.nro_caja,
         i.cod_usuario,
         '24HS' retencion,
         i.nro_cuenta,
         i.cod_moneda,
         nvl(i.monto, 0) mto_itgf,
         nvl(t.monto, 0) mto_prodep,
         case when nvl(i.monto, 0) <> nvl(t.monto, 0) then 'S' else 'N' end con_diferencia,
         'N' post_corte,
         '1 - Dep. ingresados en ITGF' descripcion
    FROM cj_mov_prodep i, ( SELECT t.nro_boleta, SUM(t.monto) monto
                              FROM cc_che_remitidos_tmp t
                             GROUP BY t.nro_boleta ) t
   WHERE i.fecha = pag_cal.fu_obt_fec_actual(4)
     AND i.tip_monto IN ('O', 'T')
     AND i.estado <> 'R'
     AND i.nro_referencia = t.nro_boleta(+)
 UNION ALL
  SELECT i.fecha,
         i.nro_referencia ref_prodep,
         i.nro_documento nro_boleta,
         i.cod_oficina,
         i.nro_caja,
         i.cod_usuario,
         '24HS' retencion,
         i.nro_cuenta,
         i.cod_moneda,
         nvl(i.monto, 0) mto_itgf,
         nvl(t.monto, 0) mto_prodep,
         case when nvl(i.monto, 0) <> nvl(t.monto, 0) then 'S' else 'N' end con_diferencia,
         'N' post_corte,
         '1 - Dep. ingresados en ITGF' descripcion
    FROM cj_mov_prodep i, ( SELECT t.nro_boleta, SUM(t.monto) monto
                              FROM cc_che_remitidos_tmp t
                             GROUP BY t.nro_boleta ) t
   WHERE i.fecha = pag_cal.fu_obt_fec_anterior(4)
     AND i.tip_monto = 'S'
     AND i.estado <> 'R'
     AND i.nro_referencia = t.nro_boleta(+)
 UNION ALL
  SELECT i.fecha,
         i.nro_referencia ref_prodep,
         i.nro_documento nro_boleta,
         i.cod_oficina,
         i.nro_caja,
         i.cod_usuario,
         '48HS' retencion,
         i.nro_cuenta,
         i.cod_moneda,
         nvl(i.monto, 0) mto_itgf,
         nvl(t.monto, 0) mto_prodep,
         case when nvl(i.monto, 0) <> nvl(t.monto, 0) then 'S' else 'N' end con_diferencia,
         'S' post_corte,
         '1 - Dep. ingresados en ITGF' descripcion
    FROM cj_mov_prodep i, ( SELECT t.nro_boleta, SUM(t.monto) monto
                              FROM cc_che_remitidos_tmp t
                             GROUP BY t.nro_boleta ) t
   WHERE i.fecha = pag_cal.fu_obt_fec_actual(4)
     AND i.tip_monto = 'S'
     AND i.estado <> 'R'
     AND i.nro_referencia = t.nro_boleta(+)
 UNION ALL
  SELECT i.fecha,
         i.nro_boleta ref_prodep,
         t.nro_documento nro_boleta,
         i.cod_oficina,
         i.nro_caja,
         i.usu_captura,
         '24HS' retencion,
         i.nro_referencia,
         decode(i.tip_dato, 2, pag_gen.fu_obt_mon_fuerte, pag_gen.fu_obt_mon_local) cod_moneda,
         nvl(t.monto, 0) mto_itgf,
         nvl(sum(i.monto), 0) mto_prodep,
         case when nvl(sum(i.monto), 0) <> nvl(t.monto, 0) then 'S' else 'N' end con_diferencia,
         'N' post_corte,
         '2 - Dep. ingresados en Prodep' descripcion
    FROM cc_che_remitidos_tmp i, ( SELECT t.*
                                     FROM cj_mov_prodep t
                                    WHERE t.fecha = pag_cal.fu_obt_fec_actual(4)
                                      AND t.tip_monto IN ('O', 'T')
                                      AND t.estado <> 'R'
                                    UNION
                                   SELECT t.*
                                     FROM cj_mov_prodep t
                                    WHERE t.fecha = pag_cal.fu_obt_fec_anterior(4)
                                      AND t.tip_monto = 'S'
                                      AND t.estado <> 'R' ) t
   WHERE i.nro_boleta = t.nro_referencia(+)
     AND i.fecha = pag_cal.fu_obt_fec_actual(4)
   GROUP BY i.fecha, i.nro_boleta, t.nro_documento, i.cod_oficina, i.nro_caja, i.usu_captura,
            i.retencion, i.nro_referencia, i.tip_dato, t.monto
 UNION ALL
  SELECT i.fecha,
         i.nro_boleta ref_prodep,
         t.nro_documento nro_boleta,
         i.cod_oficina,
         i.nro_caja,
         i.usu_captura,
         '48HS' retencion,
         i.nro_referencia,
         decode(i.tip_dato, 2, pag_gen.fu_obt_mon_fuerte, pag_gen.fu_obt_mon_local) cod_moneda,
         nvl(t.monto, 0) mto_itgf,
         nvl(sum(i.monto), 0) mto_prodep,
         case when nvl(sum(i.monto), 0) <> nvl(t.monto, 0) then 'S' else 'N' end con_diferencia,
         'S' post_corte,
         '2 - Dep. ingresados en Prodep' descripcion
    FROM cc_che_remitidos_tmp i, ( SELECT t.*
                                     FROM cj_mov_prodep t
                                    WHERE t.fecha = pag_cal.fu_obt_fec_actual(4)
                                      AND t.tip_monto = 'S'
                                      AND t.estado <> 'R' ) t
   WHERE i.fecha > pag_cal.fu_obt_fec_actual(4)
     AND i.nro_boleta = t.nro_referencia(+)
   GROUP BY i.fecha, i.nro_boleta, t.nro_documento, i.cod_oficina, i.nro_caja, i.usu_captura,
            i.retencion, i.nro_referencia, i.tip_dato, t.monto
 ORDER BY 14, 1, 4, 5;

