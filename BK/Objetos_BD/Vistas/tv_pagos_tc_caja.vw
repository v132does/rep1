create or replace force view it.tv_pagos_tc_caja as
select m.nro_caja,
       decode(c.tipo, 'H', 'HUMANA', 'S', 'AUTOSERVICIO', 'A', 'ATM') TIPO_CAJA,
       nombre responsable,
       ba.cod_persona,
       ba.nro_documento,
       ba.cod_tip_documento,
       bt.descripcion,
       fue_obt_des_oficina(m.cod_ofi_origen) des_ofi_origen,
       m.cod_ofi_origen as cod_oficina,
       fecha,
       cod_moneda,
       monto,
       substr(concepto, 20, 25) tarjeta,
       concepto,
       cod_tra_padre,
       m.nro_cuenta,
       hora,
       m.cod_modalidad tip_tarjeta,
       fug_obt_des_modalidad(m.cod_modalidad) des_tarjeta
  from ta_movimientos_his m, cj_cajas c, ba_usuarios u, ba_personas ba, ba_tip_documentos bt
 where cod_tra_padre = 250
   and ba.cod_persona = fug_obt_cli_principal(m.nro_cuenta)
   and cod_modulo = 5
   and bt.cod_tip_documento = ba.cod_tip_documento
   and m.nro_caja is not null
   and monto > 0
   and reversado = 'N'
   and m.usu_insercion <> 'HBANK'
   and m.cod_usuario <> 'HBANK'
   and c.nro_caja = m.nro_caja
   and u.cod_usuario = c.cod_usuario
union
select m.nro_caja,
       decode(c.tipo, 'H', 'HUMANA', 'S', 'AUTOSERVICIO', 'A', 'ATM') TIPO_CAJA,
       nombre responsable,
       ba.cod_persona,
       ba.nro_documento,
       ba.cod_tip_documento,
       bt.descripcion,
       fue_obt_des_oficina(m.cod_ofi_origen) des_ofi_origen,
       m.cod_ofi_origen as cod_oficina,
       fecha,
       cod_moneda,
       monto,
       substr(concepto, 20, 25) tarjeta,
       concepto,
       cod_tra_padre,
       m.nro_cuenta,
       hora,
       m.cod_modalidad tip_tarjeta,
       fug_obt_des_modalidad(m.cod_modalidad) des_tarjeta
  from ge_movimientos m, cj_cajas c, ba_usuarios u, ba_personas ba, ba_tip_documentos bt
 where cod_tra_padre = 250
   and bt.cod_tip_documento = ba.cod_tip_documento
   and ba.cod_persona = fug_obt_cli_principal(m.nro_cuenta)
   and cod_modulo = 5
   and m.nro_caja is not null
   and monto > 0
   and reversado = 'N'
   and m.usu_insercion <> 'HBANK'
   and m.cod_usuario <> 'HBANK'
   and c.nro_caja = m.nro_caja
   and u.cod_usuario = c.cod_usuario;

