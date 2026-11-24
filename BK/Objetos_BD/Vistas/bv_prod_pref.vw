create or replace force view it.bv_prod_pref as
select distinct g.cod_persona,
       t.nro_tarjeta,
       t.nro_cuenta,
       ge.estado,
       ge.descripcion as estado_des,
       fue_obt_nom_persona(g.cod_persona) as nombre,
       g.cod_usu_oficial as cod_gestor,
       fue_obt_nom_usuario(g.cod_usu_oficial) as gestor,
       fug_obt_seg_cliente(g.cod_persona) as Area_Negocio,
       gs.descripcion as Area_Negocio_des,
       fug_obt_paq_des_cliente(t.cod_persona) as paquete,
       (select ba.significado from ba_cod_referencias ba where tt.tip_tas_financiacion = ba.val_minimo and ba.dominio = 'TIP_TAS_FINANCIACION') as TIP_TAS_FINANCIACION,
       (select b.significado from ba_cod_referencias b where tt.tip_com_emision = b.val_minimo and b.dominio = 'TIP_COMISION') as TIP_COMISION,
       (select be.significado from ba_cod_referencias be where tt.tip_gas_financiero = be.val_minimo and be.dominio = 'TIP_GASTO') as TIP_GASTO,
       tj.cod_modulo, tj.cod_modalidad, tj.afinidad, tj.sub_afinidad,tj.cod_canal,tj.cod_campana

  from ta_tarjetas t, ge_clientes g, ta_cta_tarjetas tj, ta_tipos tt, ge_est_cuentas ge, ge_seg_clientes gs
 where fug_obt_paq_des_cliente(t.cod_persona) is not null
   and tj.nro_cuenta = t.nro_cuenta
   and ge.estado = tj.estado
   and gs.cod_seg_cliente(+) = fug_obt_seg_cliente(g.cod_persona)
   and ge.cod_modulo = tj.cod_modulo
   and ge.cod_modalidad = tj.cod_modalidad
   and g.cod_persona = t.cod_persona
   and tt.cod_modulo = tj.cod_modulo
   and tt.cod_modalidad = tj.cod_modalidad
   and tt.afinidad = tj.afinidad
   and tt.sub_afinidad = tj.sub_afinidad;

