CREATE OR REPLACE FORCE VIEW IT.KV_COMPRAS AS
SELECT a.nro_factura,
'Timbrado Nº '||a.timbrado timbrado,
'Válido hasta '||fug_des_mes(a.fec_val_timbrado)||' de '||to_char(a.fec_val_timbrado,'yyyy') mes_validez,
a.fecha,
a.fec_val_timbrado,
a.cod_ofi_origen cod_oficina,
tip_comprobante,
a.tip_venta tip_venta,
a.estado,
nom_completo,
fue_obt_dir_principa(p.cod_persona) direccion,
fue_obt_tel_principa(p.cod_persona) tel_cabecera,
decode(a.nro_factura,'0',null,nro_factura) nro_fac_referencia,
decode(a.timbrado,'0',null,a.timbrado) nro_tim_referencia,
a.cotizacion,
'N' impreso,
'ORIGINAL' tip_impresion,
a.cod_moneda,
p.cod_persona,
p.nro_documento nro_doc_cabecera,
substr(a.ruc,length(a.ruc)) dig_verificador,
a.ruc  ruc_cliente,
null fec_aut_timbrado,
a.timbrado nro_timbrado,
a.cod_compra cod_compra
FROM pv_compras A, ba_personas p
 WHERE a.tip_comprobante = 'T'
  AND p.nro_documento = a.ruc
  AND a.estado in ('A','P')
order by nro_factura;

