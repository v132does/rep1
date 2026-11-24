create or replace force view it.vg_cta_ent_pag_salario as
select tt.cod_ente,
               fue_obt_nom_persona(et.cod_persona) empresa,
               tt.cod_modulo,
               tt.cod_modalidad,
               tt.nro_cuenta,
               tt.fec_apertura,
               (select g.descripcion
                  from ge_est_cuentas g
                 where g.cod_modulo = tt.cod_modulo
                   and g.cod_modalidad = tt.cod_modalidad
                   and g.estado = tt.estado) estado_cta,
               case
                 when (tt.cod_sub_modalidad = '6') then
                  'AGUINALDO'
                 else
                  'NOMINA'
               end tipo_cuenta,
               gc.cod_persona,
               fue_obt_nom_persona(gc.cod_persona) cliente,
               bp.nro_documento,
               tt.cod_moneda,
               (select nvl(max(ta.deb_automatico), 'N')
                  from ta_cta_tarjetas ta
                 where ta.nro_cta_debito = tt.nro_cuenta
                   and ta.estado = 'N') debito_tarjeta,
               (select nvl(max(pr.cob_automatico), 'N')
                  from pr_cta_prestamos pr
                 where pr.nro_cta_debito = tt.nro_cuenta
                   and pr.estado = 'C') debito_prestamo,
               (select max(ss.fec_proceso)
                  from ge_pag_sueldos ss
                where ss.nro_cuenta = tt.nro_cuenta
                  and ss.procesado = 'S'
                  and ss.tipo = 'C'
                  and ss.monto > 0)fec_ult_crd,
                  tt.sal_disponible,
                  tt.cod_sub_modalidad,
                  (select dir.direccion
                     from ba_direcciones dir
                    where dir.cod_persona = bp.cod_persona
                      and dir.tipo = 'P'
                      and dir.principal = 'N'
                      and dir.observacion = 'Dirección del Kit') dir_kit,
                  bp.dir_correo,
                  (select ing.importe
                     from cr_per_ing_egresos ing
                    where ing.cod_persona = bp.cod_persona
                      and ing.ing_egreso = 'I') salario,
                  'AHO' tipo_cta
          from (select distinct ah.nro_cuenta,
                                ah.estado,
                                ah.cod_modulo,
                                ah.cod_modalidad,
                                ah.cod_sub_modalidad,
                                ah.cod_ente,
                                ah.cod_moneda,
                                ah.fec_apertura,
                                nvl(ah.SAL_TOTAL,0)-nvl(ah.SAL_RETENIDO,0)-nvl(ah.SAL_BLOQUEADO,0) SAL_DISPONIBLE
                  from ge_pag_sueldos gp, ah_cta_vistas ah
                 where ah.nro_cuenta = gp.nro_cuenta(+)
                   and ah.cod_ente is not null) tt,
               ge_cta_clientes gc,
               ba_personas bp,
               ge_entes et
         where tt.nro_cuenta = gc.nro_cuenta
           and gc.cod_persona = bp.cod_persona
           and tt.cod_ente = et.cod_ente
           and et.tipo = 'SU'
           and et.cod_persona <> 11198
        UNION ALL
        select tt.cod_ente,
               fue_obt_nom_persona(et.cod_persona) empresa,
               tt.cod_modulo,
               tt.cod_modalidad,
               tt.nro_cuenta,
               tt.fec_apertura,
               (select g.descripcion
                  from ge_est_cuentas g
                 where g.cod_modulo = tt.cod_modulo
                   and g.cod_modalidad = tt.cod_modalidad
                   and g.estado = tt.estado) estado_cta,
               case
                 when (tt.cod_sub_modalidad = '6') then
                  'AGUINALDO'
                 else
                  'NOMINA'
               end tipo_cuenta,
               gc.cod_persona,
               fue_obt_nom_persona(gc.cod_persona) cliente,
               bp.nro_documento,
               tt.cod_moneda,
               (select nvl(max(ta.deb_automatico), 'N')
                  from ta_cta_tarjetas ta
                 where ta.nro_cta_debito = tt.nro_cuenta
                   and ta.estado = 'N') debito_tarjeta,

               (select nvl(max(pr.cob_automatico), 'N')
                  from pr_cta_prestamos pr
                 where pr.nro_cta_debito = tt.nro_cuenta
                   and pr.estado = 'C') debito_prestamo,

              (select max(ss.fec_proceso)
                  from ge_pag_sueldos ss
                where ss.nro_cuenta = tt.nro_cuenta
                  and ss.procesado = 'S'
                  and ss.tipo = 'C'
                  and ss.monto > 0)fec_ult_crd,
                tt.sal_disponible,
                tt.cod_sub_modalidad,
                (select dir.direccion
                   from ba_direcciones dir
                  where dir.cod_persona = bp.cod_persona
                    and dir.tipo = 'P'
                    and dir.principal = 'N'
                    and dir.observacion = 'Dirección del Kit') dir_kit,
                bp.dir_correo,
                (select ing.importe
                     from cr_per_ing_egresos ing
                    where ing.cod_persona = bp.cod_persona
                      and ing.ing_egreso = 'I') salario,
                'CC' tipo_cta
          from (select distinct cc.nro_cuenta,
                                cc.estado,
                                cc.cod_modulo,
                                cc.cod_modalidad,
                                cc.cod_sub_modalidad,
                                cc.cod_ente,
                                cc.cod_moneda,
                                cc.fec_apertura,
                            nvl(cc.SAL_TOTAL,0)-nvl(cc.SAL_RETENIDO,0)-nvl(cc.SAL_BLOQUEADO,0)-nvl(cc.MTO_DEB_PENDIENTES,0)+nvl(cc.MTO_CRE_PENDIENTES,0) SAL_DISPONIBLE
                  from ge_pag_sueldos gp, Cc_Cta_Corrientes cc
                 where cc.nro_cuenta = gp.nro_cuenta(+)
                   and cc.cod_ente is not null) tt,
               ge_cta_clientes gc,
               ba_personas bp,
               ge_entes et
         where tt.nro_cuenta = gc.nro_cuenta
           and gc.cod_persona = bp.cod_persona
           and tt.cod_ente = et.cod_ente
           and et.tipo = 'SU'
           and et.cod_persona <> 11198;

