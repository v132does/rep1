create or replace force view it.bv_rub_conciliaciones as
select
---Realizado por SIMGIA S.R.L. para consulta dinámica de partidas conciliadas y no conciliadas de cuentas de tarjetas
d.fecha,d.hora,d.cod_usuario,d.nro_secuencia,d.nro_cuenta,
d.monto,d.cod_moneda,d.mto_equ_local,d.cotizacion,d.cod_oficina,d.cod_ofi_origen,
d.concepto,d.nro_documento,d.cod_transaccion,d.cod_modulo,d.cod_modalidad,d.nro_documento4,
d.nro_asiento,d.nro_linea,d.descripcion,d.reversado,d.cod_rubro,d.tip_mov,
null fec_conciliacion, d.mov_cuadre, 'N'conciliado
from cb_con_rub_det d
union all

select d.fecha,d.hora,d.cod_usuario,d.nro_secuencia,m.nro_cuenta,
m.monto,m.cod_moneda,m.mto_equ_local,m.cotizacion,m.cod_oficina,m.cod_ofi_origen,
m.concepto,m.nro_documento,m.cod_transaccion,m.cod_modulo,m.cod_modalidad,m.nro_documento4,
c.nro_asiento,c.nro_linea,c.descripcion,m.reversado,d.cod_rubro,c.tip_movimiento,
d.fec_conciliacion,d.mov_cuadre, 'S'conciliado
from cb_con_rub_det_his d,smg_gv_movimientos m, cb_asi_automaticos_det c
where d.fecha=m.FECHA
and d.hora=m.HORA
and d.cod_usuario=m.COD_USUARIO
and d.nro_secuencia=m.NRO_SECUENCIA
and m.FECHA=c.fecha
and m.NRO_DOCUMENTO4=c.ref_movimiento
and d.cod_rubro=c.cod_rubro
;

