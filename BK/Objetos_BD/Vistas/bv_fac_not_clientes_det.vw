create or replace force view it.bv_fac_not_clientes_det as
select a.cod_persona, x.nom_completo,
       a.fecha, a.hora, a.cod_usuario usuario, a.nro_secuencia secuencia,
       decode(a.reversado,'S','N','F') tip_comprobante,
       'DEL_MES_A_GENERAR' corte,
       a.nro_factura, a.nro_timbrado,
       a.cod_tra_padre, b.descripcion des_trapad, a.cod_transaccion cod_transaccion,
       c.descripcion des_transac, a.nro_cuenta, a.cod_moneda,
       nvl(a.mto_gravado_10,a.mto_gravado_5) mto_gravado,
       nvl(a.impuesto_10,a.impuesto_5) impuesto,
       nvl(a.mto_gravado_10,a.mto_gravado_5) + nvl(a.impuesto_10,a.impuesto_5) mto_total,
       a.rel_fac_referencia, a.rel_act_operativa, a.cod_modulo, a.cod_modalidad,
       ---
       a.nro_documento, a.mto_exento_gs, a.mto_gra_5_gs,
       a.mto_gra_10_gs, a.impuesto_5_gs, a.impuesto_10_gs,
       a.aju_impuesto_5, a.aju_impuesto_10, a.error
from cb_lib_ventas_det_tmp a, ge_transacciones b, ge_transacciones c,
     ba_personas x
where b.cod_transaccion = a.cod_tra_padre
  and b.cod_modulo = a.cod_mod_padre
  and b.cod_modalidad = a.cod_mad_padre
  and c.cod_transaccion = a.cod_transaccion
  and c.cod_modulo = a.cod_modulo
  and c.cod_modalidad = a.cod_modalidad
  and x.cod_persona = a.cod_persona
UNION ALL
select a.cod_persona, x.nom_completo,
       d.fecha, d.hora, d.cod_usuario usuario, d.nro_secuencia secuencia,
       a.tip_comprobante,
       'HISTORICO' corte, a.nro_factura, a.nro_timbrado,
       d.cod_tra_padre trpad, b.descripcion despad, d.cod_transaccion tran,
       b.descripcion destra, d.nro_cuenta, d.cod_moneda,
       nvl(d.mto_gravado_10,d.mto_gravado_5) gra,
       nvl(d.impuesto_10,d.impuesto_5) imp,
       nvl(d.mto_gravado_10,d.mto_gravado_5) + nvl(d.impuesto_10,d.impuesto_5) total,
       null rel_fac_referencia, null rel_act_operativa, d.cod_modulo, d.cod_modalidad,
       ----
       d.nro_documento, d.mto_exento_gs, d.mto_gra_5_gs,
       d.mto_gra_10_gs, d.impuesto_5_gs, d.impuesto_10_gs,
       d.aju_impuesto_5, d.aju_impuesto_10, null error
from cb_lib_ventas_det d, cb_lib_ventas a,
     ge_transacciones b, ge_transacciones c, ba_personas x
where a.nro_factura = d.nro_factura
  and a.nro_timbrado = d.nro_timbrado
  and b.cod_transaccion = d.cod_tra_padre
  and b.cod_modulo = d.cod_mod_padre
  and b.cod_modalidad = d.cod_mad_padre
  and c.cod_transaccion = d.cod_transaccion
  and c.cod_modulo = d.cod_modulo
  and c.cod_modalidad = d.cod_modalidad
  and x.cod_persona = a.cod_persona
order by 1,3 desc
;

