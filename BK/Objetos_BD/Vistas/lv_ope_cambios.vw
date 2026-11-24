create or replace force view it.lv_ope_cambios as
Select xx.Operacion,
       xx.nro_operacion,
       xx.cod_moneda,
       xx.monto,
       xx.cod_oficina,
       xx.fec_operacion fecha,
       xx.equ_local,
       xx.concepto,
       xx.canal,
       xx.cliente
From
(select t.descripcion Operacion,
      nro_operacion,
      cod_Moneda,
      monto,
      cod_oficina,
      fec_operacion,
      mto_equ_local equ_local,
      concepto,
      decode(ope_homebanking,'S','HBANK','OTRO') Canal,
      cod_persona || '-' || fue_obt_nom_persona(cod_persona) cliente
 from lc_ope_pendientes p, lc_tip_operaciones t
where /*fec_operacion between '01/FEB/2019' and '28/FEB/2019'
  and*/ liquidado = 'S'
  and p.cod_tip_operacion = t.cod_tip_operacion
union
select o.descripcion,
      h.nro_documento,
      h.cod_moneda,
      h.monto,
      h.cod_oficina,
      h.fecha,
      h.mto_equ_local,
      h.concepto,
      'CAJA' Canal,
      h.cod_persona || '-' || fue_obt_nom_persona(cod_persona) cliente
 from lc_movimientos_his h, lc_tip_operaciones o
where
/*fecha between '01/FEB/2019' and '28/FEB/2019'
and*/ h.cod_tip_ope_cambio = o.cod_tip_operacion
and o.nivel = 1
and not exists (select *
   from lc_ope_pendientes p
  where p.nro_operacion = h.nro_documento
    and p.fec_operacion = h.fecha)
and h.Cod_Modulo = '7'
and h.usu_insercion <> 'XPY8512'
union
select w.descripcion,
       a.nro_documento,
       a.cod_moneda,
       a.monto,
       a.cod_oficina,
       a.fecha,
       a.mto_equ_local,
       a.concepto,
       a.cod_usuario Canal,
      cod_persona || '-' || fue_obt_nom_persona(cod_persona) cliente
  from ah_movimientos_his a, ge_transacciones w
 where  /*fecha between '01/FEB/2019' and '28/FEB/2019'
 and*/ a.cod_transaccion = 503
 and exists (select 1
    from ah_movimientos_his b
   where a.fecha = b.FECHA
     and a.hora = b.hora
     and a.cod_usuario = b.cod_usuario
     and a.cod_moneda <> b.cod_moneda
     and b.COD_TRANSACCION = 602)
 and not exists (select 1
    from lc_ope_pendientes aa
   where a.NRO_DOCUMENTO = aa.nro_operacion)
 and monto > 0
 and reversado = 'N'
 and a.cod_transaccion = w.cod_transaccion
 and a.cod_modulo = w.cod_modulo
 and a.cod_modalidad = w.cod_modalidad
 union
 select w.descripcion,
       a.nro_documento,
       a.cod_moneda,
       a.monto,
       a.cod_oficina,
       a.fecha,
       a.mto_equ_local,
       a.concepto,
       a.cod_usuario Canal,
      cod_persona || '-' || fue_obt_nom_persona(cod_persona) cliente
  from cc_movimientos_his a, ge_transacciones w
 where /*fecha between '01/FEB/2019' and '28/FEB/2019'
 and*/ a.cod_transaccion = 503
 and exists (select 1
    from cc_movimientos_his b
   where a.fecha = b.FECHA
     and a.hora = b.hora
     and a.cod_usuario = b.cod_usuario
     and a.cod_moneda <> b.cod_moneda
     and b.COD_TRANSACCION = 602)
 and not exists (select 1
    from lc_ope_pendientes aa
   where a.NRO_DOCUMENTO = aa.nro_operacion
     and a.fecha = aa.fec_operacion)
 and monto > 0
 and reversado = 'N'
 and a.cod_transaccion = w.cod_transaccion
 and a.cod_modulo = w.cod_modulo
 and a.cod_modalidad = w.cod_modalidad
 union
 select w.descripcion,
        a.nro_documento,
        a.cod_moneda,
        a.monto,
        a.cod_oficina,
        a.fecha,
        a.mto_equ_local,
        a.concepto,
        a.cod_usuario Canal,
        cod_persona || '-' || fue_obt_nom_persona(cod_persona) cliente
  from cc_movimientos_his a, ge_transacciones w
 where /*fecha between '01/FEB/2019' and '28/FEB/2019'
 and*/ a.cod_transaccion = 503
 and exists (select 1
    from ah_movimientos_his b
   where a.fecha = b.FECHA
     and a.hora = b.hora
     and a.cod_usuario = b.cod_usuario
     and a.cod_moneda <> b.cod_moneda
     and b.COD_TRANSACCION = 602)
 and not exists (select 1
    from lc_ope_pendientes aa
   where a.NRO_DOCUMENTO = aa.nro_operacion
     and a.fecha = aa.fec_operacion)
 and monto > 0
 and reversado = 'N'
 and cod_tra_padre = 388
 and a.cod_transaccion = w.cod_transaccion
 and a.cod_modulo = w.cod_modulo
 and a.cod_modalidad = w.cod_modalidad
 union
 select a.referencia,
        a.nro_documento,
        a.cod_moneda,
        a.monto,
        a.cod_oficina,
        a.fecha,
        a.mto_equ_local,
        a.concepto,
        a.cod_usuario Canal,
        cod_persona || '-' || fue_obt_nom_persona(cod_persona) cliente
  from ah_movimientos_his a, ge_transacciones w
 where /*fecha between '01/FEB/2019' and '28/FEB/2019'
 and*/ a.cod_transaccion = 503
 and exists (select 1
    from cc_movimientos_his b
   where a.fecha = b.FECHA
     and a.hora = b.hora
     and a.cod_usuario = b.cod_usuario
     and a.cod_moneda <> b.cod_moneda
     and b.COD_TRANSACCION = 602)
 and not exists (select 1
    from lc_ope_pendientes aa
   where a.NRO_DOCUMENTO = aa.nro_operacion
     and a.fecha = aa.fec_operacion)
 and monto > 0
 and reversado = 'N'
 and cod_tra_padre = 388
 and a.cod_transaccion = w.cod_transaccion
 and a.cod_modulo = w.cod_modulo
 and a.cod_modalidad = w.cod_modalidad)xx;

