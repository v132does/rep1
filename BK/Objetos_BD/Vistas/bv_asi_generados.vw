create or replace force view it.bv_asi_generados as
select cba.fecha, cba.HORA,asi.nro_asiento,asi.nro_linea, cbx.nro_asi_real,
       asi.cod_rubro cod_rubro, decode(asi.cod_rubro,null,null,cb_rubros.descripcion)rubro,
       cba.cod_ofi_origen ofi_origen,  asi.cod_oficina,  cba.tip_movimiento, cba.cod_moneda,
       decode(cba.nro_cuenta, null, cba.concepto, fug_obt_dat_autoriza('D',null,cba.nro_cuenta)) denominacion,
       decode(cba.nro_cuenta, null, null, fug_obt_dat_autoriza('C',null,cba.nro_cuenta)) cta,
       cba.monto,cba.mto_equ_local,
       asi.ref_movimiento, cba.COD_PERSONA,
       asi.descripcion asi_desc,
     case when asi.tip_movimiento = 'D' and cba.cod_Moneda <> 'GS' then nvl(cba.mto_equ_local,0)
        when asi.tip_movimiento = 'D' and cba.cod_Moneda = 'GS' then  NVL(cba.monto,0)
        else 0 end debito,
     case when asi.tip_movimiento = 'C' and cba.cod_Moneda <> 'GS' then nvl(cba.mto_equ_local,0)
        when asi.tip_movimiento = 'C' and cba.cod_Moneda = 'GS' then  NVL(cba.monto,0)
        else 0  end credito,
       cba.cod_usuario, cbx.reversado reversado, cbx.confirmado confirmado, cbx.cod_modulo,
       cbx.cod_modalidad,ofi.descripcion oficina,  mon.descripcion moneda,
       cba.cod_tip_movimiento movi,cba.cod_banco,decode(cba.nro_secuencia,1,cba.nro_documento3,0) nro_cheque,
       cba.cod_mad_padre,  fue_obt_titulo(cba.des_transaccion) des_transaccion,cba.COD_TRANSACCION,
        cba.COD_TRA_PADRE, cba.NRO_CUENTA,cba.NRO_DOCUMENTO
from gv_movimientos cba,cb_asi_automaticos_det asi,cb_asi_automaticos cbx,cb_rubros
,ba_monedas mon,ba_oficinas ofi
where mon.cod_moneda = cba.cod_moneda
and cba.nro_documento4 = asi.ref_movimiento
and cba.fecha = asi.fecha
and cbx.fecha = asi.fecha
and cbx.cod_oficina = asi.cod_oficina
and cbx.nro_asiento = asi.nro_asiento
and asi.cod_rubro = cb_rubros.cod_rubro
and cba.cod_oficina = ofi.cod_oficina(+)


union

select asi.fecha, cba.HORA, cbx.nro_asi_automatico, asi.nro_linea, asi.nro_asiento,
       asi.cod_rubro cod_rubro,  decode(asi.cod_rubro,null,null,cb_rubros.descripcion)rubro,
       cba.cod_ofi_origen ofi_origen,  asi.cod_oficina,  cba.tip_movimiento, cba.cod_moneda,
       decode(cba.nro_cuenta, null, cba.concepto, fug_obt_dat_autoriza('D',null,cba.nro_cuenta)) denominacion,
       decode(cba.nro_cuenta, null, null, fug_obt_dat_autoriza('C',null,cba.nro_cuenta)) cta,
       cba.monto,cba.mto_equ_local, asi.ref_movimiento, cba.COD_PERSONA,
       asi.descripcion asi_desc,
     case when asi.tip_movimiento = 'D' and cba.cod_Moneda <> 'GS' then nvl(cba.mto_equ_local,0)
        when asi.tip_movimiento = 'D' and cba.cod_Moneda = 'GS' then  NVL(cba.monto,0)
        else 0 end debito,
    case when asi.tip_movimiento = 'C' and cba.cod_Moneda <> 'GS' then nvl(cba.mto_equ_local,0)
        when asi.tip_movimiento = 'C' and cba.cod_Moneda = 'GS' then  NVL(cba.monto,0)
        else 0  end credito,
       cba.cod_usuario, cbx.reversado reversado, cbx.confirmado confirmado, cbx.cod_modulo,
       cbx.cod_modalidad,ofi.descripcion oficina,  mon.descripcion moneda,
       cba.cod_tip_movimiento movi,cba.cod_banco, decode(cba.nro_secuencia,1,cba.nro_documento3,0) nro_cheque,
       cba.cod_mad_padre,  fue_obt_titulo(cba.des_transaccion) des_transaccion,cba.COD_TRANSACCION,
       cba.COD_TRA_PADRE, cba.NRO_CUENTA,cba.NRO_DOCUMENTO
  from ba_monedas mon, gv_movimientos cba, cb_asientos_det_his asi,
       cb_asientos_his cbx, cb_rubros, ba_oficinas ofi
 where mon.cod_moneda = cba.cod_moneda
 and  cba.nro_documento4 = asi.ref_movimiento
       and cba.fecha = asi.fecha
       and cbx.fecha = asi.fecha
       and cbx.cod_oficina = asi.cod_oficina
       and cbx.nro_asiento = asi.nro_asiento
       and asi.cod_rubro = cb_rubros.cod_rubro
       and cba.cod_oficina = ofi.cod_oficina;

