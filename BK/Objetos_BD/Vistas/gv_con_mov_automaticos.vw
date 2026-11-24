CREATE OR REPLACE FORCE VIEW IT.GV_CON_MOV_AUTOMATICOS AS
SELECT 'S' libro,
       c.nro_cuenta,
       c.cod_moneda,
       d.nro_documento,
       d.tip_movimiento tipo,
       d.monto,
       d.ref_movimiento,
       d.monto cta_monto,
       0 mov_monto,
       decode(d.tip_movimiento, 'C', d.monto, 0) credito,
       decode(d.tip_movimiento, 'D', d.monto, 0) debito,
       d.nro_orden nro_secuencia,
       c.fec_mensaje fecha,
       NULL hora,
       NULL cod_usuario,
       NULL mov_tipo,
       NULL cod_modulo,
       NULL cod_modalidad,
       NULL cod_rubro,
       d.nro_ref_externa,
       d.nro_conciliacion,
			 0 sal_extracto
  FROM ge_ext_swift c, ge_ext_swift_det d
 WHERE c.nro_ref_externa = d.nro_ref_externa
 union all
select 'N',s.nro_cuenta,null,null,null,null,null,null,null,null,null,s.nro_secuencia,s.fec_mensaje,null,null,null,null,null,null,s.nro_ref_externa,d.nro_conciliacion,s.sal_disponible
from ge_ext_swift s, ge_ext_swift_det d
where s.sal_disponible <> 0
and s.nro_ref_externa = d.nro_ref_externa
UNION ALL
SELECT 'N',
       m.nro_cuenta,
       m.cod_moneda,
       to_char(m.nro_documento),
       decode(t.tipo, NULL, m.tip_mov_rubro, t.tipo) tipo,
       m.monto,
       m.concepto,
       0 cta_monto,
       m.monto mov_monto,
       decode(decode(t.tipo, NULL, m.tip_mov_rubro, t.tipo), 'C', m.monto, 0) credito,
       decode(decode(t.tipo, NULL, m.tip_mov_rubro, t.tipo), 'D', m.monto, 0) debito,
       m.nro_secuencia,
       m.fecha,
       m.hora,
       m.cod_usuario,
       m.tipo,
       m.cod_modulo,
       m.cod_modalidad,
       m.cod_rubro,
       NULL,
       m.nro_conciliacion,
			 0 sal_extracto
  FROM gv_movimientos m, ge_transacciones t
 WHERE m.cod_modulo = t.cod_modulo(+)
   AND m.cod_modalidad = t.cod_modalidad(+)
   AND m.cod_transaccion = t.cod_transaccion(+)
   AND m.cod_modulo = 4
   AND m.cod_modalidad = 45
   AND m.reversado = 'N'
   AND nvl(m.monto, 0) <> 0
	 AND (cod_rubro IS NULL OR cod_rubro = fuc_obt_rub_cta_bancaria(m.nro_cuenta));

