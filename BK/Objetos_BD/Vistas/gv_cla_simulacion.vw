CREATE VIEW IT.GV_CLA_SIMULACION
AS select pag_cal.fu_obt_fec_actual(1) fecha_cierre,
       case
         when a.cod_sec_credito in (702, 703) then
          'V'
         else
          case
            when f.tipo = 'T' and a.tip_destino = 4 then
             'P'
            else
             f.tipo
          end
       end tipo,
       fue_obt_des_refcodes('TIP_CLIENTE',
                            case
                              when a.cod_sec_credito in (702, 703) then
                               'V'
                              else
                               case
                                 when f.tipo = 'T' and a.tip_destino = 4 then
                                  'P'
                                 else
                                  f.tipo
                               end
                            end) tip_cliente,
       null cod_rubro, --a.cod_rubro,
       a.cod_modulo,
       a.cod_modalidad,
       a.nro_cuenta,
       a.cod_persona,
       d.nro_documento,
       d.nom_completo,
       e.fec_inicio, -- 
       e.fec_vencimiento, --
       e.val_tasa,
       (e.fec_vencimiento - e.fec_inicio) plazo, --
       null cod_tip_deudor, --b.cod_tip_deudor, --este
       fug_obt_des_modal(e.cod_modulo, e.cod_modalidad) tip_operacion,
       a.cod_estado,
       a.dia_atraso,
       a.cat_automatica,
       f.cat_riesgo,
       e.cod_moneda,
       nvl(pag_gen.fu_obt_cotizacion(e.cod_moneda,
                                     pag_cal.fu_obt_fec_actual(1)),
           0) cotizacion,
       e.sal_capital,
       e.dev_no_cobrado,
       case
         when e.cod_moneda = 'USD' then
          (nvl(e.sal_capital, 0) *pag_gen.fu_obt_cotizacion(e.cod_moneda, pag_cal.fu_obt_fec_actual(1)))
         else
          e.sal_capital
       end sal_capital_guaranizado,
       case
         when e.cod_moneda = 'USD' then
          (nvl(e.dev_no_cobrado, 0) *
          pag_gen.fu_obt_cotizacion(e.cod_moneda,
                                     pag_cal.fu_obt_fec_actual(1)))
         else
          e.dev_no_cobrado
       end dev_no_cobrado_guaranizado,
       nvl(nvl(e.sal_interes, 0) + nvl(e.sal_int_adelantado, 0), 0) sal_int,
       e.val_int_devengar,
       (case
         when (a.cod_modalidad = 695) then
          0 -- modalidad 695 solo debe tener prevision_cta_orden 
         else
          nvl(a.tot_prevision, 0) + nvl(a.mto_pre_total, 0)
       end) total_prevision,
       (case
         when (a.cod_modalidad = 695) then
          0 -- modalidad 695 solo debe tener prevision_cta_orden
         else
          a.tot_prevision
       end) prevision_cartera,
       (case
         when (a.cod_modalidad = 695) then
          0 -- modalidad 695 solo debe tener prevision_cta_orden
         else
          a.mto_pre_total
       end) prevision_diferida,
       (case
         when a.cod_modalidad = 695 then
          nvl(nvl(a.tot_prevision, 0) + nvl(a.mto_pre_total, 0), 0)
         else
          0
       end) prevision_cta_orden,
       a.tot_pri_prevision prevision_anterior,
       nvl(a.tot_deu_contingente, 0) saldo_contingente,
       nvl(a.tot_gar_computables, 0) gar_computable
  from ge_cla_operaciones a,
       ba_personas        d,
       pr_cta_prestamos   e,
       ge_clientes        f
 where a.cod_persona = f.cod_persona
   and a.cod_persona = d.cod_persona
   and a.nro_cuenta(+) = e.nro_cuenta
   and (nvl(a.tot_deu_real, 0) + nvl(a.tot_deu_contingente, 0) > 0)

union all

-- tarjetas
select pag_cal.fu_obt_fec_actual(1) fecha_cierre,
       case
         when a.cod_sec_credito in (702, 703) then
          'V'
         else
          case
            when f.tipo = 'T' and a.tip_destino = 4 then
             'P'
            else
             f.tipo
          end
       end tipo,
       fue_obt_des_refcodes('TIP_CLIENTE',
                            case
                              when a.cod_sec_credito in (702, 703) then
                               'V'
                              else
                               case
                                 when f.tipo = 'T' and a.tip_destino = 4 then
                                  'P'
                                 else
                                  f.tipo
                               end
                            end) tip_cliente,
       null cod_rubro, --a.cod_rubro,
       a.cod_modulo,
       a.cod_modalidad,
       a.nro_cuenta,
       a.cod_persona,
       d.nro_documento,
       d.nom_completo,
       /*(select ta.fec_emision
          from ta_tarjetas ta
         where nro_cuenta = e.nro_cuenta
           and ta.rel_tarjeta = '0') */ null fec_inicio, -- 
           /*(select ta.fec_vencimiento
          from ta_tarjetas ta
         where nro_cuenta = e.nro_cuenta
           and ta.rel_tarjeta = '0')*/ null fec_vencimiento,
       e.tas_financiacion val_tasa,
       /*((select ta.fec_vencimiento
           from ta_tarjetas ta
          where nro_cuenta = e.nro_cuenta
            and ta.rel_tarjeta = '0') -
       (select ta.fec_emision
           from ta_tarjetas ta
          where nro_cuenta = e.nro_cuenta
            and ta.rel_tarjeta = '0'))*/ null plazo,
       null cod_tip_deudor, --b.cod_tip_deudor,
       fug_obt_des_modal(a.cod_modulo, a.cod_modalidad) tip_operacion,
       a.cod_estado,
       a.dia_atraso,
       a.cat_automatica,
       f.cat_riesgo,
       a.cod_moneda,
       nvl(pag_gen.fu_obt_cotizacion(e.cod_moneda,
                                     pag_cal.fu_obt_fec_actual(1)),
           0) cotizacion,
       (nvl(a.tot_deu_real, 0) - nvl(a.dev_no_cobrado, 0)) sal_capital,
       a.dev_no_cobrado,
       case
         when a.cod_moneda = 'USD' then
          (nvl(a.tot_deu_real, 0) - nvl(a.dev_no_cobrado, 0)) *
          pag_gen.fu_obt_cotizacion(a.cod_moneda,
                                    pag_cal.fu_obt_fec_actual(1))
         else
          (nvl(a.tot_deu_real, 0) - nvl(a.dev_no_cobrado, 0))
       end sal_capital_guaranizado,

       case
         when a.cod_moneda = 'USD' then
          nvl(a.dev_no_cobrado, 0) *
          pag_gen.fu_obt_cotizacion(a.cod_moneda,
                                    pag_cal.fu_obt_fec_actual(1))
         else
          nvl(a.dev_no_cobrado, 0)
       end dev_no_cobrado_guaranizado,

       0 sal_int,
       0 val_int_devengar,
       (case
         when (a.cod_modalidad = 695) then
          0 -- modalidad 695 solo debe tener prevision_cta_orden 
         else
          nvl(a.tot_prevision, 0) + nvl(a.mto_pre_total, 0)
       end) total_prevision,
       (case
         when (a.cod_modalidad = 695) then
          0 -- modalidad 695 solo debe tener prevision_cta_orden
         else
          a.tot_prevision
       end) prevision_cartera,
       (case
         when (a.cod_modalidad = 695) then
          0 -- modalidad 695 solo debe tener prevision_cta_orden
         else
          a.mto_pre_total
       end) prevision_diferida,
       (case
         when a.cod_modalidad = 695 then
          nvl(nvl(a.tot_prevision, 0) + nvl(a.mto_pre_total, 0), 0)
         else
          0
       end) prevision_cta_orden,
       a.tot_pri_prevision prevision_anterior,
       nvl(a.tot_deu_contingente, 0) saldo_contingente,
       nvl(a.tot_gar_computables, 0) gar_computable
  from ge_cla_operaciones a,
       ba_personas        d,
       ta_cta_tarjetas    e,
       ge_clientes        f
 where a.cod_persona = f.cod_persona
   and a.cod_persona = d.cod_persona
   and a.nro_cuenta(+) = e.nro_cuenta
   and (nvl(a.tot_deu_real, 0) + nvl(a.tot_deu_contingente, 0) > 0)
union all
-- op vencidas
select pag_cal.fu_obt_fec_actual(1) fecha_cierre,
       case
         when a.cod_sec_credito in (702, 703) then
          'V'
         else
          case
            when f.tipo = 'T' and a.tip_destino = 4 then
             'P'
            else
             f.tipo
          end
       end tipo,
       fue_obt_des_refcodes('TIP_CLIENTE',
                            case
                              when a.cod_sec_credito in (702, 703) then
                               'V'
                              else
                               case
                                 when f.tipo = 'T' and a.tip_destino = 4 then
                                  'P'
                                 else
                                  f.tipo
                               end
                            end) tip_cliente,
       null cod_rubro, --b.cod_rubro,
       a.cod_modulo,
       a.cod_modalidad,
       a.nro_cuenta,
       a.cod_persona,
       d.nro_documento,
       d.nom_completo,
       e.fec_apertura fec_inicio,
       sysdate fec_vencimiento, --se puso sysdate por el formato de fecha nomas
       e.val_tasa,
       0 plazo,
       null cod_tip_deudor, --b.cod_tip_deudor,
       fug_obt_des_modal(a.cod_modulo, a.cod_modalidad) tip_operacion,
       a.cod_estado,
       a.dia_atraso,
       a.cat_automatica,
       f.cat_riesgo,
       a.cod_moneda,
       nvl(pag_gen.fu_obt_cotizacion(e.cod_moneda,
                                     pag_cal.fu_obt_fec_actual(1)),
           0) cotizacion,
       case
         when a.cod_moneda = 'USD' then
          ROUND((nvl(a.tot_deu_real, 0) - nvl(a.dev_no_cobrado, 0)) /
          pag_gen.fu_obt_cotizacion(a.cod_moneda,
                                    pag_cal.fu_obt_fec_actual(1)) ,2)
         else
          (nvl(a.tot_deu_real, 0) - nvl(a.dev_no_cobrado, 0))
       end sal_capital,
       case
        when a.cod_moneda = 'USD' then
         ROUND(nvl(a.dev_no_cobrado, 0) / pag_gen.fu_obt_cotizacion(a.cod_moneda,pag_cal.fu_obt_fec_actual(1)) ,2)
         else
           nvl(a.dev_no_cobrado, 0)
          end  dev_no_cobrado,
       round((nvl(a.tot_deu_real, 0) - nvl(a.dev_no_cobrado, 0)),0) sal_capital_guaranizado,
       nvl(a.dev_no_cobrado, 0) dev_no_cobrado_guaranizado,
       0 sal_int,
       0 val_int_devengar,
       nvl(a.tot_prevision, 0) + nvl(a.mto_pre_total, 0) total_prevision,
       nvl(a.tot_prevision,0) prevision_cartera,
       nvl(a.mto_pre_total,0) prevision_diferida,
       nvl(nvl(a.tot_prevision, 0) + nvl(a.mto_pre_total, 0), 0) prevision_cta_orden,
       a.tot_pri_prevision prevision_anterior,
       nvl(a.tot_deu_contingente, 0) saldo_contingente,
       nvl(a.tot_gar_computables, 0) gar_computable
  from ge_cla_operaciones a,
       ba_personas        d,
       ov_cta_vencidas    e,
       ge_clientes        f
 where a.cod_persona = f.cod_persona
   and a.cod_persona = d.cod_persona
   and a.nro_cuenta(+) = e.nro_cuenta
   and (nvl(a.tot_deu_real, 0) + nvl(a.tot_deu_contingente, 0) > 0)
union all
-- Ctas Corrientes
select pag_cal.fu_obt_fec_actual(1) fecha_cierre,
       case
         when a.cod_sec_credito in (702, 703) then
          'V'
         else
          case
            when f.tipo = 'T' and a.tip_destino = 4 then
             'P'
            else
             f.tipo
          end
       end tipo,
       fue_obt_des_refcodes('TIP_CLIENTE',
                            case
                              when a.cod_sec_credito in (702, 703) then
                               'V'
                              else
                               case
                                 when f.tipo = 'T' and a.tip_destino = 4 then
                                  'P'
                                 else
                                  f.tipo
                               end
                            end) tip_cliente,
       null cod_rubro, --b.cod_rubro,
       a.cod_modulo,
       a.cod_modalidad,
       a.nro_cuenta,
       a.cod_persona,
       d.nro_documento,
       d.nom_completo,
       e.fec_apertura fec_inicio,
       sysdate fec_vencimiento, --se puso sysdate por el formato de fecha nomas
       null val_tasa,
       0 plazo,
       null cod_tip_deudor, --b.cod_tip_deudor,
       fug_obt_des_modal(a.cod_modulo, a.cod_modalidad) tip_operacion,
       a.cod_estado,
       a.dia_atraso,
       a.cat_automatica,
       f.cat_riesgo,
       a.cod_moneda,
       nvl(pag_gen.fu_obt_cotizacion(e.cod_moneda,
                                     pag_cal.fu_obt_fec_actual(1)),
           0) cotizacion,
       case
         when a.cod_moneda = 'USD' then
          ROUND((nvl(a.tot_deu_real, 0) - nvl(a.dev_no_cobrado, 0)) /
          pag_gen.fu_obt_cotizacion(a.cod_moneda,
                                    pag_cal.fu_obt_fec_actual(1)) ,2)
         else
          (nvl(a.tot_deu_real, 0) - nvl(a.dev_no_cobrado, 0))
       end sal_capital,
       case
        when a.cod_moneda = 'USD' then
         ROUND(nvl(a.dev_no_cobrado, 0) / pag_gen.fu_obt_cotizacion(a.cod_moneda,pag_cal.fu_obt_fec_actual(1)) ,2)
         else
           nvl(a.dev_no_cobrado, 0)
          end  dev_no_cobrado,     
       round((nvl(a.tot_deu_real, 0) - nvl(a.dev_no_cobrado, 0)),0) sal_capital_guaranizado,
       nvl(a.dev_no_cobrado, 0) dev_no_cobrado_guaranizado,
       0 sal_int,
       0 val_int_devengar,
       nvl(a.tot_prevision, 0) + nvl(a.mto_pre_total, 0) total_prevision,
       nvl(a.tot_prevision,0) prevision_cartera,
       nvl(a.mto_pre_total,0) prevision_diferida,
       nvl(nvl(a.tot_prevision, 0) + nvl(a.mto_pre_total, 0), 0) prevision_cta_orden,
       nvl(a.tot_pri_prevision,0) prevision_anterior,
       nvl(a.tot_deu_contingente, 0) saldo_contingente,
       nvl(a.tot_gar_computables, 0) gar_computable
  from ge_cla_operaciones a,
       ba_personas        d,
       cc_cta_corrientes  e,
       ge_clientes        f
 where a.cod_persona = f.cod_persona
   and a.cod_persona = d.cod_persona
   and a.nro_cuenta(+) = e.nro_cuenta
   and (nvl(a.tot_deu_real, 0) + nvl(a.tot_deu_contingente, 0) > 0);
