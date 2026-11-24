create or replace force view it.lv_cam_hb as
select p.cod_tip_operacion cod_tip_operacion,
       t.descripcion descripcion,
       fug_emp_enmascara(p.cod_persona, p.cod_persona) cod_persona,
       fug_emp_enmascara(p.cod_persona, b.nom_completo) nom_completo,
       fug_emp_enmascara(p.cod_persona, b.nro_documento) nro_documento,
       td.abreviatura tip_documento,
       p.fec_liquidacion fec_liquidacion,
       fug_emp_enmascara(p.cod_persona, deb.nro_cuenta) nro_cta_debito,
       fug_emp_enmascara(p.cod_persona,cre.nro_cuenta) nro_cta_credito,
       p.cod_moneda cod_moneda,
       p.monto,
       p.nro_diario nro_nro_operacion_hb,
       p.nro_operacion nro_operacion,
       t.cod_modalidad cod_tip_cambio,
       m.descripcion des_tip_cambio,
       p.cotizacion cotizacion,
       g.cod_oficina ofi_cliente,
       fue_obt_des_oficina(g.cod_oficina) des_ofi_cliente,
       g.cod_usu_oficial gestor,
       fue_obt_nom_usuario(g.cod_usu_oficial) nom_gestor,
       u.cod_oficina cod_ofi_gestor,
       fue_obt_des_oficina(u.cod_oficina) des_ofi_gestor,
       fug_obt_des_segmento(g.cod_seg_cliente) area_negocio,
       case
         when b.tipo = 'J' then
          'JURÍDICA'
         when b.tipo = 'F' then
          'FÍSICA'
       end as tip_persona

  from lc_movimientos_his l,
       lc_ope_pendientes  p,
       lc_tip_operaciones t,
       ba_personas        b,
       ba_tip_documentos td,
       ge_clientes        g,
       ba_usuarios        u,
       ge_modalidades     m,
       (select a.fecha, a.hora, a.cod_usuario, a.nro_secuencia, a.nro_cuenta, a.nro_documento, a.fec_insercion from ah_movimientos_his a where a.cod_transaccion = 503 and a.nro_secuencia = 1 union
        select c.fecha, c.hora, c.cod_usuario, c.nro_secuencia, c.nro_cuenta, c.nro_documento, c.fec_insercion from cc_movimientos_his c where c.cod_transaccion = 503 and c.nro_secuencia = 1) deb,
       (select a.fecha, a.hora, a.cod_usuario, a.nro_secuencia, a.nro_cuenta, a.nro_documento, a.fec_insercion from ah_movimientos_his a where a.cod_transaccion = 602 and a.nro_secuencia = 2 union
        select c.fecha, c.hora, c.cod_usuario, c.nro_secuencia, c.nro_cuenta, c.nro_documento, c.fec_insercion from cc_movimientos_his c where c.cod_transaccion = 602 and c.nro_secuencia = 2) cre
 where deb.nro_documento = p.nro_operacion
   and cre.nro_documento = p.nro_operacion
   and l.nro_documento = p.nro_operacion
   and deb.nro_cuenta is not null
   and cre.nro_cuenta is not null
   and l.reversado = 'N'
   and deb.fecha = cre.fecha
   and deb.hora = cre.hora
   and deb.cod_usuario = cre.cod_usuario
   and (deb.fec_insercion = p.fec_liquidacion or deb.cod_usuario = p.cod_usu_liquidacion)
   and (cre.fec_insercion = p.fec_liquidacion or deb.cod_usuario = p.cod_usu_liquidacion)
   and l.cod_usuario = p.cod_usu_liquidacion
   and p.cod_tip_operacion = t.cod_tip_operacion
   and p.cod_persona = b.cod_persona
   and b.cod_persona = g.cod_persona
   and b.cod_tip_documento = td.cod_tip_documento
   and g.cod_usu_oficial = u.cod_usuario
   and m.cod_modulo = t.cod_modulo
   and m.cod_modalidad = t.cod_modalidad
   and p.ope_homebanking = 'S'
   and p.cod_usu_liquidacion = 'HBANK'
union all
select p.cod_tip_operacion cod_tip_operacion,
       t.descripcion descripcion,
       fug_emp_enmascara(p.cod_persona, p.cod_persona) cod_persona,
       fug_emp_enmascara(p.cod_persona, b.nom_completo) nom_completo,
       fug_emp_enmascara(p.cod_persona, b.nro_documento) nro_documento,
       td.abreviatura tip_documento,
       p.fec_liquidacion fec_liquidacion,
       fug_emp_enmascara(p.cod_persona, deb.nro_cuenta) nro_cta_debito,
       fug_emp_enmascara(p.cod_persona,cre.nro_cuenta) nro_cta_credito,
       p.cod_moneda cod_moneda,
       p.monto,
       p.nro_diario nro_nro_operacion_hb,
       p.nro_operacion nro_operacion,
       t.cod_modalidad cod_tip_cambio,
       m.descripcion des_tip_cambio,
       p.cotizacion cotizacion,
       g.cod_oficina ofi_cliente,
       fue_obt_des_oficina(g.cod_oficina) des_ofi_cliente,
       g.cod_usu_oficial gestor,
       fue_obt_nom_usuario(g.cod_usu_oficial) nom_gestor,
       u.cod_oficina cod_ofi_gestor,
       fue_obt_des_oficina(u.cod_oficina) des_ofi_gestor,
       fug_obt_des_segmento(g.cod_seg_cliente),
       case
         when b.tipo = 'J' then
          'JURÍDICA'
         when b.tipo = 'F' then
          'FÍSICA'
       end as tip_persona

  from lc_ope_pendientes  p,
       lc_tip_operaciones t,
       ba_personas        b,
       ba_tip_documentos td,
       ge_clientes        g,
       ba_usuarios        u,
       ge_modalidades     m,
       (select a.fecha, a.hora, a.cod_usuario, a.nro_secuencia, a.nro_cuenta, a.nro_documento, a.fec_insercion from ah_movimientos_his a where a.cod_transaccion = 503 and a.nro_secuencia = 1 union
        select c.fecha, c.hora, c.cod_usuario, c.nro_secuencia, c.nro_cuenta, c.nro_documento, c.fec_insercion from cc_movimientos_his c where c.cod_transaccion = 503 and c.nro_secuencia = 1) deb,
       (select a.fecha, a.hora, a.cod_usuario, a.nro_secuencia, a.nro_cuenta, a.nro_documento, a.fec_insercion from ah_movimientos_his a where a.cod_transaccion = 602 and a.nro_secuencia = 2 union
        select c.fecha, c.hora, c.cod_usuario, c.nro_secuencia, c.nro_cuenta, c.nro_documento, c.fec_insercion from cc_movimientos_his c where c.cod_transaccion = 602 and c.nro_secuencia = 2) cre
 where deb.nro_documento = p.nro_operacion
   and cre.nro_documento = p.nro_operacion
   and deb.fec_insercion = p.fec_liquidacion
   and cre.fec_insercion = p.fec_liquidacion
   and deb.nro_cuenta is not null
   and cre.nro_cuenta is not null
   and deb.fecha = cre.fecha
   and deb.hora = cre.hora
   and deb.cod_usuario = cre.cod_usuario
   and p.cod_tip_operacion = t.cod_tip_operacion
   and p.cod_persona = b.cod_persona
   and b.cod_persona = g.cod_persona
   and b.cod_tip_documento = td.cod_tip_documento
   and g.cod_usu_oficial = u.cod_usuario
   and m.cod_modulo = t.cod_modulo
   and m.cod_modalidad = t.cod_modalidad
   and p.ope_homebanking = 'S'
   and p.cod_usu_liquidacion = 'HBANK'
   and not exists (select 1 from lc_movimientos_his l where l.nro_documento = p.nro_operacion and l.fecha = p.fec_operacion);

