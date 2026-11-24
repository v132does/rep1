create or replace force view it.gv_ctas_nomina_cancel as
select cc.nro_cuenta,per.nro_documento, c.cod_persona, it.fue_obt_nom_persona(c.cod_persona) nom_persona,
       cc.cod_ente, it.fue_obt_nom_ente(cc.cod_ente) nom_ente, (select e.cod_persona
                                                                  from it.ge_entes e where e.cod_ente = cc.cod_ente) cod_per_ente,
       cli.cod_usu_oficial, it.fuy_obt_nom_usuario(cli.cod_usu_oficial) nom_gestor, cc.fec_cam_estado fecha,
        cc.hor_ult_movimiento hora,
       cc.cod_cau_cancelacion, it.fug_obt_des_causa(cc.cod_cau_cancelacion) desc_causa_cancel,
       m.cod_usuario cod_usu_cancel, it.fuy_obt_nom_usuario(m.cod_usuario) nom_usu_cancel
  from it.cc_movimientos_his m, it.ge_cta_clientes c, it.cc_cta_corrientes cc, it.ge_clientes cli, it.ba_personas per
 where m.nro_cuenta = cc.nro_cuenta
   and c.nro_cuenta = cc.nro_cuenta
   and c.relacion = 'P'
   and per.cod_persona=cli.cod_persona
   and c.cod_persona = cli.cod_persona
   and cc.cod_ente is not null
   and cc.estado = 'C'
   and m.cod_transaccion = 406/*Cta Cancelada*/

union

select cc.nro_cuenta,per.nro_documento, c.cod_persona, it.fue_obt_nom_persona(c.cod_persona) nom_persona,
       cc.cod_ente, it.fue_obt_nom_ente(cc.cod_ente) nom_ente, (select e.cod_persona
                                                                  from it.ge_entes e where e.cod_ente = cc.cod_ente) cod_per_ente,
       cli.cod_usu_oficial, it.fuy_obt_nom_usuario(cli.cod_usu_oficial) nom_gestor, cc.fec_cam_estado fecha,
       cc.hor_ult_movimiento hora,
       cc.cod_cau_cancelacion, it.fug_obt_des_causa(cc.cod_cau_cancelacion) desc_causa_cancel,
       m.cod_usuario cod_usu_cancel, it.fuy_obt_nom_usuario(m.cod_usuario) nom_usu_cancel
  from it.ah_movimientos_his m, it.ge_cta_clientes c, it.ah_cta_vistas cc, it.ge_clientes cli,it.ba_personas per
 where m.nro_cuenta = cc.nro_cuenta
   and c.nro_cuenta = cc.nro_cuenta
   and c.relacion = 'P'
   and per.cod_persona=cli.cod_persona
   and c.cod_persona = cli.cod_persona
   and cc.cod_ente is not null
   and cc.estado = 'C'
   and m.cod_transaccion = 406/*Cta Cancelada*/;

