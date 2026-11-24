create or replace view it.gv_ext_legales as
select m.nro_cuenta,
       p.nom_completo,
       m.fecha,
       m.fec_valor,
       m.hora,
       m.cod_moneda,
       m.nro_documento,
       m.concepto,
       m.cod_tra_padre||'-'||tp.descripcion Tra_Padre,
       m.cod_transaccion||'-'||th.descripcion Tra_Hijo,
       r.significado estado,
       m.reversado,
       m.nro_caja,
       decode(th.tipo, 'D', nvl(m.monto, 0), 0) mto_debito,
       decode(th.tipo, 'C', nvl(m.monto, 0), 0) mto_Credito,
       (select decode(m.cod_transaccion,503,'Transf. enviada a la ',602,'Transf. recibida de la ')||'Cta: '||ch.nro_cuenta||' - Titular: '||ps.nom_completo||' - Cédula: '||ps.nro_documento
          from cc_movimientos_his ch, ge_cta_clientes ct, ge_clientes l, ba_personas ps
         where ch.nro_cuenta = ct.nro_cuenta
           and ct.cod_persona = l.cod_persona
           and l.cod_persona = ps.cod_persona
           and ch.fecha = m.fecha
           and ch.hora = m.hora
           and ch.cod_usuario = m.cod_usuario
           and ct.relacion = 'P'
           and l.cod_seg_cliente != fug_obt_pardinamico('SEG_FUNCIONARIOS')
           and ch.cod_tra_padre in (309,388)
           and ((m.cod_transaccion = 503 and ch.cod_transaccion = 602) or (m.cod_transaccion = 602 and ch.cod_transaccion = 503))
        union all
        select decode(m.cod_transaccion,503,'Transf. enviada a la ',602,'Transf. recibida de la ')||'Cta: '||ah.nro_cuenta||' - Titular: '||ps.nom_completo||' - Cédula: '||ps.nro_documento
          from ah_movimientos_his ah, ge_cta_clientes ct, ge_clientes l, ba_personas ps
         where ah.nro_cuenta = ct.nro_cuenta
           and ct.cod_persona = l.cod_persona
           and l.cod_persona = ps.cod_persona
           and ah.fecha = m.fecha
           and ah.hora = m.hora
           and ah.cod_usuario = m.cod_usuario
           and ct.relacion = 'P'
           and l.cod_seg_cliente != fug_obt_pardinamico('SEG_FUNCIONARIOS')
           and ah.cod_tra_padre in (309,388)
           and ((m.cod_transaccion = 503 and ah.cod_transaccion = 602) or (m.cod_transaccion = 602 and ah.cod_transaccion = 503))
        union all
        select decode(m.cod_transaccion,503,'Transf. enviada a la ',602,'Transf. recibida de la ')||'Cta: '||md.nro_cuenta||' - Titular: '||ps.nom_completo||' - Cédula: '||ps.nro_documento
          from ge_movimientos md, ge_cta_clientes ct, ge_clientes l, ba_personas ps
         where md.nro_cuenta = ct.nro_cuenta
           and ct.cod_persona = l.cod_persona
           and l.cod_persona = ps.cod_persona
           and md.fecha = m.fecha
           and md.hora = m.hora
           and md.cod_usuario = m.cod_usuario
           and ct.relacion = 'P'
           and l.cod_seg_cliente != fug_obt_pardinamico('SEG_FUNCIONARIOS')
           and md.cod_tra_padre in (309,388)
           and md.cod_modulo in (3,4)
           and ((m.cod_transaccion = 503 and md.cod_transaccion = 602) or (m.cod_transaccion = 602 and md.cod_transaccion = 503))) transf_int
  from cc_movimientos_his m, ge_cta_clientes c, ge_clientes cl, ba_personas p, ge_transacciones th, ge_transacciones tp, ba_cod_referencias r
 where m.nro_cuenta = c.nro_cuenta

   and c.cod_persona = cl.cod_persona

   and cl.cod_persona = p.cod_persona

   and m.cod_mod_padre = tp.cod_modulo
   and m.cod_mad_padre = tp.cod_modalidad
   and m.cod_tra_padre = tp.cod_transaccion

   and m.cod_modulo = th.cod_modulo
   and m.cod_modalidad = th.cod_modalidad
   and m.cod_transaccion = th.cod_transaccion

   and m.estado = r.val_minimo

   and r.dominio = 'EST_MOVIMIENTO'

   and c.relacion = 'P'

   and cl.cod_seg_cliente != fug_obt_pardinamico('SEG_FUNCIONARIOS')

   and th.ve_cliente = 'S'

   and th.tipo in ('C', 'D')
union all
select m.nro_cuenta,
       p.nom_completo,
       m.fecha,
       m.fec_valor,
       m.hora ,
       m.cod_moneda,
       m.nro_documento,
       m.concepto,
       m.cod_tra_padre||'-'||tp.descripcion Tra_Padre,
       m.cod_transaccion||'-'||th.descripcion tra_Hijo,
       r.significado estado,
       m.reversado,
       m.nro_caja,
       decode(th.tipo, 'D', nvl(m.monto, 0), 0) mto_debito,
       decode(th.tipo, 'C', nvl(m.monto, 0), 0) mto_credito,
       (select decode(m.cod_transaccion,503,'Transf. enviada a la ',602,'Transf. recibida de la ')||'Cta: '||ch.nro_cuenta||' - Titular: '||ps.nom_completo||' - Cédula: '||ps.nro_documento
          from cc_movimientos_his ch, ge_cta_clientes ct, ge_clientes l, ba_personas ps
         where ch.nro_cuenta = ct.nro_cuenta
           and ct.cod_persona = l.cod_persona
           and l.cod_persona = ps.cod_persona
           and ch.fecha = m.fecha
           and ch.hora = m.hora
           and ch.cod_usuario = m.cod_usuario
           and ct.relacion = 'P'
           and l.cod_seg_cliente != fug_obt_pardinamico('SEG_FUNCIONARIOS')
           and ch.cod_tra_padre in (309,388)
           and ((m.cod_transaccion = 503 and ch.cod_transaccion = 602) or (m.cod_transaccion = 602 and ch.cod_transaccion = 503))
        union all
        select decode(m.cod_transaccion,503,'Transf. enviada a la ',602,'Transf. recibida de la ')||'Cta: '||ah.nro_cuenta||' - Titular: '||ps.nom_completo||' - Cédula: '||ps.nro_documento
          from ah_movimientos_his ah, ge_cta_clientes ct, ge_clientes l, ba_personas ps
         where ah.nro_cuenta = ct.nro_cuenta
           and ct.cod_persona = l.cod_persona
           and l.cod_persona = ps.cod_persona
           and ah.fecha = m.fecha
           and ah.hora = m.hora
           and ah.cod_usuario = m.cod_usuario
           and ct.relacion = 'P'
           and l.cod_seg_cliente != fug_obt_pardinamico('SEG_FUNCIONARIOS')
           and ah.cod_tra_padre in (309,388)
           and ((m.cod_transaccion = 503 and ah.cod_transaccion = 602) or (m.cod_transaccion = 602 and ah.cod_transaccion = 503))
        union all
        select decode(m.cod_transaccion,503,'Transf. enviada a la ',602,'Transf. recibida de la ')||'Cta: '||md.nro_cuenta||' - Titular: '||ps.nom_completo||' - Cédula: '||ps.nro_documento
          from ge_movimientos md, ge_cta_clientes ct, ge_clientes l, ba_personas ps
         where md.nro_cuenta = ct.nro_cuenta
           and ct.cod_persona = l.cod_persona
           and l.cod_persona = ps.cod_persona
           and md.fecha = m.fecha
           and md.hora = m.hora
           and md.cod_usuario = m.cod_usuario
           and ct.relacion = 'P'
           and l.cod_seg_cliente != fug_obt_pardinamico('SEG_FUNCIONARIOS')
           and md.cod_tra_padre in (309,388)
           and md.cod_modulo in (3,4)
           and ((m.cod_transaccion = 503 and md.cod_transaccion = 602) or (m.cod_transaccion = 602 and md.cod_transaccion = 503))) transf_int
  from ah_movimientos_his m, ge_cta_clientes c, ge_clientes cl, ba_personas p, ge_transacciones th, ge_transacciones tp, ba_cod_referencias r
 where m.nro_cuenta = c.nro_cuenta

   and c.cod_persona = cl.cod_persona

   and cl.cod_persona = p.cod_persona

   and m.cod_mod_padre = tp.cod_modulo
   and m.cod_mad_padre = tp.cod_modalidad
   and m.cod_tra_padre = tp.cod_transaccion

   and m.cod_modulo = th.cod_modulo
   and m.cod_modalidad = th.cod_modalidad
   and m.cod_transaccion = th.cod_transaccion

   and m.estado = r.val_minimo

   and r.dominio = 'EST_MOVIMIENTO'

   and c.relacion = 'P'

   and cl.cod_seg_cliente != fug_obt_pardinamico('SEG_FUNCIONARIOS')

   and th.ve_cliente = 'S'

   and th.tipo in ('C', 'D')
union all
select m.nro_cuenta,
       p.nom_completo,
       m.fecha,
       m.fec_valor,
       m.hora,
       m.cod_moneda,
       m.nro_documento,
       m.concepto,
       m.cod_tra_padre||'-'||tp.descripcion Tra_Padre,
       m.cod_transaccion||'-'||th.descripcion Tra_Hijo,
       r.significado estado,
       m.reversado,
       m.nro_caja,
       decode(th.tipo, 'D', nvl(m.monto, 0), 0) mto_debito,
       decode(th.tipo, 'C', nvl(m.monto, 0), 0) mto_credito,
       (select decode(m.cod_transaccion,503,'Transf. enviada a la ',602,'Transf. recibida de la ')||'Cta: '||ch.nro_cuenta||' - Titular: '||ps.nom_completo||' - Cédula: '||ps.nro_documento
          from cc_movimientos_his ch, ge_cta_clientes ct, ge_clientes l, ba_personas ps
         where ch.nro_cuenta = ct.nro_cuenta
           and ct.cod_persona = l.cod_persona
           and l.cod_persona = ps.cod_persona
           and ch.fecha = m.fecha
           and ch.hora = m.hora
           and ch.cod_usuario = m.cod_usuario
           and ct.relacion = 'P'
           and l.cod_seg_cliente != fug_obt_pardinamico('SEG_FUNCIONARIOS')
           and ch.cod_tra_padre in (309,388)
           and ((m.cod_transaccion = 503 and ch.cod_transaccion = 602) or (m.cod_transaccion = 602 and ch.cod_transaccion = 503))
        union all
        select decode(m.cod_transaccion,503,'Transf. enviada a la ',602,'Transf. recibida de la ')||'Cta: '||ah.nro_cuenta||' - Titular: '||ps.nom_completo||' - Cédula: '||ps.nro_documento
          from ah_movimientos_his ah, ge_cta_clientes ct, ge_clientes l, ba_personas ps
         where ah.nro_cuenta = ct.nro_cuenta
           and ct.cod_persona = l.cod_persona
           and l.cod_persona = ps.cod_persona
           and ah.fecha = m.fecha
           and ah.hora = m.hora
           and ah.cod_usuario = m.cod_usuario
           and ct.relacion = 'P'
           and l.cod_seg_cliente != fug_obt_pardinamico('SEG_FUNCIONARIOS')
           and ah.cod_tra_padre in (309,388)
           and ((m.cod_transaccion = 503 and ah.cod_transaccion = 602) or (m.cod_transaccion = 602 and ah.cod_transaccion = 503))
        union all
        select decode(m.cod_transaccion,503,'Transf. enviada a la ',602,'Transf. recibida de la ')||'Cta: '||md.nro_cuenta||' - Titular: '||ps.nom_completo||' - Cédula: '||ps.nro_documento
          from ge_movimientos md, ge_cta_clientes ct, ge_clientes l, ba_personas ps
         where md.nro_cuenta = ct.nro_cuenta
           and ct.cod_persona = l.cod_persona
           and l.cod_persona = ps.cod_persona
           and md.fecha = m.fecha
           and md.hora = m.hora
           and md.cod_usuario = m.cod_usuario
           and ct.relacion = 'P'
           and l.cod_seg_cliente != fug_obt_pardinamico('SEG_FUNCIONARIOS')
           and md.cod_tra_padre in (309,388)
           and md.cod_modulo in (3,4)
           and ((m.cod_transaccion = 503 and md.cod_transaccion = 602) or (m.cod_transaccion = 602 and md.cod_transaccion = 503)))

  from ge_movimientos m, ge_cta_clientes c, ge_clientes cl, ba_personas p, ge_transacciones th, ge_transacciones tp, ba_cod_referencias r
 where m.nro_cuenta = c.nro_cuenta

   and c.cod_persona = cl.cod_persona

   and cl.cod_persona = p.cod_persona

   and m.cod_mod_padre = tp.cod_modulo
   and m.cod_mad_padre = tp.cod_modalidad
   and m.cod_tra_padre = tp.cod_transaccion

   and m.cod_modulo = th.cod_modulo
   and m.cod_modalidad = th.cod_modalidad
   and m.cod_transaccion = th.cod_transaccion

   and m.cod_modulo in (3,4)

   and m.estado = r.val_minimo

   and r.dominio = 'EST_MOVIMIENTO'

   and c.relacion = 'P'

   and cl.cod_seg_cliente != fug_obt_pardinamico('SEG_FUNCIONARIOS')

   and th.ve_cliente = 'S'

   and th.tipo in ('C', 'D');
