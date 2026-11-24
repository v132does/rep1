CREATE OR REPLACE FORCE VIEW IT.BV_LIB_COMPRAS AS
SELECT to_char(a.fecha, 'mm') mes,
       to_char(a.fecha, 'yyyy') ano,
       fug_des_mes(a.fecha) des_mes,
       to_char(a.fecha, 'dd') dia,
       a.nro_factura,
       a.nro_timbrado,
       a.tipo condicion,
       nvl(b.tip_comprobante, a.tip_comprobante)tip_comprobante,
       decode(a.tipo, 'CO', decode(b.can_cuotas, NULL, 0, b.can_cuotas),
              decode(b.can_cuotas, NULL, 1, b.can_cuotas)) can_cuotas,
       a.fecha,
       a.cod_persona,
       CASE
          WHEN instr(a.nro_documento, '-') > 0 THEN
           a.nro_documento
          WHEN instr(a.nro_documento, '-') <= 0 THEN
           a.nro_documento || '-' || fue_obt_ruc_dig_verificador(a.nro_documento)
       END nro_documento,
       a.raz_social nombre,
       a.mto_gravado_10,
       a.impuesto_10,
       a.mto_gravado_5,
       a.impuesto_5,
       a.mto_exento,
       nvl(a.mto_gravado_10, 0) + nvl(a.impuesto_10, 0) + nvl(a.mto_gravado_5, 0) +
       nvl(a.impuesto_5, 0) + nvl(a.mto_exento, 0) mto_total,
       a.cod_ofi_origen cod_oficina,
       a.cod_ent_proveedor,
       NULL nro_comprobante,
       a.fec_pago,
       nvl(b.cod_moneda,a.cod_moneda)cod_moneda,
       null nro_fac_referencia,
       null nro_tim_referencia,
       a.ind_fac_virtual
  FROM cb_lib_compras a, pv_compras b
 WHERE a.nro_factura = b.nro_factura(+)
   AND a.cod_ent_proveedor = b.cod_ent_proveedor(+)
   AND a.nro_timbrado = b.timbrado(+)
   AND a.tip_comprobante <> 'P'
   AND (b.estado IS NULL OR b.estado <> 'N')
UNION ALL
SELECT to_char(a.fecha, 'mm') mes,
       to_char(a.fecha, 'yyyy') ano,
       fug_des_mes(a.fecha) des_mes,
       to_char(a.fecha, 'dd') dia,
       a.nro_factura,
       a.nro_timbrado,
       a.tip_venta condicion,
       'NC' tip_comprobante,
       decode(a.tip_venta, 'CO', decode(a.can_cuotas, NULL, 0, a.can_cuotas),
              decode(a.can_cuotas, NULL, 1, a.can_cuotas)) can_cuotas,
       a.fecha,
       a.cod_persona,
       CASE
          WHEN instr(a.nro_documento, '-') > 0 THEN
           a.nro_documento
          WHEN instr(a.nro_documento, '-') <= 0 THEN
           a.nro_documento || '-' || fue_obt_ruc_dig_verificador(a.nro_documento)
       END nro_documento,
       a.nom_completo nombre,
       a.mto_gravado_10_gs  ,
       a.impuesto_10_gs ,
       a.mto_gravado_5_gs ,
       a.impuesto_5_gs ,
       a.mto_exento_gs ,
       nvl(a.mto_gravado_10_gs, 0) + nvl(a.impuesto_10_gs, 0) + nvl(a.mto_gravado_5_gs, 0) +
       nvl(a.impuesto_5_gs, 0) + nvl(a.mto_exento_gs, 0) mto_total,
       a.cod_oficina,
       NULL cod_ent_prodeedor,
       NULL nro_comprobante,
       a.fecha fec_pago,
       a.cod_moneda,
       a.nro_fac_referencia,
       a.nro_tim_referencia,
       null
  FROM cb_lib_ventas a
 WHERE a.tip_comprobante = 'N'
 AND ((a.serie is not null and a.cod_control is not null ) or (a.serie is null));

