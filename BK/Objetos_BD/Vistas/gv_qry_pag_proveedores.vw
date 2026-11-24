CREATE OR REPLACE FORCE VIEW IT.GV_QRY_PAG_PROVEEDORES AS
SELECT a.cod_ente cod_empresa,a.nro_orden,a.nro_factura,a.cod_moneda,a.monto,a.estado,
       a.concepto,prov.cod_ent_proveedor cod_proveedor,prov.nom_proveedor proveedor,
       a.nro_cta_credito,a.nro_cta_debito, A.Beneficiario,a.nro_cheque,a.nro_recibo,
       a.fec_proceso,a.hora,a.fec_pago,a.for_pago, a.fec_ingreso, a.referencia, prov.tot_impuesto,
       prov.tip_venta, prov.cod_compra
  FROM ge_pag_proveedores a, pv_compras prov
 WHERE prov.nro_factura   = a.nro_factura
   AND prov.nom_proveedor = a.beneficiario
   AND prov.tip_comprobante = a.tip_comprobante -- CB. 18/10/2013. SPI 1876.
   AND a.estado IN ('C','R') -- Trae los q no son pagados
   AND prov.estado NOT IN ('N','P') -- No trae los anulados OMM 28/09/2011.  -- CB. 02/10/2013. SPI 2513. No incluir las Pagadas.
   AND (a.for_pago = 'C' OR a.for_pago = 'R' OR a.for_pago = 'E' OR (a.for_pago = 'G'))
;

