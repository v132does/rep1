create or replace force view it.gv_estado_cta as
select cc.cod_oficina, cc.nro_cuenta, cc.estado, it.fug_obt_des_est_cta(cc.cod_modulo, cc.cod_modalidad, cc.estado) des_est_cta,
       per.nro_documento, c.cod_persona, it.fue_obt_nom_persona(c.cod_persona) nom_persona,
       cc.cod_ente, decode(cc.cod_ente, null, null, it.fue_obt_nom_ente(cc.cod_ente)) nom_ente,
       (select e.cod_persona from it.ge_entes e where e.cod_ente = cc.cod_ente) cod_per_ente,
       cli.cod_usu_oficial, it.fuy_obt_nom_usuario(cli.cod_usu_oficial) nom_gestor, cc.fec_cam_estado fecha,
       cc.cod_cau_cancelacion, initcap(it.fug_obt_des_causa(cc.cod_cau_cancelacion)) desc_causa_cancel,
       cc.sal_total, cc.sal_retenido, cc.sal_bloqueado
  from it.ge_cta_clientes c, it.cc_cta_corrientes cc, it.ge_clientes cli, it.ba_personas per
 where c.nro_cuenta = cc.nro_cuenta
   and c.relacion = 'P'
   and per.cod_persona=cli.cod_persona
   and c.cod_persona = cli.cod_persona

union

select cc.cod_oficina, cc.nro_cuenta, cc.estado, it.fug_obt_des_est_cta(cc.cod_modulo, cc.cod_modalidad, cc.estado) des_est_cta,
       per.nro_documento, c.cod_persona, it.fue_obt_nom_persona(c.cod_persona) nom_persona,
       cc.cod_ente, decode(cc.cod_ente, null, null, it.fue_obt_nom_ente(cc.cod_ente)) nom_ente,
       (select e.cod_persona from it.ge_entes e where e.cod_ente = cc.cod_ente) cod_per_ente,
       cli.cod_usu_oficial, it.fuy_obt_nom_usuario(cli.cod_usu_oficial) nom_gestor, cc.fec_cam_estado fecha,
       cc.cod_cau_cancelacion, initcap(it.fug_obt_des_causa(cc.cod_cau_cancelacion)) desc_causa_cancel,
       cc.sal_total, cc.sal_retenido, cc.sal_bloqueado
  from it.ge_cta_clientes c, it.ah_cta_vistas cc, it.ge_clientes cli,it.ba_personas per
 where c.nro_cuenta = cc.nro_cuenta
   and c.relacion = 'P'
   and per.cod_persona=cli.cod_persona
   and c.cod_persona = cli.cod_persona;

