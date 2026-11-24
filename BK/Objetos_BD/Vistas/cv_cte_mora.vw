create or replace force view it.cv_cte_mora as
Select ga.cod_persona COD_CLIENTE,
       cc.nro_cuenta CUENTA,
       cc.cod_modalidad MODALIDAD,
       cc.cod_sub_modalidad COD_SUB_MOD,
       fug_obt_des_submodalidad(cc.cod_modulo,
                                cc.cod_modalidad,
                                cc.cod_sub_modalidad) SUB_MODALIDAD,
       cc.cta_combinada,
       fue_obt_nom_persona(ga.cod_persona) NOMBRE,
       gc.cat_sistema CATEGORÍA,
       fue_obt_nom_usuario(gc.cod_usu_oficial) GESTOR,
       cc.cod_moneda MONEDA,
       cc.sal_total SAL_TOTAL,
       cc.sal_retenido SAL_RETENIDO,
       cc.sal_bloqueado SAL_BLOQUEADO,
       (select gb.mto_embargado
          from ge_embargos_det gb
         where gb.nro_cuenta = cc.nro_cuenta
           and gb.fec_insercion =
               (select max(gb.fec_insercion)
                  from ge_embargos_det gb
                 where gb.nro_cuenta = cc.nro_cuenta)) MTO_EMBARGO,
       cc.sal_total - (cc.sal_bloqueado + cc.sal_retenido) SAL_DISPONIBLE,
       cl.monto MONTO_LINEA,
       case
         when nvl(cc.SAL_TOTAL, 0) - nvl(cc.SAL_RETENIDO, 0) -
              nvl(cc.SAL_BLOQUEADO, 0) < 0 then
          (nvl(cc.SAL_TOTAL, 0) - nvl(cc.SAL_RETENIDO, 0) -
          nvl(cc.SAL_BLOQUEADO, 0)) + nvl(cl.monto, 0)
         else
          0
       end Excesos,
       fuc_obt_dia_atraso(cc.nro_cuenta) DIAS_DE_MORA,
       fug_obt_cau_inhibicion(cc.nro_cuenta) MOT_INHIBICION,
       null fec_solicitud,
       null est_chequera,
       null TIPO,
       cc.COD_ENTE,
       case
         when (cc.COD_ENTE is not null) then
          (select ge.descripcion
             from ge_entes ge
            where cc.cod_ente = ge.cod_ente)
         else
          null
       end NOM_ENTE,
       'SIN CHEQUERA' AS CONSULTA
  from cc_cta_corrientes cc,
       ge_clientes       gc,
       ge_cta_clientes   ga,
       cc_lin_sobregiros cl
 where cc.nro_cuenta = ga.nro_cuenta
   and cc.nro_cuenta = cl.nro_cuenta(+)
   and gc.cod_persona = ga.cod_persona
   and ga.relacion = 'P'
   and cc.sal_total < 0
   and cc.estado = 'N'
   and not exists (Select 1
          from cc_lin_sobregiros a
         where a.nro_cuenta = cc.nro_cuenta
           and a.estado = 'A')
   and fuc_obt_dia_atraso(cc.nro_cuenta) > 0
   and not exists(select 1 from cc_chequeras c where c.nro_cuenta = cc.nro_cuenta)
union
select ga.cod_persona COD_CLIENTE,
       cc.nro_cuenta CUENTA,
       cc.cod_modalidad MODALIDAD,
       cc.cod_sub_modalidad COD_SUB_MOD,
       fug_obt_des_submodalidad(cc.cod_modulo,
                                cc.cod_modalidad,
                                cc.cod_sub_modalidad) SUB_MODALIDAD,
       cc.cta_combinada,
       fue_obt_nom_persona(ga.cod_persona) NOMBRE,
       gc.cat_sistema CATEGORÍA,
       fue_obt_nom_usuario(gc.cod_usu_oficial) GESTOR,
       cc.cod_moneda MONEDA,
       cc.sal_total SAL_TOTAL,
       cc.sal_retenido SAL_RETENIDO,
       cc.sal_bloqueado SAL_BLOQUEADO,
       (select gb.mto_embargado
          from ge_embargos_det gb
         where gb.nro_cuenta = cc.nro_cuenta
           and gb.fec_insercion =
               (select max(gb.fec_insercion)
                  from ge_embargos_det gb
                 where gb.nro_cuenta = cc.nro_cuenta)) MTO_EMBARGO,
       cc.sal_total - (cc.sal_bloqueado + cc.sal_retenido) SAL_DISPONIBLE,
       cl.monto MONTO_LINEA,
       case
         when nvl(cc.SAL_TOTAL, 0) - nvl(cc.SAL_RETENIDO, 0) -
              nvl(cc.SAL_BLOQUEADO, 0) < 0 then
          (nvl(cc.SAL_TOTAL, 0) - nvl(cc.SAL_RETENIDO, 0) -
          nvl(cc.SAL_BLOQUEADO, 0)) + nvl(cl.monto, 0)
         else
          0
       end Excesos,
       fuc_obt_dia_atraso(cc.nro_cuenta) DIAS_DE_MORA,
       fug_obt_cau_inhibicion(cc.nro_cuenta) MOT_INHIBICION,
       sc.fec_solicitud fec_solicitud,
       (select b.significado
          from ba_cod_referencias b
         where b.dominio = 'EST_CHEQUERA'
           and b.val_minimo like sc.estado) est_chequera,
       (select tc.descripcion
          from cc_tip_chequeras tc
         where tc.cod_tip_chequera = sc.tipo) TIPO,
       cc.COD_ENTE,
       case
         when (cc.COD_ENTE is not null) then
          (select ge.descripcion
             from ge_entes ge
            where cc.cod_ente = ge.cod_ente)
         else
          null
       end NOM_ENTE,
       'CON CHEQUERA' AS CONSULTA
  from cc_cta_corrientes cc,
       cc_chequeras      sc,
       ge_clientes       gc,
       ge_cta_clientes   ga,
       cc_lin_sobregiros cl
 where cc.nro_cuenta = ga.nro_cuenta
   and cc.nro_cuenta = cl.nro_cuenta(+)
   and gc.cod_persona = ga.cod_persona
   and cc.nro_cuenta = sc.nro_cuenta
   and ga.relacion = 'P'
   and sc.fec_solicitud =
       (select max(fec_solicitud)
          from cc_chequeras
         where nro_cuenta = cc.nro_cuenta)
   /*and sc.fec_modificacion =
       (select max(fec_modificacion)
          from cc_chequeras
         where nro_cuenta = cc.nro_cuenta)*/
   and cc.sal_total < 0
   and cc.estado = 'N'
   and not exists (Select 1
          from cc_lin_sobregiros a
         where a.nro_cuenta = cc.nro_cuenta
           and a.estado = 'A')
   and fuc_obt_dia_atraso(cc.nro_cuenta) > 0
 order by 1;

