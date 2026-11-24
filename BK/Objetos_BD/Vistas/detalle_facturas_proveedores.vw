CREATE OR REPLACE FORCE VIEW IT.DETALLE_FACTURAS_PROVEEDORES AS
SELECT DISTINCT x.fec_pago,
                x.cod_moneda,
                x.cod_ofi_origen oficina_proceso,
                x.cod_ent_proveedor,
                x.nom_proveedor nombre_y_apellido,
                x.ruc,
                x.fecha fecha,
                x.fec_vto_credito vto_factura,
                decode(x.ind_pagado, 'N', trunc(x.fec_vto_credito-sysdate),null) Dias_Vencidos_o_Vencer_hoy,
                x.nro_factura,
                x.concepto,
                p.beneficiario,
                nvl(x.tot_compra, 0) monto_factura_total,
                nvl(x.tot_impuesto, 0) monto_factura_iva,
                y.cod_transaccion,
                g.cod_rubro,
                g.descripcion des_rubro,
                x.estado,
                fue_obt_des_refcodes('EST_FACTURA', x.estado) des_estado,
                x.usu_insercion usuario,
                x.fec_insercion,
                y.cod_oficina oficina_destino,
                o.descripcion desc_ofi_des ,
                fue_obt_des_refcodes('TIP_COMPROBANTE', x.tip_comprobante) tip_comprobante,
                y.cod_compra,
                y.nro_linea,
                nvl(y.val_total, 0) monto_det_total,
                fue_obt_des_refcodes('FOR_PAGO', x.for_pago) for_pago,
                p.nro_orden,
                p.nro_cheque,
                nvl(y.val_impuesto, 0) monto_det_iva,
                y.descripcion desc_compra,
                nvl(fug_obt_cotizacion(x.cod_moneda,pag_cal.fu_obt_fec_actual(1)),1) cotizacion,
                nvl((pag_gen.fu_con_mon_a_moneda(x.cod_moneda,
                                                       pag_gen.fu_obt_mon_local,
                                                       (nvl(y.val_total, 0)),
                                                       nvl(fug_obt_cotizacion(x.cod_moneda,
                                                                              pag_cal.fu_obt_fec_actual(1)),
                                                           1))),0)  mon_det_tot_gs,
                 nvl((pag_gen.fu_con_mon_a_moneda(x.cod_moneda,
                                                       pag_gen.fu_obt_mon_local,
                                                       (nvl(y.val_impuesto, 0)),
                                                       nvl(fug_obt_cotizacion(x.cod_moneda,
                                                                              pag_cal.fu_obt_fec_actual(1)),
                                                           1))),0)  mon_det_iva_gs,
                  nvl((pag_gen.fu_con_mon_a_moneda(x.cod_moneda,
                                                       pag_gen.fu_obt_mon_local,
                                                       (nvl(y.val_total, 0)),
                                                       nvl(fug_obt_cotizacion(x.cod_moneda,
                                                                              pag_cal.fu_obt_fec_actual(1)),
                                                           1))),0) -
                  nvl((pag_gen.fu_con_mon_a_moneda(x.cod_moneda,
                                                       pag_gen.fu_obt_mon_local,
                                                       (nvl(y.val_impuesto, 0)),
                                                       nvl(fug_obt_cotizacion(x.cod_moneda,
                                                                              pag_cal.fu_obt_fec_actual(1)),
                                                           1))),0)  mto_det_tot_sin_iva_gs,
                                                           a.cod_area,
                a.descripcion desc_area,
                decode(x.ind_pagado, 'S', 'Si', 'No') pagado,
                nvl(x.ind_caj_chica , 'N') ind_caj_chica
  FROM pv_compras       x,
       pv_compras_det   y,
       ge_transacciones t,
       ge_tip_asientos  g,
       ba_oficinas      o,
       ba_areas         a,
       ge_pag_proveedores  p
 WHERE x.cod_compra      = y.cod_compra
   AND y.cod_modulo      = t.cod_modulo
   AND y.cod_modalidad   = t.cod_modalidad
   AND y.cod_transaccion = t.cod_transaccion
   AND x.cod_moneda      = g.cod_moneda
   AND t.cod_tip_asiento = g.cod_tip_asiento
   AND y.cod_oficina     = o.cod_oficina
   AND p.nro_factura(+)  = x.nro_factura
   AND x.fec_pago        = p.fec_pago(+)
   AND y.cod_oficina     = a.cod_oficina
   AND y.cod_area        = a.cod_area
   and p.estado(+)       <> 'A'
   AND p.beneficiario(+) = substr(x.nom_proveedor, 1, 50)
   and y.cod_transaccion <> 2810
   union all
   SELECT DISTINCT x.fec_pago,
                x.cod_moneda,
                x.cod_ofi_origen oficina_proceso,
                x.cod_ent_proveedor,
                x.nom_proveedor nombre_y_apellido,
                x.ruc,
                x.fecha fecha,
                x.fec_vto_credito vto_factura,
                decode(x.ind_pagado, 'N', trunc(x.fec_vto_credito-sysdate),null) Dias_Vencidos_o_Vencer_hoy,
                x.nro_factura,
                x.concepto,
               p.beneficiario,
                nvl(x.tot_compra, 0) monto_factura_total,
                nvl(x.tot_impuesto, 0) monto_factura_iva,
                f.cod_tra_alta,
                g.cod_rubro,
                g.descripcion des_rubro,
                x.estado,
                fue_obt_des_refcodes('EST_FACTURA', x.estado) des_estado,
                x.usu_insercion usuario,
				x.fec_insercion,
                y.cod_oficina oficina_destino,
                o.descripcion desc_ofi_des ,
                fue_obt_des_refcodes('TIP_COMPROBANTE', x.tip_comprobante) tip_comprobante,
                y.cod_compra,
                y.nro_linea,
                nvl(y.val_total, 0) monto_det_total,
                fue_obt_des_refcodes('FOR_PAGO', x.for_pago) for_pago,
                p.nro_orden,
                p.nro_cheque,
                nvl(y.val_impuesto, 0) monto_det_iva,
                y.descripcion desc_compra,
                nvl(fug_obt_cotizacion(x.cod_moneda,pag_cal.fu_obt_fec_actual(1)),1) cotizacion,
                nvl((pag_gen.fu_con_mon_a_moneda(x.cod_moneda,
                                                       pag_gen.fu_obt_mon_local,
                                                       (nvl(y.val_total, 0)),
                                                       nvl(fug_obt_cotizacion(x.cod_moneda,
                                                                              pag_cal.fu_obt_fec_actual(1)),
                                                           1))),0)  mon_det_tot_gs,
                 nvl((pag_gen.fu_con_mon_a_moneda(x.cod_moneda,
                                                       pag_gen.fu_obt_mon_local,
                                                       (nvl(y.val_impuesto, 0)),
                                                       nvl(fug_obt_cotizacion(x.cod_moneda,
                                                                              pag_cal.fu_obt_fec_actual(1)),
                                                           1))),0)  mon_det_iva_gs,
                  nvl((pag_gen.fu_con_mon_a_moneda(x.cod_moneda,
                                                       pag_gen.fu_obt_mon_local,
                                                       (nvl(y.val_total, 0)),
                                                       nvl(fug_obt_cotizacion(x.cod_moneda,
                                                                              pag_cal.fu_obt_fec_actual(1)),
                                                           1))),0) -
                  nvl((pag_gen.fu_con_mon_a_moneda(x.cod_moneda,
                                                       pag_gen.fu_obt_mon_local,
                                                       (nvl(y.val_impuesto, 0)),
                                                       nvl(fug_obt_cotizacion(x.cod_moneda,
                                                                              pag_cal.fu_obt_fec_actual(1)),
                                                           1))),0)  mto_det_tot_sin_iva_gs,
                                                           a.cod_area,
                a.descripcion desc_area,
                decode(x.ind_pagado, 'S', 'Si', 'No') pagado,
                nvl(x.ind_caj_chica , 'N') ind_caj_chica
  FROM pv_compras       x,
       pv_compras_det   y,
       ge_transacciones t,
       ge_tip_asientos  g,
       ba_oficinas      o,
       ba_areas         a,
       ge_pag_proveedores  p, af_articulos f
 WHERE x.cod_compra      = y.cod_compra
   AND f.cod_modulo      = t.cod_modulo
   AND f.cod_modalidad   = t.cod_modalidad
   AND f.cod_tra_alta    = t.cod_transaccion
   AND x.cod_moneda      = g.cod_moneda
   AND t.cod_tip_asiento = g.cod_tip_asiento
   AND y.cod_oficina     = o.cod_oficina
   AND p.nro_factura(+)  = x.nro_factura
   AND x.fec_pago        = p.fec_pago(+)
   AND y.cod_oficina     = a.cod_oficina
   AND y.cod_area        = a.cod_area
   and p.estado(+)       <> 'A'
   and y.cod_transaccion = 2810
   AND p.beneficiario(+) = substr(x.nom_proveedor, 1, 50)
   and y.cod_articulo    = f.cod_articulo
 ORDER BY 1 asc, 2, 3, 4, 5, 6,7;

