create or replace force view it.gv_ctas_canceladas as
select cc.nro_cuenta, cc.estado, 'CANCELADA' des_est_cta,
       per.nro_documento, c.cod_persona, per.nom_completo nom_persona,
       cc.cod_ente, decode(cc.cod_ente, null, null, en.descripcion) nom_ente,
       en.cod_persona cod_per_ente,
       cli.cod_usu_oficial, us.nombre nom_gestor, cc.fec_cam_estado fecha,
       cc.cod_cau_cancelacion, ca.descripcion desc_causa_cancel,
       m.cod_usuario cod_usu_cancel, um.nombre nom_usu_cancel, cc.sal_total,
       cc.sal_retenido, cc.sal_bloqueado, cc.cod_oficina
  from cc_movimientos_his m, ge_cta_clientes c, cc_cta_corrientes cc, ge_clientes cli, ba_personas per,
       ge_entes en, ba_usuarios us, ge_causales ca, ba_usuarios um
 where m.nro_cuenta = cc.nro_cuenta
   and c.nro_cuenta = cc.nro_cuenta
   and c.relacion = 'P'
   and per.cod_persona=cli.cod_persona
   and c.cod_persona = cli.cod_persona
   and cc.estado = 'C'
   and m.cod_transaccion = 406/*Cta Cancelada*/
   and en.cod_ente(+) = cc.cod_ente
   and us.cod_usuario = cli.cod_usu_oficial
   and ca.cod_causa(+) = cc.cod_cau_cancelacion
   and um.cod_usuario = m.cod_usuario
union
select cc.nro_cuenta, cc.estado, 'CANCELADA' des_est_cta,
       per.nro_documento, c.cod_persona, per.nom_completo nom_persona,
       cc.cod_ente, decode(cc.cod_ente, null, null, en.descripcion) nom_ente,
       en.cod_persona cod_per_ente,
       cli.cod_usu_oficial, us.nombre nom_gestor, cc.fec_cam_estado fecha,
       cc.cod_cau_cancelacion, ca.descripcion desc_causa_cancel,
       m.cod_usuario cod_usu_cancel, um.nombre nom_usu_cancel, cc.sal_total,
       cc.sal_retenido, cc.sal_bloqueado, cc.cod_oficina
  from ah_movimientos_his m, ge_cta_clientes c, ah_cta_vistas cc, ge_clientes cli, ba_personas per,
       ge_entes en, ba_usuarios us, ge_causales ca, ba_usuarios um
 where m.nro_cuenta = cc.nro_cuenta
   and c.nro_cuenta = cc.nro_cuenta
   and c.relacion = 'P'
   and per.cod_persona=cli.cod_persona
   and c.cod_persona = cli.cod_persona
   and cc.estado = 'C'
   and m.cod_transaccion = 406/*Cta Cancelada*/
   and en.cod_ente(+) = cc.cod_ente
   and us.cod_usuario = cli.cod_usu_oficial
   and ca.cod_causa(+) = cc.cod_cau_cancelacion
   and um.cod_usuario = m.cod_usuario;

