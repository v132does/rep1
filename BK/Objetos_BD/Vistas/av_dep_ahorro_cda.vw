CREATE OR REPLACE FORCE VIEW IT.AV_DEP_AHORRO_CDA AS
select a.nro_cuenta,a.cod_persona, a.cod_moneda, a.nombre_cliente,  a.tip_documento, a.nro_documento, a.tipo, a.relacion, a.estado , a.fec_apertura,a.sal_total,  case when a.tipo = 'CDA' and a.estado_ah='N' and a.sal_disponible >= a.capital then
                                             nvl(a.sal_disponible,0) - nvl(a.capital,0)
                                         else
                                                a.sal_disponible
                                         end sal_disponible
       from (SELECT t.nro_cuenta,
        t.cod_moneda ,
       b.nom_completo nombre_cliente ,
       tp.descripcion tip_documento,
       b.cod_persona,
       b.nro_documento,'CDA' tipo,
       rr.significado relacion,
       fug_obt_des_est_cta(t.cod_modulo, t.cod_modalidad, t.estado) estado,
       t.estado estado_ah ,
       t.capital capital,
       t.fec_apertura,
       t.sal_total, case when nvl(t.sal_retenido,0) <= t.capital  or t.estado ='A'  then    nvl(t.sal_total,0) - nvl(t.sal_retenido,0)+ nvl(t.sal_bloqueado,0)
      else     nvl(t.sal_total,0) - nvl(t.sal_retenido,0)+ nvl(t.sal_bloqueado,0) -  nvl(t.capital,0)end sal_disponible
  from ah_cta_certificados t,
       ge_cta_clientes cc,
       ge_cuentas cu,
       ge_est_cuentas ec,
       ba_personas b,
       ba_tip_documentos tp,
       (select * from ba_cod_referencias r where r.dominio = 'RELACION') rr
 where t.nro_cuenta = cc.nro_cuenta
   and cc.cod_persona = b.cod_persona
   and b.cod_tip_documento = tp.cod_tip_documento
   and cc.relacion = rr.val_minimo
   and t.cod_modulo=3
   and cc.nro_cuenta = cu.nro_cuenta
   and cu.cod_modulo = ec.cod_modulo
   and cu.cod_modalidad = ec.cod_modalidad
   and cu.estado        =ec.estado
   and ec.activo ='S'
  and not exists (select 1 from
              pr_cta_prestamos p, ge_cta_clientes cl,  ge_cuentas cue, ge_est_cuentas esc
             where p.nro_cuenta = cl.nro_cuenta
               and cl.nro_cuenta = cue.nro_cuenta
               and cue.estado =  esc.estado and esc.activo='S'
                 and p.cod_modulo = 6
               and cl.cod_persona = cc.cod_persona)
    and not exists(select 1 from
                        ta_tarjetas ta,  ge_cta_clientes cl,  ge_cuentas cue, ge_est_cuentas esc
                          where cl.nro_cuenta=ta.nro_cuenta
                          and cl.nro_cuenta = cue.nro_cuenta
                          and cue.estado =  esc.estado and esc.activo='S' and  cl.cod_persona = cc.cod_persona
                          )
 union

    select v.nro_cuenta,
      v.cod_moneda ,
       b.nom_completo,
       tp.descripcion,
       b.cod_persona,
       b.nro_documento,
      'Ahorros a la vista',
       rr.significado relacion,
       fug_obt_des_est_cta(v.cod_modulo, v.cod_modalidad, v.estado),
       v.estado estado_ah ,
       0 capital,
       v.fec_apertura,
       v.sal_total,
       nvl(v.sal_total, 0) - nvl(v.sal_retenido, 0) -
       nvl(v.sal_bloqueado, 0) - nvl(v.mto_deb_pendientes, 0) +
       nvl(v.mto_cre_pendientes, 0) sal_disponible

  from ah_cta_vistas v,
       ge_cta_clientes cc,
       ge_cuentas cu,
       ge_est_cuentas ec,
       ba_personas b,
       ba_tip_documentos tp,
       (select * from ba_cod_referencias r where r.dominio ='RELACION') rr
 where v.nro_cuenta = cc.nro_cuenta
   and cc.cod_persona = b.cod_persona
   and b.cod_tip_documento = tp.cod_tip_documento
   and cc.relacion = rr.val_minimo
    and v.cod_modulo=3
   and cc.nro_cuenta = cu.nro_cuenta
   and cu.cod_modulo = ec.cod_modulo
   and cu.cod_modalidad = ec.cod_modalidad
   and cu.estado        =ec.estado
   and ec.activo ='S'
 and not exists (select 1 from
              pr_cta_prestamos p, ge_cta_clientes cl,  ge_cuentas cue, ge_est_cuentas esc
             where p.nro_cuenta = cl.nro_cuenta
               and cl.nro_cuenta = cue.nro_cuenta
               and cue.estado =  esc.estado
               and esc.activo='S'
               and p.cod_modulo = 6
               and cl.cod_persona = cc.cod_persona)
      and not exists(select 1 from
                        ta_tarjetas ta,  ge_cta_clientes cl,  ge_cuentas cue, ge_est_cuentas esc
                          where cl.nro_cuenta=ta.nro_cuenta
                          and cl.nro_cuenta = cue.nro_cuenta
                          and cue.estado =  esc.estado
                          and esc.activo='S'
                          and  cl.cod_persona = cc.cod_persona
                          )   ) a;

