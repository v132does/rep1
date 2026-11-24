create or replace force view it.av_tar_deb_activaciones as
select  lpad(nvl(fua_obt_cta_ficticia(nro_cuenta, nro_bin),pag_sue.Fu_cod_cuenta(nro_cuenta)),10,'0') || -- 10- cuenta  SDBIN8TDD-1 obt cta ficticia
        rpad(fue_obt_des_refcodes('TIP_TAR_DEBITO',tip_tar_debito),6,' ')|| -- 6-Codigo de Formato de Embozado
        adherente || -- 2
        lpad(nro_emision, 2, '0') registro,  -- nro de emision 2
        nro_cuenta nro_cuenta,
        embozado embozado ,
        adherente adherente,
        nro_emision nro_emision,
        cod_persona cod_persona,
        lpad( substr( to_char( nvl(cod_ofi_origen, cod_oficina ) ), 1, 2 ), 2, '0' ) tip_tarjeta,
        fec_envio,
        decode(tip_envio, 'R', lpad( substr( to_char( nvl(cod_ofi_origen, cod_oficina ) ), 1, 2 ), 2, '0' ) ) cod_ofi_origen,
        decode(cod_moneda, pag_gen.fu_obt_mon_local, '00', '01' ) cod_mon_numerico,
        cod_modalidad,
        fec_entrega fec_entrega,
        fec_activacion  fec_activacion,
        cod_ent_procesadora,
        fila
   from (select t.nro_cuenta, t.embozado, t.adherente, t.nro_emision, t.cod_persona, t.cod_ofi_origen,
                t.fec_envio, t.tip_envio, t.fec_entrega, t.fec_activacion, t.rowid fila,
                decode(c.cod_moneda, pag_gen.fu_obt_mon_local, '0', '2') mon,
                c.cod_oficina, c.cod_modalidad, c.cod_moneda, t.cod_ent_procesadora, e.descripcion,
                p.tipo tip_persona, t.tip_tar_debito, t.nro_bin
           from ba_personas p, ah_tar_debitos t, cc_cta_corrientes c, ba_direcciones b, ge_entes e
          where t.cod_est_solicitud IN (12, 14)     --- ENTREGADO AL CLIENTE
            and c.nro_cuenta = t.nro_cuenta
            and t.cod_ent_procesadora = e.cod_ente
            and c.estado IN ('N', 'A', 'I','S')
            and p.cod_persona = t.cod_persona
            and t.cod_persona = b.cod_persona
            and t.referencia = b.cod_direccion
            and t.tip_envio = 'D'
            and e.tipo = 'TA'
          union all
         select t.nro_cuenta, t.embozado, t.adherente, t.nro_emision, t.cod_persona, t.cod_ofi_origen,
                t.fec_envio, t.tip_envio, t.fec_entrega, t.fec_activacion, t.rowid fila,
                decode(c.cod_moneda, pag_gen.fu_obt_mon_local, '0', '2') mon,
                c.cod_oficina, c.cod_modalidad, c.cod_moneda, t.cod_ent_procesadora, e.descripcion, p.tipo,
                t.tip_tar_debito, t.nro_bin
           from ba_personas p, ah_tar_debitos t, cc_cta_corrientes c, ge_dir_retenciones r, ge_entes e
          where t.cod_est_solicitud IN (12, 14)     --- ENTREGADO AL CLIENTE
            and c.nro_cuenta = t.nro_cuenta
            and t.cod_ent_procesadora = e.cod_ente
            and c.estado IN ('N', 'A', 'I','S')  ---- lo de abajo para traer descripcion de direccion envio
            and p.cod_persona = t.cod_persona
            and r.cod_dir_retencion = t.referencia
            and t.tip_envio = 'R'
            and e.tipo = 'TA'
          union all
         select t.nro_cuenta, t.embozado,  t.adherente, t.nro_emision,t.cod_persona, t.cod_ofi_origen,
                t.fec_envio, t.tip_envio, t.fec_entrega, t.fec_activacion, t.rowid fila,
                decode(c.cod_moneda, pag_gen.fu_obt_mon_local, '1', '3') mon,
                c.cod_oficina, c.cod_modalidad, c.cod_moneda, t.cod_ent_procesadora, e.descripcion, p.tipo,
                t.tip_tar_debito, t.nro_bin
           from ba_personas p, ah_tar_debitos t, ah_cta_vistas c, ba_direcciones b, ge_entes e
          where t.cod_est_solicitud IN (12, 14)     --- ENTREGADO AL CLIENTE
            and c.nro_cuenta = t.nro_cuenta
            and t.cod_ent_procesadora = e.cod_ente
            and c.estado IN ('N', 'A', 'I','S')
            and p.cod_persona = t.cod_persona
            and t.cod_persona = b.cod_persona
            and t.referencia = b.cod_direccion
            and t.tip_envio = 'D'
            and e.tipo = 'TA'
          union all
         select t.nro_cuenta, t.embozado, t.adherente, t.nro_emision, t.cod_persona, t.cod_ofi_origen,
                t.fec_envio, t.tip_envio, t.fec_entrega, t.fec_activacion, t.rowid fila,
                decode(c.cod_moneda, pag_gen.fu_obt_mon_local, '1', '3') mon,
                c.cod_oficina, c.cod_modalidad, c.cod_moneda, t.cod_ent_procesadora, e.descripcion, p.tipo,
                t.tip_tar_debito, t.nro_bin
           from ba_personas p, ah_tar_debitos t, ah_cta_vistas c, ge_dir_retenciones r, ge_entes e
          where t.cod_est_solicitud IN (12, 14)     --- ENTREGADO AL CLIENTE
            and c.nro_cuenta = t.nro_cuenta
            and t.cod_ent_procesadora = e.cod_ente
            and c.estado IN ('N', 'A', 'I','S')  ---- lo de abajo para traer descripcion de direccion envio
            and p.cod_persona = t.cod_persona
            and r.cod_dir_retencion = t.referencia
            and t.tip_envio = 'R'
            and e.tipo = 'TA'
        )
;

