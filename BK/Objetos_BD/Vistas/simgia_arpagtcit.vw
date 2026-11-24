create or replace force view it.simgia_arpagtcit as
select "RPFCHA","RPHORA","RPUSR","RPCTA","RPMONE","RPMONTO","RPSUC","RPORI","RPCONC","RPCAJA","RPRUBIT","RPRUBAS","RPTIPO","RPTRN","RPMOD","RPTRNP","RPASIE","RPLINE","REVERSADO"/*, "FUENTE"*/ from
(select nvl(to_char(h.fecha,'ddmmyyyy'),0) RPFCHA,
  nvl(replace(to_char(h.hora),CHR(58),''),0) RPHORA,
  nvl(h.cod_usuario,'') RPUSR,
  nvl(h.nro_cuenta,0) RPCTA,
  nvl(h.cod_moneda,'') RPMONE,
  nvl(h.monto,0) RPMONTO,
  nvl(h.cod_oficina,0) RPSUC,
  nvl(h.cod_ofi_origen,0) RPORI,
  nvl(h.concepto,'') RPCONC,
  nvl(h.nro_caja,0) RPCAJA,
  nvl(d.cod_rubro,0) RPRUBIT,
  nvl(r.cod_rub_externo,0) RPRUBAS,
  nvl(d.tip_movimiento,'') RPTIPO,
  nvl(decode(substr(h.cod_transaccion,-3),h.COD_TRANSACCION,h.COD_TRANSACCION,substr(h.cod_transaccion,-3)),0) RPTRN,
  nvl(h.cod_modalidad,0) RPMOD,
  nvl(decode(substr(h.cod_tra_padre,-3),h.cod_tra_padre,h.cod_tra_padre,substr(h.cod_tra_padre,-3)),0) RPTRNP,
  --nvl(h.cod_tra_padre,0) RPTRNP,
  nvl(d.nro_asiento,0) RPASIE,
  nvl(d.nro_linea,0) RPLINE,
  h.reversado
  --d.mto_mon_rubro,
  --d.mto_mon_local
  --,'ta_movimientos_his' fuente
  , h.nro_documento --se agrega para evitar filtrar pagos del mismo cliente, mismo monto, misma fecha n.a. 20100630
from ta_movimientos_his h, cb_asi_automaticos_det d, cb_rubros r
where h.fecha=d.fecha
and h.nro_documento4=d.ref_movimiento
and r.cod_rubro = d.cod_rubro
and h.fecha = pag_cal.fu_obt_fec_actual(1) --pag_cal.fu_obt_fec_actual(1)
and  r.cod_rub_externo = '260002060993'
and (h.reversado = 'N' or (h.reversado = 'S' and h.fecha <> h.fec_valor))
union
select nvl(to_char(m.fecha,'ddmmyyyy'),0) RPFCHA,
  nvl(replace(to_char(m.hora),CHR(58),''),0) RPHORA,
  nvl(m.cod_usuario,'') RPUSR,
  nvl(m.nro_cuenta,0) RPCTA,
  nvl(m.cod_moneda,'') RPMONE,
  nvl(m.monto,0) RPMONTO,
  nvl(m.cod_oficina,0) RPSUC,
  nvl(m.cod_ofi_origen,0) RPORI,
  nvl(m.concepto,nvl(d.descripcion,'')) RPCONC,
  nvl(m.nro_caja,0) RPCAJA,
  nvl(d.cod_rubro,0) RPRUBIT,
  nvl(r.cod_rub_externo,0) RPRUBAS,
  nvl(d.tip_movimiento,'') RPTIPO,
  nvl(decode(substr(m.cod_transaccion,-3),m.COD_TRANSACCION,m.COD_TRANSACCION,substr(m.cod_transaccion,-3)),0) RPTRN,
  nvl(m.cod_modalidad,0) RPMOD,
  --nvl(m.cod_tra_padre,0) RPTRNP,
  nvl(decode(substr(m.cod_tra_padre,-3),m.cod_tra_padre,m.cod_tra_padre,substr(m.cod_tra_padre,-3)),0) RPTRNP,
  nvl(d.nro_asiento,0) RPASIE,
  nvl(d.nro_linea,0) RPLINE,
  m.reversado
  --d.mto_mon_rubro,
  --d.mto_mon_local
   --,'gv_movimientos' fuente
  , m.NRO_DOCUMENTO --se agrega para evitar filtrar pagos del mismo cliente, mismo monto, misma fecha n.a. 20100630
from gv_movimientos m, cb_asi_automaticos_det d, cb_rubros r
where m.fecha=d.fecha
and m.nro_documento4=d.ref_movimiento
and r.cod_rubro = d.cod_rubro
and m.fecha = pag_cal.fu_obt_fec_actual(1) --pag_cal.fu_obt_fec_actual(1)
and r.cod_rub_externo = '260002060993'
and m.nro_cuenta is null
and (m.reversado = 'N' or (m.reversado = 'S' and m.fecha <> m.fec_valor))
)order by 1, 2
;

