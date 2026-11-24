create or replace force view it.gv_cta_ult_movimiento as
select cc.cod_oficina cod_oficina,
       cc.nro_cuenta nro_cuenta,
       cc.estado estado,
       it.fug_obt_des_est_cta(cc.cod_modulo, cc.cod_modalidad, cc.estado) des_est_cta,
       per.nro_documento nro_documento,
       c.cod_persona cod_persona,
       it.fue_obt_nom_persona(c.cod_persona) nom_persona,
       cc.cod_ente cod_ente,
       decode(cc.cod_ente, null, null, it.fue_obt_nom_ente(cc.cod_ente)) nom_ente,
       (select e.cod_persona
          from it.ge_entes e
         where e.cod_ente = cc.cod_ente) cod_per_ente,
       cli.cod_usu_oficial,
       it.fuy_obt_nom_usuario(cli.cod_usu_oficial) nom_gestor,
       cc.fec_cam_estado fec_cam_estado,
       cc.cod_cau_cancelacion cod_cau_cancelacion,
       initcap(it.fug_obt_des_causa(cc.cod_cau_cancelacion)) desc_causa_cancel,
       cc.sal_total sal_total,
       cc.sal_retenido sal_retenido,
       cc.sal_bloqueado sal_bloqueado,
       cc.fec_ult_movimiento fecha ,
       cc.mto_mora importe_sobregirado,
       pai_dtm.FU_OBT_TIP_CLIENTE(per.cod_persona,cc.nro_cuenta) tip_cliente,
       to_char(pai_dtm.fu_obt_can_chequeras(cc.nro_cuenta)) campo_adicional,
       cc.cod_moneda,
       cc.cta_combinada combinada,
       cm.nro_cta_ahorro cta_combinada,
       cc.cod_sub_modalidad,
       (select max(ss.fec_proceso)
          from ge_pag_sueldos ss
         where ss.nro_cuenta = cc.nro_cuenta
           and ss.procesado = 'S'
           and ss.tipo = 'C'
           and ss.monto > 0)fec_ult_crd,
        cc.cod_modulo,
        cc.cod_modalidad
  from it.ge_cta_clientes   c,
       it.cc_cta_corrientes cc,
       it.ge_clientes       cli,
       it.ba_personas       per,
       cc_cta_combinadas cm
 where c.nro_cuenta = cc.nro_cuenta
   and cc.nro_cuenta=cm.nro_cta_cte(+)
   and c.relacion = 'P'
   and per.cod_persona = cli.cod_persona
   and c.cod_persona = cli.cod_persona
union
select cc.cod_oficina cod_oficina,
       cc.nro_cuenta nro_cuenta,
       cc.estado estado,
       it.fug_obt_des_est_cta(cc.cod_modulo, cc.cod_modalidad, cc.estado) des_est_cta,
       per.nro_documento nro_documento,
       c.cod_persona cod_persona,
       it.fue_obt_nom_persona(c.cod_persona) nom_persona,
       cc.cod_ente cod_ente,
       decode(cc.cod_ente, null, null, it.fue_obt_nom_ente(cc.cod_ente)) nom_ente,
       (select e.cod_persona
          from it.ge_entes e
         where e.cod_ente = cc.cod_ente) cod_per_ente,
       cli.cod_usu_oficial cod_usu_oficial,
       it.fuy_obt_nom_usuario(cli.cod_usu_oficial) nom_gestor,
       cc.fec_cam_estado fec_cam_estado,
       cc.cod_cau_cancelacion cod_cau_cancelacion,
       initcap(it.fug_obt_des_causa(cc.cod_cau_cancelacion)) desc_causa_cancel,
       cc.sal_total sal_total,
       cc.sal_retenido sal_retenido,
       cc.sal_bloqueado sal_bloqueado,
       cc.fec_ult_movimiento fecha,
       0 imp_sobregirado,
        pai_dtm.FU_OBT_TIP_CLIENTE(per.cod_persona,cc.nro_cuenta)tip_cliente,
       decode(cc.cod_sub_modalidad,
       6,'Aguinaldo') campo_adicional,
       cc.cod_moneda,
       cc.cta_combinada combinada,
       cm.nro_cta_cte cta_combinada,
       cc.cod_sub_modalidad,
       (select max(ss.fec_proceso)
          from ge_pag_sueldos ss
         where ss.nro_cuenta = cc.nro_cuenta
           and ss.procesado = 'S'
           and ss.tipo = 'C'
           and ss.monto > 0)fec_ult_crd ,
        cc.cod_modulo,
        cc.cod_modalidad
  from it.ge_cta_clientes c,
       it.ah_cta_vistas   cc,
       it.ge_clientes     cli,
       it.ba_personas     per,
       cc_cta_combinadas cm
 where c.nro_cuenta = cc.nro_cuenta
   and cm.nro_cta_ahorro(+)=cc.nro_cuenta
   and c.relacion = 'P'
   and per.cod_persona = cli.cod_persona
   and c.cod_persona = cli.cod_persona;

