CREATE OR REPLACE PROCEDURE IT.PRZ_INS_SUMINISTRO
 (r_sumi IN in_suministros%ROWTYPE
 )
 IS
BEGIN
   ---
   insert into in_suministros(
   cod_suministro,cod_articulo,descripcion,
   cod_oficina,cod_area,val_compra,cod_moneda,
   fecha,cod_ent_proveedor,nro_factura,tipo,
   estado, fec_transferencia)
   values(
   r_sumi.cod_suministro,r_sumi.cod_articulo,r_sumi.descripcion,
   r_sumi.cod_oficina,r_sumi.cod_area,r_sumi.val_compra,r_sumi.cod_moneda,
   r_sumi.fecha,r_sumi.cod_ent_proveedor,r_sumi.nro_factura,r_sumi.tipo,
   r_sumi.estado, r_sumi.fec_transferencia);
   ---
END;
/

