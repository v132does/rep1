create or replace force view it.tv_solicitudes as
select 'T' Tipo,
       'Titular' Des_Tipo,
       nro_solicitud, cod_persona, cod_oficina, cod_modulo, cod_modalidad,
       cod_usu_promotor, fec_solicitud, cod_usu_oficial,
       fec_aprobacion, cod_causa,
       deb_automatico, nro_cta_debito, tip_cobro,
       nom_embozado,
       monto,
       cod_estado, cod_est_sugerido, lin_sugerida, puntaje,
       observacion, cod_moneda, cod_campana, cod_canal, mto_aprobado
       --agreguc un campo mas para traer el usuario que actualizn-WRAA
       ,usu_modificacion,
       --> Personaliza Pago Mínimo
       por_pag_minimo,
       mto_min_pag_minimo,
       mto_fij_pag_minimo,
       --<
       mto_min_pago,
       tas_mora
       ,cod_estado est_titular,
       nro_acta,
       niv_aprobacion,
       cod_persona cod_per_titular,
       nro_cuenta nro_cuenta,
       nro_linea, afinidad, sub_afinidad, cod_tip_cierre, cod_ent_procesadora,
       -- BSEVOCORE-111 - Implementacion de Plastico Contactless
       case when nvl(fug_val_dat_parametros('TRC_TIP_PLA_CLESS',cod_modulo,cod_modalidad,null,afinidad,'N'),0) > 0 then
          'L'
       else
         --DYDMR-2467 ITGF - Alta Adicional con Chip - SC 20802. DYDMR-9097
         case when nvl(INSTR(fug_obt_pardinamico('TRC_TIP_PLA_CHIP',cod_modulo,cod_modalidad),afinidad),0) > 0 then
            case when nvl(instr(fug_obt_pardinamico('TRC_OBL_TIP_PLA_CHIP', cod_modulo, cod_modalidad), afinidad),0) > 0 then
               case when monto >= to_number(fug_obt_pardinamico('MTO_MIN_LIN_CRE_CHIP', null, null, cod_moneda)) then
                  'C'
               else
                  'N'
               end
            else
               'C'
            end
         else
            nvl(tip_plastico, 'N')
         end
       end tip_plastico,
       -- Personaliza Tipo Tasa Interes
       tas_int_corriente,
       tas_int_mora,
       tas_int_compra,
       pre_embozada
from ta_solicitudes
UNION
select 'A' Tipo,
       'Adicional' Des_Tipo,
       t.nro_solicitud, a.cod_persona, t.cod_oficina, t.cod_modulo, t.cod_modalidad,
       a.cod_usu_promotor, a.fec_ingreso, a.cod_usu_oficial,
       a.fec_aprobacion, a.cod_causa,
       t.deb_automatico, t.nro_cta_debito, t.tip_cobro,
       a.nom_embozado,
       t.monto,
       a.cod_estado, a.cod_estado, 0, 0,
       a.observacion, t.cod_moneda, t.cod_campana, t.cod_canal, t.mto_aprobado
       --agreguc un campo mas para traer el usuario que actualizn-WRAA
        ,t.usu_modificacion,
       --> Personaliza Pago Mínimo
       t.por_pag_minimo,
       t.mto_min_pag_minimo,
       t.mto_fij_pag_minimo,
       --<
       t.mto_min_pago,
       t.tas_mora
       , t.cod_estado est_titular,
       a.nro_acta,
       a.niv_aprobacion,
       t.cod_persona cod_per_titular,
       t.nro_cuenta nro_cuenta,
       t.nro_linea, afinidad, sub_afinidad, t.cod_tip_cierre, a.cod_ent_procesadora,
       -- BSEVOCORE-111 - Implementacion de Plastico Contactless
       case when nvl(fug_val_dat_parametros('TRC_TIP_PLA_CLESS',cod_modulo,cod_modalidad,null,afinidad,'N'),0) > 0 then
         'L'
       else
         --DYDMR-2467 ITGF - Alta Adicional con Chip - SC 20802. DYDMR-9097
         case when nvl(INSTR(fug_obt_pardinamico('TRC_TIP_PLA_CHIP',cod_modulo,cod_modalidad),afinidad),0) > 0 then
            case when nvl(instr(fug_obt_pardinamico('TRC_OBL_TIP_PLA_CHIP', cod_modulo, cod_modalidad), '%'),0) > 0 then
               case when monto >= to_number(fug_obt_pardinamico('MTO_MIN_LIN_CRE_CHIP', null, null, cod_moneda)) then
                  'C'
               else
                  'N'
               end
            else
               'C'
            end
         else
            nvl(tip_plastico, 'N')
         end
       end tip_plastico,
       tas_int_corriente, tas_int_mora, tas_int_compra,
       pre_embozada
from ta_solicitudes t, ta_sol_adicionales a
where t.nro_solicitud = a.nro_solicitud
UNION
select 'A' Tipo,
       'Adicional' Des_Tipo,
       null nro_solicitud, a.cod_persona, c.cod_oficina, c.cod_modulo, c.cod_modalidad,
       a.cod_usu_promotor, a.fec_ingreso, a.cod_usu_oficial,
       a.fec_aprobacion, a.cod_causa,
       c.deb_automatico, c.nro_cta_debito, c.tip_cobro,
       a.nom_embozado,
       c.lin_Credito,
       a.cod_estado, a.cod_estado, 0, 0,
       a.observacion, c.cod_moneda, c.cod_campana, c.cod_canal, c.lin_credito
       ,a.usu_modificacion,
       --> Personaliza Pago Mínimo
       c.por_pag_minimo,
       c.mto_min_pag_minimo,
       c.mto_fij_pag_minimo,
       --<
       c.mto_min_pago,
       c.tas_mora
       , null est_titular,
       a.nro_acta,
       a.niv_aprobacion,
       cl.cod_persona cod_per_titular,
       c.nro_cuenta nro_cuenta,
       c.nro_linea, c.afinidad, c.sub_afinidad, c.cod_tip_cierre, a.cod_ent_procesadora,
       -- BSEVOCORE-111 - Implementacion de Plastico Contactless
       case when nvl(fug_val_dat_parametros('TRC_TIP_PLA_CLESS',c.cod_modulo,c.cod_modalidad,null,afinidad,'N'),0) > 0 then
         'L'
       else
         --DYDMR-2467 ITGF - Alta Adicional con Chip - SC 20802. DYDMR-9097
         case when nvl(INSTR(fug_obt_pardinamico('TRC_TIP_PLA_CHIP',c.cod_modulo,c.cod_modalidad),afinidad),0) > 0 then
            case when nvl(instr(fug_obt_pardinamico('TRC_OBL_TIP_PLA_CHIP', c.cod_modulo, c.cod_modalidad), afinidad),0) > 0 then
               case when c.lin_Credito >= to_number(fug_obt_pardinamico('MTO_MIN_LIN_CRE_CHIP', null, null, cod_moneda)) then
                  'C'
               else
                  'N'
               end
            else
               'C'
            end
         else
            nvl(tip_plastico, 'N')
         end
       end tip_plastico,
      tas_int_corriente, tas_int_mora, tas_int_compra,
       'N'
from ge_Cta_clientes cl, ta_cta_tarjetas c, ta_sol_adicionales a
where c.nro_cuenta = a.nro_cuenta
  and a.nro_solicitud is null
  and cl.nro_cuenta = c.nro_cuenta
  and cl.relacion   = 'P'
UNION
select 'L' Tipo,
       'Ampliación' Des_Tipo,
       a.nro_solicitud, a.cod_persona, c.cod_oficina, c.cod_modulo, c.cod_modalidad,
       a.cod_usu_promotor, a.fec_ingreso, a.cod_usu_oficial,
       a.fec_aprobacion, a.cod_causa,
       c.deb_automatico, c.nro_cta_debito, c.tip_cobro,
       null nom_embozado,
       c.lin_Credito,
       a.cod_estado, a.cod_estado, 0, 0,
       a.observacion, c.cod_moneda, c.cod_campana, c.cod_canal, a.lin_credito
       ,a.usu_modificacion,
       --> Personaliza Pago Mínimo
       c.por_pag_minimo,
       c.mto_min_pag_minimo,
       c.mto_fij_pag_minimo,
       --<
       c.mto_min_pago,
       c.tas_mora
       , null est_titular,
       a.nro_acta,
       a.niv_aprobacion,
       a.cod_persona cod_per_titular,
       c.nro_cuenta nro_cuenta,
       c.nro_linea, c.afinidad, c.sub_afinidad, c.cod_tip_cierre, NULL,
       -- BSEVOCORE-111 - Implementacion de Plastico Contactless
       case when nvl(fug_val_dat_parametros('TRC_TIP_PLA_CLESS',cod_modulo,cod_modalidad,null,afinidad,'N'),0) > 0 then
         'L'
       else
         case when nvl(INSTR(fug_obt_pardinamico('TRC_TIP_PLA_CHIP',c.cod_modulo,c.cod_modalidad),c.afinidad),0) > 0 then
             'C'
         else
             nvl(tip_plastico, 'N')
         end
       end tip_plastico,
       tas_int_corriente, tas_int_mora, tas_int_compra,
       'N'
 from ta_cta_tarjetas c, Ta_Sol_Lineas a
where c.nro_cuenta = a.nro_cuenta
  and a.tip_solicitud = 'A'
UNION
select 'D' Tipo,
       'Disminución' Des_Tipo,
       a.nro_solicitud, a.cod_persona, c.cod_oficina, c.cod_modulo, c.cod_modalidad,
       a.cod_usu_promotor, a.fec_ingreso, a.cod_usu_oficial,
       a.fec_aprobacion, a.cod_causa,
       c.deb_automatico, c.nro_cta_debito, c.tip_cobro,
       null nom_embozado,
       c.lin_Credito,
       a.cod_estado, a.cod_estado, 0, 0,
       a.observacion, c.cod_moneda, c.cod_campana, c.cod_canal, a.lin_credito
       ,a.usu_modificacion,
       --> Personaliza Pago Mínimo
       c.por_pag_minimo,
       c.mto_min_pag_minimo,
       c.mto_fij_pag_minimo,
       --<
       c.mto_min_pago,
       c.tas_mora
       , null est_titular,
       a.nro_acta,
       a.niv_aprobacion,
       a.cod_persona cod_per_titular,
       c.nro_cuenta nro_cuenta,
       c.nro_linea, c.afinidad, c.sub_afinidad, c.cod_tip_cierre, NULL,
       -- BSEVOCORE-111 - Implementacion de Plastico Contactless
       case when nvl(fug_val_dat_parametros('TRC_TIP_PLA_CLESS',cod_modulo,cod_modalidad,null,afinidad,'N'),0) > 0 then
         'L'
       else
         case when nvl(INSTR(fug_obt_pardinamico('TRC_TIP_PLA_CHIP',c.cod_modulo,c.cod_modalidad),c.afinidad),0) > 0 then
             'C'
         else
             nvl(tip_plastico, 'N')
         end
       end tip_plastico,
       tas_int_corriente, tas_int_mora, tas_int_compra,
       'N'
 from ta_cta_tarjetas c, Ta_Sol_Lineas a
where c.nro_cuenta = a.nro_cuenta
  and a.tip_solicitud = 'D'
;

