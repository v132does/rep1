CREATE OR REPLACE FORCE VIEW IT.GV_OPE_CAM_DATATEC AS
SELECT 'D' tip_informe, gv_movimientos.fecha,
       ful_cli_ope_cambios(cliente.cod_persona, gv_movimientos.monto, gv_movimientos.cod_moneda,
                           gv_movimientos.fecha,
                            --
                           'N',
                            --
                           gv_movimientos.cod_mad_padre) cla_operacion,
       nvl(cliente.nombre, '-') nombre,
       cliente.cod_persona,
       cliente.nro_doc,
       lc_tip_operaciones.descripcion tip_operacion,
       gv_movimientos.cod_mad_padre,
       gv_movimientos.cod_moneda,
       decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte, gv_movimientos.cotizacion,
              fug_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)) cotizacion,
       (decode(gv_movimientos.cod_mad_padre, 71,
               pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                            nvl(gv_movimientos.monto, 0), gv_movimientos.cotizacion)
                -- SDC le paso la cotizacion
              , 0)) +
       (decode(gv_movimientos.cod_mad_padre, 73,
                -- ARBITRAJE
               decode(gv_movimientos.nro_secuencia, 1,
                       pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                                    nvl(gv_movimientos.monto, 0),
                                                    gv_movimientos.cotizacion)
                        -- SDC le paso la cotizacion
                      , 0), 74,
                -- CANJE
               decode(gv_movimientos.nro_secuencia, 1,
                       pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                                    nvl(gv_movimientos.monto, 0),
                                                    gv_movimientos.cotizacion)
                        -- SDC le paso la cotizacion
                      , 0), 0)) mto_compra,
       (decode(gv_movimientos.cod_mad_padre, 72,
               pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                            nvl(gv_movimientos.monto, 0), gv_movimientos.cotizacion)
                -- SDC le paso la cotizacion
              , 0)) +
       (decode(gv_movimientos.cod_mad_padre, 73,
                -- ARBITRAJE
               decode(gv_movimientos.nro_secuencia, 2,
                       pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                                    nvl(gv_movimientos.monto, 0),
                                                    gv_movimientos.cotizacion)
                        -- SDC le paso la cotizacion
                      , 0), 74,
                -- CANJE
               decode(gv_movimientos.nro_secuencia, 2,
                       pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                                    nvl(gv_movimientos.monto, 0),
                                                    gv_movimientos.cotizacion)
                        -- SDC le paso la cotizacion
                      , 0), 0)) mto_venta,
       (decode(gv_movimientos.cod_mad_padre, 71,
               decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte, gv_movimientos.cotizacion,
                       fug_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)), 73,
                -- ARBITRAJE
               decode(gv_movimientos.nro_secuencia, 1,
                       decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                               gv_movimientos.cotizacion,
                               pag_gen.fu_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)), 0), 74,
                -- CANJE
               decode(gv_movimientos.nro_secuencia, 1,
                       decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                               gv_movimientos.cotizacion,
                               pag_gen.fu_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)), 0), 0)) tot_cot_compra,
       (decode(gv_movimientos.cod_mad_padre, 71, 1, 73,
               decode(gv_movimientos.nro_secuencia, 1, 1, 0), 74,
               decode(gv_movimientos.nro_secuencia, 1, 1, 0), 0)) ind_cot_compra,
       (decode(gv_movimientos.cod_mad_padre, 72,
               decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte, gv_movimientos.cotizacion,
                       pag_gen.fu_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)), 73,
                -- ARBITRAJE
               decode(gv_movimientos.nro_secuencia, 2,
                       decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                               gv_movimientos.cotizacion, fug_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)),
                       0), 74,
                -- ARBITRAJE
               decode(gv_movimientos.nro_secuencia, 2,
                       decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                               gv_movimientos.cotizacion, fug_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)),
                       0), 0)) tot_cot_venta,
       (decode(gv_movimientos.cod_mad_padre, 72, 1, 73,
               decode(gv_movimientos.nro_secuencia, 2, 1, 0), 74,
               decode(gv_movimientos.nro_secuencia, 2, 1, 0), 0)) ind_cot_venta,
       cliente.cod_ofi_cliente,
       oc.descripcion ofi_cliente,
       cc.descripcion ciu_cliente,
       gv_movimientos.cod_ofi_origen,
       oo.descripcion ofi_origen,
       co.descripcion ciu_origen
  FROM ba_monedas,
       ge_movimientos gv_movimientos,
       lc_tip_operaciones,
       (SELECT gv_movimientos.nro_documento,
               gv_movimientos.nro_documento2 nro_doc,
               gv_movimientos.fecha,
               gv_movimientos.hora,
               gv_movimientos.cod_usuario,
               ba_personas.cod_persona,
               nvl(ba_personas.nom_completo, gv_movimientos.concepto) nombre,
               c.cod_oficina cod_ofi_cliente
          FROM ba_personas, ge_clientes c, ge_movimientos gv_movimientos
         WHERE to_char(gv_movimientos.nro_documento2) = ba_personas.cod_persona(+)
           AND c.cod_persona(+) = ba_personas.cod_persona
           AND gv_movimientos.cod_transaccion = 760
           AND gv_movimientos.cod_mod_padre = 7
           AND gv_movimientos.reversado = 'N') cliente,
       ba_oficinas oo,
       ba_oficinas oc,
       ba_ciudades co,
       ba_ciudades cc
 WHERE ba_monedas.cod_moneda = gv_movimientos.cod_moneda
   AND ((gv_movimientos.cod_mad_padre IN (71, 72) AND gv_movimientos.nro_secuencia = 1 AND gv_movimientos.cod_ref_cambio <> 76) OR
       (gv_movimientos.cod_mad_padre IN (73) AND gv_movimientos.nro_secuencia IN (1, 2)))
   AND gv_movimientos.monto IS NOT NULL
   AND gv_movimientos.cotizacion IS NOT NULL
   AND gv_movimientos.mto_equ_local IS NOT NULL
   AND cliente.fecha(+) = gv_movimientos.fecha
   AND cliente.cod_usuario(+) = gv_movimientos.cod_usuario
   AND cliente.hora(+) = gv_movimientos.hora
   AND gv_movimientos.reversado = 'N'
   AND gv_movimientos.cod_tip_ope_cambio = lc_tip_operaciones.cod_tip_operacion
   AND afe_posicion IN ('E', 'O')
   AND oc.cod_oficina(+) = cliente.cod_ofi_cliente
   AND oo.cod_oficina(+) = gv_movimientos.cod_ofi_origen
   AND cc.cod_pais(+) = oc.cod_pais
   AND cc.cod_ciudad(+) = oc.cod_ciudad
   AND co.cod_pais(+) = oo.cod_pais
   AND co.cod_ciudad(+) = oo.cod_ciudad
union all -- Operaciones Futuras
SELECT 'D' tip_informe, gv_movimientos.fecha,
       ful_cli_ope_cambios(cliente.cod_persona, gv_movimientos.monto, gv_movimientos.cod_moneda,
                           gv_movimientos.fecha,
                            --
                           'N',
                            --
                           gv_movimientos.cod_mad_padre) cla_operacion,
       nvl(cliente.nombre, '-') nombre,
       cliente.cod_persona,
       cliente.nro_doc,
       lc_tip_operaciones.descripcion tip_operacion,
       gv_movimientos.cod_mad_padre,
       gv_movimientos.cod_moneda,
       decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte, gv_movimientos.cotizacion,
              fug_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)) cotizacion,
       (decode(gv_movimientos.cod_modalidad, 71,
               pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                            nvl(gv_movimientos.monto, 0), gv_movimientos.cotizacion), 0)) mto_compra,
       (decode(gv_movimientos.cod_modalidad, 72,
               pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                            nvl(gv_movimientos.monto, 0), gv_movimientos.cotizacion), 0)) mto_venta,
       (decode(gv_movimientos.cod_modalidad, 71,
               decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte, gv_movimientos.cotizacion,
                       fug_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)), 0)) tot_cot_compra,
       (decode(gv_movimientos.cod_modalidad, 71, 1, 0)) ind_cot_compra,
       (decode(gv_movimientos.cod_modalidad, 72,
               decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte, gv_movimientos.cotizacion,
                       pag_gen.fu_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)), 0)) tot_cot_venta,
       (decode(gv_movimientos.cod_modalidad, 72, 1, 0)) ind_cot_venta,
       cliente.cod_ofi_cliente,
       oc.descripcion ofi_cliente,
       cc.descripcion ciu_cliente,
       gv_movimientos.cod_ofi_origen,
       oo.descripcion ofi_origen,
       co.descripcion ciu_origen
  FROM ba_monedas,
       ge_movimientos gv_movimientos,
       lc_tip_operaciones,
       (SELECT gv_movimientos.nro_documento,
               gv_movimientos.nro_documento2 nro_doc,
               gv_movimientos.fecha,
               gv_movimientos.hora,
               gv_movimientos.cod_usuario,
               ba_personas.cod_persona,
               nvl(ba_personas.nom_completo, gv_movimientos.concepto) nombre,
               c.cod_oficina cod_ofi_cliente
          FROM ba_personas, ge_clientes c, ge_movimientos gv_movimientos
         WHERE to_char(gv_movimientos.cod_persona) = ba_personas.cod_persona(+)
           AND c.cod_persona(+) = ba_personas.cod_persona
           AND gv_movimientos.cod_transaccion = 760
           AND gv_movimientos.cod_mod_padre = 7
           AND gv_movimientos.cod_mad_padre = 76
           AND gv_movimientos.reversado = 'N') cliente,
       ba_oficinas oo,
       ba_oficinas oc,
       ba_ciudades co,
       ba_ciudades cc
 WHERE ba_monedas.cod_moneda = gv_movimientos.cod_moneda
   AND gv_movimientos.cod_mad_padre = 76
   AND gv_movimientos.nro_secuencia = 1
   AND gv_movimientos.monto IS NOT NULL
   AND gv_movimientos.cotizacion IS NOT NULL
   AND gv_movimientos.mto_equ_local IS NOT NULL
   AND cliente.fecha(+) = gv_movimientos.fecha
   AND cliente.cod_usuario(+) = gv_movimientos.cod_usuario
   AND cliente.hora(+) = gv_movimientos.hora
   AND gv_movimientos.reversado = 'N'
   AND gv_movimientos.cod_tip_ope_cambio = lc_tip_operaciones.cod_tip_operacion
   AND oc.cod_oficina(+) = cliente.cod_ofi_cliente
   AND oo.cod_oficina(+) = gv_movimientos.cod_ofi_origen
   AND cc.cod_pais(+) = oc.cod_pais
   AND cc.cod_ciudad(+) = oc.cod_ciudad
   AND co.cod_pais(+) = oo.cod_pais
   AND co.cod_ciudad(+) = oo.cod_ciudad
union all
 SELECT r.tip_informe, r.fecha, r.cla_operacion, '-' nombre, '-' cod_persona, 0 nro_doc, '-' tip_operacion, 0 cod_mad_padre, '-' cod_moneda,
        0 cotizacion, sum(r.mto_compra) mto_compra, sum(r.mto_venta) mto_venta,
        case when sum(r.ind_cot_compra) = 0 then 0 else
                  round(sum(r.tot_cot_compra)/sum(r.ind_cot_compra), 2) end tot_cot_compra,
        sum(r.ind_cot_compra) ind_cot_compra,
        case when sum(r.ind_cot_venta) = 0 then 0 else
                  round(sum(r.tot_cot_venta)/sum(r.ind_cot_venta), 2) end tot_cot_venta,
        sum(r.ind_cot_venta) ind_cot_venta,
        0 cod_ofi_cliente, '-' ofi_cliente, '-' ciu_cliente, 0 cod_ofi_origen, '-' ofi_origen, r.ciu_origen
 FROM (
 SELECT 'C' tip_informe, gv_movimientos.fecha,
       ful_cli_ope_cambios(cliente.cod_persona, gv_movimientos.monto, gv_movimientos.cod_moneda,
                           gv_movimientos.fecha,
                            --
                           'N',
                            --
                           gv_movimientos.cod_mad_padre) cla_operacion,
       nvl(cliente.nombre, '-') nombre,
       cliente.cod_persona,
       cliente.nro_doc,
       lc_tip_operaciones.descripcion tip_operacion,
       gv_movimientos.cod_mad_padre,
       gv_movimientos.cod_moneda,
       decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte, gv_movimientos.cotizacion,
              fug_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)) cotizacion,
       (decode(gv_movimientos.cod_mad_padre, 71,
               pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                            nvl(gv_movimientos.monto, 0), gv_movimientos.cotizacion)
                -- SDC le paso la cotizacion
              , 0)) +
       --OPERACION FUTURA
       (decode(gv_movimientos.cod_mad_padre, 76,
              (decode(gv_movimientos.cod_modalidad, 71,
               pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                            nvl(gv_movimientos.monto, 0), gv_movimientos.cotizacion)
                -- SDC le paso la cotizacion
              , 0)), 0)) +
       (decode(gv_movimientos.cod_mad_padre, 73,
                -- ARBITRAJE
               decode(gv_movimientos.nro_secuencia, 1,
                       pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                                    nvl(gv_movimientos.monto, 0),
                                                    gv_movimientos.cotizacion)
                        -- SDC le paso la cotizacion
                      , 0), 74,
                -- CANJE
               decode(gv_movimientos.nro_secuencia, 1,
                       pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                                    nvl(gv_movimientos.monto, 0),
                                                    gv_movimientos.cotizacion)
                        -- SDC le paso la cotizacion
                      , 0), 0)) mto_compra,
       (decode(gv_movimientos.cod_mad_padre, 72,
               pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                            nvl(gv_movimientos.monto, 0), gv_movimientos.cotizacion)
                -- SDC le paso la cotizacion
              , 0)) +
       --OPERACION FUTURA
       (decode(gv_movimientos.cod_mad_padre, 76,
              (decode(gv_movimientos.cod_modalidad, 72,
               pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                            nvl(gv_movimientos.monto, 0), gv_movimientos.cotizacion)
                -- SDC le paso la cotizacion
              , 0)), 0)) +
       (decode(gv_movimientos.cod_mad_padre, 73,
                -- ARBITRAJE
               decode(gv_movimientos.nro_secuencia, 2,
                       pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                                    nvl(gv_movimientos.monto, 0),
                                                    gv_movimientos.cotizacion)
                        -- SDC le paso la cotizacion
                      , 0), 74,
                -- CANJE
               decode(gv_movimientos.nro_secuencia, 2,
                       pal_cam.fu_con_mon_a_moneda(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                                                    nvl(gv_movimientos.monto, 0),
                                                    gv_movimientos.cotizacion)
                        -- SDC le paso la cotizacion
                      , 0), 0)) mto_venta,
       (decode(gv_movimientos.cod_mad_padre, 71,
               decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte, gv_movimientos.cotizacion,
                       fug_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)), 76,
               -- FORWARD
               decode(gv_movimientos.cod_modalidad, 71,
                      decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte, gv_movimientos.cotizacion,
                             fug_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)), 0), 73,
                -- ARBITRAJE
               decode(gv_movimientos.nro_secuencia, 1,
                       decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                               gv_movimientos.cotizacion,
                               pag_gen.fu_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)), 0), 74,
                -- CANJE
               decode(gv_movimientos.nro_secuencia, 1,
                       decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                               gv_movimientos.cotizacion,
                               pag_gen.fu_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)), 0), 0)) tot_cot_compra,
       (decode(gv_movimientos.cod_mad_padre, 71, 1, 76,
               decode(gv_movimientos.cod_modalidad, 71, 1, 0), 73,
               decode(gv_movimientos.nro_secuencia, 1, 1, 0), 74,
               decode(gv_movimientos.nro_secuencia, 1, 1, 0), 0)) ind_cot_compra,
       (decode(gv_movimientos.cod_mad_padre, 72,
               decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte, gv_movimientos.cotizacion,
                       pag_gen.fu_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)), 76,
               -- FORWARD
               decode(gv_movimientos.cod_modalidad, 72,
                      decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte, gv_movimientos.cotizacion,
                             pag_gen.fu_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)), 0), 73,
                -- ARBITRAJE
               decode(gv_movimientos.nro_secuencia, 2,
                       decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                               gv_movimientos.cotizacion, fug_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)),
                       0), 74,
                -- ARBITRAJE
               decode(gv_movimientos.nro_secuencia, 2,
                       decode(gv_movimientos.cod_moneda, pag_gen.fu_obt_mon_fuerte,
                               gv_movimientos.cotizacion, fug_obt_cotizacion(pag_gen.fu_obt_mon_fuerte)),
                       0), 0)) tot_cot_venta,
       (decode(gv_movimientos.cod_mad_padre, 72, 1, 76,
               decode(gv_movimientos.cod_modalidad, 72, 1, 0), 73,
               decode(gv_movimientos.nro_secuencia, 2, 1, 0), 74,
               decode(gv_movimientos.nro_secuencia, 2, 1, 0), 0)) ind_cot_venta,
       cliente.cod_ofi_cliente,
       oc.descripcion ofi_cliente,
       cc.descripcion ciu_cliente,
       gv_movimientos.cod_ofi_origen,
       oo.descripcion ofi_origen,
       co.descripcion ciu_origen
  FROM ba_monedas,
       ge_movimientos gv_movimientos,
       lc_tip_operaciones,
       (SELECT gv_movimientos.nro_documento,
               gv_movimientos.nro_documento2 nro_doc,
               gv_movimientos.fecha,
               gv_movimientos.hora,
               gv_movimientos.cod_usuario,
               ba_personas.cod_persona,
               nvl(ba_personas.nom_completo, gv_movimientos.concepto) nombre,
               c.cod_oficina cod_ofi_cliente
          FROM ba_personas, ge_clientes c, ge_movimientos gv_movimientos
         WHERE to_char(gv_movimientos.nro_documento2) = ba_personas.cod_persona(+)
           AND c.cod_persona(+) = ba_personas.cod_persona
           AND gv_movimientos.cod_transaccion = 760
           AND gv_movimientos.cod_mod_padre = 7
           AND gv_movimientos.reversado = 'N') cliente,
       ba_oficinas oo,
       ba_oficinas oc,
       ba_ciudades co,
       ba_ciudades cc
 WHERE ba_monedas.cod_moneda = gv_movimientos.cod_moneda
   AND ((gv_movimientos.cod_mad_padre IN (71, 72) AND gv_movimientos.nro_secuencia = 1 AND gv_movimientos.cod_ref_cambio <> 76) OR
        (gv_movimientos.cod_mad_padre = 76 AND gv_movimientos.nro_secuencia = 1) OR
       (gv_movimientos.cod_mad_padre IN (73) AND gv_movimientos.nro_secuencia IN (1, 2)))
   AND gv_movimientos.monto IS NOT NULL
   AND gv_movimientos.cotizacion IS NOT NULL
   AND gv_movimientos.mto_equ_local IS NOT NULL
   AND cliente.fecha(+) = gv_movimientos.fecha
   AND cliente.cod_usuario(+) = gv_movimientos.cod_usuario
   AND cliente.hora(+) = gv_movimientos.hora
   AND gv_movimientos.reversado = 'N'
   AND gv_movimientos.cod_tip_ope_cambio = lc_tip_operaciones.cod_tip_operacion
   AND ((afe_posicion IN ('E', 'O') AND gv_movimientos.cod_mad_padre <> 76) OR (gv_movimientos.cod_mad_padre = 76))
   AND oc.cod_oficina(+) = cliente.cod_ofi_cliente
   AND oo.cod_oficina(+) = gv_movimientos.cod_ofi_origen
   AND cc.cod_pais(+) = oc.cod_pais
   AND cc.cod_ciudad(+) = oc.cod_ciudad
   AND co.cod_pais(+) = oo.cod_pais
   AND co.cod_ciudad(+) = oo.cod_ciudad) r
 WHERE r.cla_operacion = 8
   group by r.tip_informe, r.fecha, r.cla_operacion, r.ciu_origen
 ORDER BY 3
;

