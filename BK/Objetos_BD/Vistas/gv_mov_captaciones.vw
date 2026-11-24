create or replace force view it.gv_mov_captaciones as
select a.nro_cuenta, fecha, fec_valor, nro_documento, c.descripcion des_tra_padre, c.abreviatura abr_tra_padre,
         b.tipo cod_tip_movimiento, monto, hora, nro_secuencia, a.fec_insercion, a.cod_tra_padre, a.cod_persona,
         a.cod_usuario, a.cod_moneda
    from ge_transacciones c, ge_transacciones b, cc_movimientos_his a
   where estado = 'N'
     and reversado = 'N'
     and monto <> 0
     and b.tipo  in ('D','C')
     and a.cod_modulo = b.cod_modulo
     and a.cod_modalidad = b.cod_modalidad
     and a.cod_transaccion = b.cod_transaccion
     and b.ve_cliente = 'S'
     and a.cod_mod_padre = c.cod_modulo
     and a.cod_mad_padre = c.cod_modalidad
     and a.cod_tra_padre = c.cod_transaccion
     and not exists (select 0 from ah_retenciones x
                      where x.nro_cuenta = a.nro_cuenta
                        and x.nro_documento = a.nro_documento
                        and x.cod_retencion = a.cod_retencion
                        and x.fec_final = a.fec_fin_retencion
                        and x.liberado = 'N')
   union
  select a.nro_cuenta, fecha, fec_valor, nro_documento, c.descripcion des_tra_padre, c.abreviatura abr_tra_padre,
         b.tipo cod_tip_movimiento, monto, hora, nro_secuencia, a.fec_insercion, a.cod_tra_padre, a.cod_persona,
         a.cod_usuario, a.cod_moneda
    from ge_transacciones c, ge_transacciones b, ah_movimientos_his a
   where estado = 'N'
     and reversado = 'N'
     and monto <> 0
     and b.tipo  in ('D','C')
     and a.cod_modulo = b.cod_modulo
     and a.cod_modalidad = b.cod_modalidad
     and a.cod_transaccion = b.cod_transaccion
     and b.ve_cliente = 'S'
     and a.cod_mod_padre = c.cod_modulo
     and a.cod_mad_padre = c.cod_modalidad
     and a.cod_tra_padre = c.cod_transaccion
     and not exists (select 0 from ah_retenciones x
                      where x.nro_cuenta = a.nro_cuenta
                        and x.nro_documento = a.nro_documento
                        and x.cod_retencion = a.cod_retencion
                        and x.fec_final = a.fec_fin_retencion
                        and x.liberado = 'N')
   union
  select a.nro_cuenta, fecha, fec_valor, nro_documento, c.descripcion des_tra_padre, c.abreviatura abr_tra_padre,
         b.tipo cod_tip_movimiento, monto, hora, nro_secuencia, a.fec_insercion, a.cod_tra_padre, a.cod_persona,
         a.cod_usuario, a.cod_moneda
    from ge_transacciones c, ge_transacciones b, ge_movimientos a
   where estado = 'N'
     and reversado = 'N'
     and monto <> 0
     and b.tipo  in ('D','C')
     and a.cod_modulo = b.cod_modulo
     and a.cod_modalidad = b.cod_modalidad
     and a.cod_transaccion = b.cod_transaccion
     and b.ve_cliente = 'S'
     and a.cod_mod_padre = c.cod_modulo
     and a.cod_mad_padre = c.cod_modalidad
     and a.cod_tra_padre = c.cod_transaccion
     and not exists (select 0 from ah_retenciones x
                      where x.nro_cuenta = a.nro_cuenta
                        and x.nro_documento = a.nro_documento
                        and x.cod_retencion = a.cod_retencion
                        and x.fec_final = a.fec_fin_retencion
                        and x.liberado = 'N')
   union
  select a.nro_cuenta, fecha, fec_valor, nro_documento, c.descripcion des_tra_padre, c.abreviatura abr_tra_padre,
         b.tipo cod_tip_movimiento, monto, hora, nro_secuencia, a.fec_insercion, a.cod_tra_padre, a.cod_persona,
         a.cod_usuario, a.cod_moneda
    from ge_transacciones c, ge_transacciones b, ge_movimientos_noc a
   where estado = 'N'
     and reversado = 'N'
     and monto <> 0
     and b.tipo  in ('D','C')
     and a.cod_modulo = b.cod_modulo
     and a.cod_modalidad = b.cod_modalidad
     and a.cod_transaccion = b.cod_transaccion
     and b.ve_cliente = 'S'
     and a.cod_mod_padre = c.cod_modulo
     and a.cod_mad_padre = c.cod_modalidad
     and a.cod_tra_padre = c.cod_transaccion
     and not exists (select 0 from ah_retenciones x
                      where x.nro_cuenta = a.nro_cuenta
                        and x.nro_documento = a.nro_documento
                        and x.cod_retencion = a.cod_retencion
                        and x.fec_final = a.fec_fin_retencion
                        and x.liberado = 'N');

