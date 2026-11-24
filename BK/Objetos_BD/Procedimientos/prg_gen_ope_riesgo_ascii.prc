CREATE OR REPLACE PROCEDURE IT.PRG_GEN_OPE_RIESGO_ASCII
(
   p_fec_desde DATE DEFAULT NULL,
   p_fec_hasta DATE DEFAULT NULL
) IS
   -- Archivos de movimientos de clientes, informado a Seprelad cada vez que solicitan información s/una persona
   -- Se debe marcar primero el cliente en la carpeta de la persona (datos adicionales),
   -- fecha inicio y fin de los datos solicitados
   --- VARIABLES DEL PROCESO
   v_archivo              utl_file.file_type;
   v_seprelad             LONG;
   v_cot_dest             lc_movimientos_his.cotizacion%TYPE;
   v_afe_transf           lc_tip_operaciones.afe_transferencia%TYPE := 'N';
   v_cod_aba_banco        lc_transferencias.cod_aba_banco%TYPE;
   v_cod_swi_banco        lc_transferencias.cod_swi_banco%TYPE;
   v_nro_cta_referencia   lc_transferencias.nro_cta_referencia%TYPE;
   v_nom_solicitante      lc_transferencias.nom_solicitante%TYPE;
   v_observacion          lc_transferencias.observacion%TYPE;
   v_cod_bco_corresponsal lc_transferencias.cod_bco_corresponsal%TYPE;
   v_saldo                ge_cuentas.sal_contable%TYPE;
   v_banco                ge_bancos.descripcion%TYPE;
   v_cda_beneficiario     ge_gen_ope_riesgo.beneficiario%TYPE;
   v_beneficiario         ge_gen_ope_riesgo.beneficiario%TYPE;
   v_nom_beneficiario     ge_gen_ope_riesgo.beneficiario%TYPE;
   v_cod_persona          ba_personas.cod_persona%TYPE;
   v_nro_factura          cb_lib_ventas.nro_factura%TYPE;
   v_mon_local            ba_monedas.cod_moneda%TYPE; -- moneda local
   v_mon_fuerte           ba_monedas.cod_moneda%TYPE; -- moneda extranjera
   v_nom_ascii            VARCHAR2(50);
   v_directorio           VARCHAR2(100);
   v_cod_mon_des_arb      VARCHAR2(15);
   v_red_local            NUMBER; -- redondeo para moneda local
   v_red_fuerte           NUMBER; -- redondeo para moneda fuerte
   v_fec_desde            DATE;
   v_fec_hasta            DATE;
   ------Alejandro Ferreira 24/10/2013------
   v_tra_descripcion      ge_transacciones.descripcion%type;
   v_cod_tra_instrumento  ge_tra_instrumentos.cod_tra_instrumento%type;
   v_tip_movimiento       VARCHAR2(10);
   v_motivo               ge_gen_ope_riesgo.motivo%type;
   v_nro_operacion        ge_gen_ope_riesgo.nro_operacion%type;

   CURSOR personas IS
      SELECT cod_persona
        FROM ba_per_dat_adicionales a
       WHERE parametro = 'GEN_OPE_RIESGO'
         AND a.val_parametro = 'S';
   CURSOR movim IS -- ahorros
      SELECT nvl((SELECT re.val_maximo
                   FROM ba_cod_referencias re
                  WHERE re.dominio = 'TIP_DOC_OPE_RIESGO'
                    AND re.val_minimo = ba.cod_tip_documento),
                 ba.cod_tip_documento) cod_tip_documento,
             ba.nro_documento nro_documento,
             am.nro_documento nro_operacion,
             am.fecha fec_operacion,
             (SELECT sb.cod_tra_instrumento
                FROM ge_tra_instrumentos     sb,
                     ge_tra_instrumentos_det b
               WHERE sb.cod_tra_instrumento = b.cod_tra_instrumento
                 AND b.cod_tra_padre = am.cod_tra_padre
                 AND b.cod_mod_padre = am.cod_mod_padre
                 AND b.cod_mad_padre = am.cod_mad_padre) cod_tip_instrumento,

             round(nvl(decode(am.cod_moneda,
                              v_mon_local,
                              am.monto,
                              (am.monto * fug_obt_cotizacion(am.cod_moneda,
                                                             am.fecha))),
                       0),
                   v_red_local) mto_equ_local,
             gi.nro_cuenta nro_cuenta,
             decode(fug_obt_pardinamico('COD_TIP_CUENTA',
                                        am.cod_modulo,
                                        am.cod_modalidad,
                                        am.cod_moneda,
                                        am.cod_oficina),
                    '0',
                    NULL,
                    fug_obt_pardinamico('COD_TIP_CUENTA',
                                        am.cod_modulo,
                                        am.cod_modalidad,
                                        am.cod_moneda,
                                        am.cod_oficina)) tip_cuenta,
             mo.cod_mon_bco_central cod_moneda,
             decode(am.cod_moneda,
                    v_mon_local,
                    0,
                    am.monto) mto_mon_origen,
             decode(am.cod_moneda,
                    v_mon_fuerte,
                    1,
                    fug_obt_cotizacion(v_mon_fuerte,
                                       am.fecha)) cotizacion,
             round(nvl(decode(am.cod_moneda,
                              v_mon_fuerte,
                              monto,
                              (monto / fug_obt_cotizacion(v_mon_fuerte,
                                                          am.fecha))),
                       0),
                   v_red_fuerte) mto_mon_extranjera,
             ba.nom_completo beneficiario,
             NULL ordenante,
             fug_obt_des_transaccion(am.cod_modulo,
                                     am.cod_modalidad,
                                     am.cod_transaccion) motivo,
             am.cod_modalidad,
             am.cod_mod_padre,
             am.cod_mad_padre,
             am.cod_tra_padre,
             am.cod_modulo,
             am.hora,
             am.cod_usuario,
             NULL tip_ope_cambio,
             am.cod_transaccion
        FROM ba_personas        ba,
             ge_cta_clientes    gi,
             ah_movimientos_his am,
             ge_transacciones   tr,
             ba_monedas         mo
       WHERE ba.cod_persona = gi.cod_persona
         AND gi.nro_cuenta = am.nro_cuenta
         AND gi.relacion = 'P'
         AND ((am.cod_mod_padre = 3) OR (am.cod_mod_padre = 9 AND am.cod_modulo = 3) OR
             (am.cod_mod_padre = 4 AND am.cod_modulo = 43 AND am.cod_modulo = 3) )
         AND am.fecha BETWEEN v_fec_desde AND v_fec_hasta
         AND ba.cod_persona = v_cod_persona
         AND am.reversado = 'N'
         AND am.nro_documento IS NOT NULL -- LOS MOV DEL SISTEMA TIENEN NULO ESTE DATO
         AND am.monto IS NOT NULL
         AND am.cod_moneda = mo.cod_moneda
         AND am.cod_transaccion = tr.cod_transaccion
         AND am.cod_modulo = tr.cod_modulo
         AND am.cod_modalidad = tr.cod_modalidad
         AND nvl(tr.ve_cliente,
                 'N') = 'S' -- SOLO LOS QUE APARECEN EN EL EXTRACTO DEL CLIENTE
      UNION ALL
      SELECT nvl((SELECT re.val_maximo
                   FROM ba_cod_referencias re
                  WHERE re.dominio = 'TIP_DOC_OPE_RIESGO'
                    AND re.val_minimo = ba.cod_tip_documento),
                 ba.cod_tip_documento) cod_tip_documento,
             ba.nro_documento nro_documento,
             am.nro_documento nro_operacion,
             am.fecha fec_operacion,
             (SELECT sb.cod_tra_instrumento
                FROM ge_tra_instrumentos     sb,
                     ge_tra_instrumentos_det b
               WHERE sb.cod_tra_instrumento = b.cod_tra_instrumento
                 AND b.cod_tra_padre = am.cod_tra_padre
                 AND b.cod_mod_padre = am.cod_mod_padre
                 AND b.cod_mad_padre = am.cod_mad_padre) cod_tip_instrumento,
             round(nvl(decode(am.cod_moneda,
                              v_mon_local,
                              am.monto,
                              (am.monto * fug_obt_cotizacion(am.cod_moneda,
                                                             am.fecha))),
                       0),
                   v_red_local) mto_equ_local,
             gi.nro_cuenta nro_cuenta,
             decode(fug_obt_pardinamico('COD_TIP_CUENTA',
                                        am.cod_modulo,
                                        am.cod_modalidad,
                                        am.cod_moneda,
                                        am.cod_oficina),
                    '0',
                    NULL,
                    fug_obt_pardinamico('COD_TIP_CUENTA',
                                        am.cod_modulo,
                                        am.cod_modalidad,
                                        am.cod_moneda,
                                        am.cod_oficina)) tip_cuenta,
             mo.cod_mon_bco_central cod_moneda,
             decode(am.cod_moneda,
                    v_mon_local,
                    0,
                    am.monto) mto_mon_origen,
             decode(am.cod_moneda,
                    v_mon_fuerte,
                    1,
                    fug_obt_cotizacion(v_mon_fuerte,
                                       am.fecha)) cotizacion,
             round(nvl(decode(am.cod_moneda,
                              v_mon_fuerte,
                              monto,
                              (monto / fug_obt_cotizacion(v_mon_fuerte,
                                                          am.fecha))),
                       0),
                   v_red_fuerte) mto_mon_extranjera,
             ba.nom_completo beneficiario,
             NULL ordenante,
             fug_obt_des_transaccion(am.cod_modulo,
                                     am.cod_modalidad,
                                     am.cod_transaccion) motivo,
             am.cod_modalidad,
             am.cod_mod_padre,
             am.cod_mad_padre,
             am.cod_tra_padre,
             am.cod_modulo,
             am.hora,
             am.cod_usuario,
             NULL tip_ope_cambio,
             am.cod_transaccion
        FROM ba_personas      ba,
             ge_cta_clientes  gi,
             ge_movimientos   am,
             ge_transacciones tr,
             ba_monedas       mo
       WHERE ba.cod_persona = gi.cod_persona
         AND gi.nro_cuenta = am.nro_cuenta
         AND am.estado = 'N'
         AND gi.relacion = 'P'
         AND ((am.cod_mod_padre = 3) OR (am.cod_mod_padre = 9 AND am.cod_modulo = 3) OR
             (am.cod_mod_padre = 4 AND am.cod_modulo = 43 AND am.cod_modulo = 3) )
         AND am.fecha BETWEEN v_fec_desde AND v_fec_hasta
         AND ba.cod_persona = v_cod_persona
         AND am.reversado = 'N'
         AND am.nro_documento IS NOT NULL -- LOS MOV DEL SISTEMA TIENEN NULO ESTE DATO
         AND am.monto IS NOT NULL
         AND am.cod_moneda = mo.cod_moneda
         AND am.cod_transaccion = tr.cod_transaccion
         AND am.cod_modulo = tr.cod_modulo
         AND am.cod_modalidad = tr.cod_modalidad
         AND nvl(tr.ve_cliente,
                 'N') = 'S'
      UNION ALL -- prestamos
      SELECT nvl((SELECT re.val_maximo
                   FROM ba_cod_referencias re
                  WHERE re.dominio = 'TIP_DOC_OPE_RIESGO'
                    AND re.val_minimo = ba.cod_tip_documento),
                 ba.cod_tip_documento) cod_tip_documento,
             ba.nro_documento,
             ph.nro_documento,
             ph.fecha,
             (SELECT sb.cod_tra_instrumento
                FROM ge_tra_instrumentos     sb,
                     ge_tra_instrumentos_det b
               WHERE sb.cod_tra_instrumento = b.cod_tra_instrumento
                 AND b.cod_tra_padre = ph.cod_tra_padre
                 AND b.cod_mod_padre = ph.cod_mod_padre
                 AND b.cod_mad_padre = ph.cod_mad_padre) cod_tipo_instrumento,
             round(nvl(decode(ph.cod_moneda,
                              v_mon_local,
                              ph.monto,
                              (ph.monto * fug_obt_cotizacion(ph.cod_moneda,
                                                             ph.fecha))),
                       0),
                   v_red_local) mto_equ_local,
             gt.nro_cuenta,
             decode(fug_obt_pardinamico('COD_TIP_CUENTA',
                                        ph.cod_modulo,
                                        ph.cod_modalidad,
                                        ph.cod_moneda,
                                        ph.cod_oficina),
                    '0',
                    NULL,
                    fug_obt_pardinamico('COD_TIP_CUENTA',
                                        ph.cod_modulo,
                                        ph.cod_modalidad,
                                        ph.cod_moneda,
                                        ph.cod_oficina)) tip_cuenta,
             mo.cod_mon_bco_central cod_moneda,
             decode(ph.cod_moneda,
                    v_mon_local,
                    0,
                    ph.monto) mto_mon_origen,
             decode(ph.cod_moneda,
                    v_mon_fuerte,
                    1,
                    fug_obt_cotizacion(v_mon_fuerte,
                                       ph.fecha)) cotizacion,
             round(nvl(decode(ph.cod_moneda,
                              v_mon_fuerte,
                              ph.monto,
                              (ph.monto / fug_obt_cotizacion(v_mon_fuerte,
                                                             ph.fecha))),
                       0),
                   v_red_fuerte) mto_mon_extranjera,
             ba.nom_completo beneficiario,
             NULL ordenante,
             fug_obt_des_transaccion(ph.cod_modulo,
                                     ph.cod_modalidad,
                                     ph.cod_transaccion) motivo,
             ph.cod_modalidad,
             ph.cod_mod_padre,
             ph.cod_mad_padre,
             ph.cod_tra_padre,
             ph.cod_modulo,
             ph.hora,
             ph.cod_usuario,
             NULL tip_ope_cambio,
             ph.cod_transaccion
        FROM ba_personas     ba,
             ge_cta_clientes gt,
             ge_movimientos  ph,
             ba_monedas      mo
       WHERE ba.cod_persona = gt.cod_persona
         AND gt.nro_cuenta = ph.nro_cuenta
         AND ph.estado = 'N'
         AND gt.relacion = 'P'
         AND ((ph.cod_mod_padre = 6) OR (ph.cod_mod_padre = 9 AND ph.cod_modulo = 6))
         AND ph.cod_transaccion IN (715,
                                    711) -- CAPITAL
         AND ph.fecha BETWEEN v_fec_desde AND v_fec_hasta
         AND ba.cod_persona = v_cod_persona
         AND ph.cod_moneda = mo.cod_moneda
         AND ph.reversado = 'N'
      UNION ALL
      SELECT nvl((SELECT re.val_maximo
                   FROM ba_cod_referencias re
                  WHERE re.dominio = 'TIP_DOC_OPE_RIESGO'
                    AND re.val_minimo = ba.cod_tip_documento),
                 ba.cod_tip_documento) cod_tip_documento,
             ba.nro_documento,
             ph.nro_documento,
             ph.fecha,
             (SELECT sb.cod_tra_instrumento
                FROM ge_tra_instrumentos     sb,
                     ge_tra_instrumentos_det b
               WHERE sb.cod_tra_instrumento = b.cod_tra_instrumento
                 AND b.cod_tra_padre = ph.cod_tra_padre
                 AND b.cod_mod_padre = ph.cod_mod_padre
                 AND b.cod_mad_padre = ph.cod_mad_padre) cod_tipo_instrumento,
             round(nvl(decode(ph.cod_moneda,
                              v_mon_local,
                              ph.monto,
                              (ph.monto * fug_obt_cotizacion(ph.cod_moneda,
                                                             ph.fecha))),
                       0),
                   v_red_local) mto_equ_local,
             gt.nro_cuenta,
             decode(fug_obt_pardinamico('COD_TIP_CUENTA',
                                        ph.cod_modulo,
                                        ph.cod_modalidad,
                                        ph.cod_moneda,
                                        ph.cod_oficina),
                    '0',
                    NULL,
                    fug_obt_pardinamico('COD_TIP_CUENTA',
                                        ph.cod_modulo,
                                        ph.cod_modalidad,
                                        ph.cod_moneda,
                                        ph.cod_oficina)) tip_cuenta,
             mo.cod_mon_bco_central cod_moneda,
             decode(ph.cod_moneda,
                    v_mon_local,
                    0,
                    ph.monto) mto_mon_origen,
             decode(ph.cod_moneda,
                    v_mon_fuerte,
                    1,
                    fug_obt_cotizacion(v_mon_fuerte,
                                       ph.fecha)) cotizacion,
             round(nvl(decode(ph.cod_moneda,
                              v_mon_fuerte,
                              ph.monto,
                              (ph.monto / fug_obt_cotizacion(v_mon_fuerte,
                                                             ph.fecha))),
                       0),
                   v_red_fuerte) mto_mon_extranjera,
             ba.nom_completo beneficiario,
             NULL ordenante,
             fug_obt_des_transaccion(ph.cod_modulo,
                                     ph.cod_modalidad,
                                     ph.cod_transaccion) motivo,
             ph.cod_modalidad,
             ph.cod_mod_padre,
             ph.cod_mad_padre,
             ph.cod_tra_padre,
             ph.cod_modulo,
             ph.hora,
             ph.cod_usuario,
             NULL tip_ope_cambio,
             ph.cod_transaccion
        FROM ba_personas        ba,
             ge_cta_clientes    gt,
             pr_movimientos_his ph,
             ba_monedas         mo
       WHERE ba.cod_persona = gt.cod_persona
         AND gt.nro_cuenta = ph.nro_cuenta
         AND gt.relacion = 'P'
         AND ((ph.cod_mod_padre = 6) OR (ph.cod_mod_padre = 9 AND ph.cod_modulo = 6))
         AND ph.cod_transaccion IN (715,
                                    711) -- CAPITAL
         AND ph.fecha BETWEEN v_fec_desde AND v_fec_hasta
         AND ba.cod_persona = v_cod_persona
         AND ph.cod_moneda = mo.cod_moneda
         AND ph.reversado = 'N'
      UNION ALL -- TARJETAS
      SELECT nvl((SELECT re.val_maximo
                   FROM ba_cod_referencias re
                  WHERE re.dominio = 'TIP_DOC_OPE_RIESGO'
                    AND re.val_minimo = ba.cod_tip_documento),
                 ba.cod_tip_documento) cod_tip_documento,
             ba.nro_documento,
             th.nro_documento,
             th.fecha,
             sb.cod_tra_instrumento cod_tipo_instrumento,
             round(nvl(decode(th.cod_moneda,
                              v_mon_local,
                              th.monto,
                              (th.monto * fug_obt_cotizacion(th.cod_moneda,
                                                             th.fecha))),
                       0),
                   v_red_local) mto_equ_local,
             gt.nro_cuenta,
             decode(fug_obt_pardinamico('COD_TIP_CUENTA',
                                        th.cod_modulo,
                                        th.cod_modalidad,
                                        th.cod_moneda,
                                        th.cod_oficina),
                    '0',
                    NULL,
                    fug_obt_pardinamico('COD_TIP_CUENTA',
                                        th.cod_modulo,
                                        th.cod_modalidad,
                                        th.cod_moneda,
                                        th.cod_oficina)) tipo_cta,
             mo.cod_mon_bco_central,
             decode(th.cod_moneda,
                    v_mon_local,
                    0,
                    th.monto) mto_mon_origen,
             decode(th.cod_moneda,
                    v_mon_fuerte,
                    1,
                    fug_obt_cotizacion(v_mon_fuerte,
                                       th.fecha)) cotizacion,
             round(nvl(decode(th.cod_moneda,
                              v_mon_fuerte,
                              monto,
                              (monto / fug_obt_cotizacion(v_mon_fuerte,
                                                          th.fecha))),
                       0),
                   v_red_fuerte) mto_mon_extranjera,
             ba.nom_completo,
             th.cod_usu_autorizador,
             fug_obt_des_transaccion(th.cod_modulo,
                                     th.cod_modalidad,
                                     th.cod_transaccion),
             th.cod_modalidad,
             th.cod_mod_padre,
             th.cod_mad_padre,
             th.cod_tra_padre,
             th.cod_modulo,
             th.hora,
             th.cod_usuario,
             NULL tip_ope_cambio,
             th.cod_transaccion
        FROM ba_personas             ba,
             ge_cta_clientes         gt,
             ta_movimientos_his      th,
             ge_tra_instrumentos     sb,
             ge_tra_instrumentos_det b,
             ba_monedas              mo
       WHERE ba.cod_persona = gt.cod_persona
         AND gt.nro_cuenta = th.nro_cuenta
         AND gt.relacion = 'P'
         AND ((th.cod_mod_padre = 5) OR (th.cod_mod_padre = 9 AND th.cod_modulo = 5))
         AND sb.cod_tra_instrumento = b.cod_tra_instrumento
         AND b.cod_tra_padre = th.cod_tra_padre
         AND b.cod_mod_padre = th.cod_mod_padre
         AND b.cod_mad_padre = th.cod_mad_padre
         AND fecha BETWEEN v_fec_desde AND v_fec_hasta
         AND ba.cod_persona = v_cod_persona
         AND th.reversado = 'N'
         AND th.cod_moneda = mo.cod_moneda
      UNION ALL -- extractos de tarjetas
      SELECT nvl((SELECT re.val_maximo
                   FROM ba_cod_referencias re
                  WHERE re.dominio = 'TIP_DOC_OPE_RIESGO'
                    AND re.val_minimo = ba.cod_tip_documento),
                 ba.cod_tip_documento) cod_tip_documento,
             ba.nro_documento,
             /*SUBSTR((SELECT TO_CHAR(TO_NUMBER(MAX(T.NRO_TARJETA)))
              FROM TA_TARJETAS T
              WHERE T.NRO_CUENTA = GT.NRO_CUENTA
             ),1,60)*/
             rownum nro_operacion,
             th.fec_cierre,
             '70001' cod_tipo_instrumento,
             round(nvl(decode(ta.cod_moneda,
                              v_mon_local,
                              th.sal_facturado,
                              (th.sal_facturado *
                              fug_obt_cotizacion(ta.cod_moneda,
                                                  th.fec_cierre))),
                       0),
                   v_red_local) mto_equ_local,
             gt.nro_cuenta,
             decode(fug_obt_pardinamico('COD_TIP_CUENTA',
                                        gt.cod_modulo,
                                        gt.cod_modalidad,
                                        ta.cod_moneda,
                                        gt.cod_oficina),
                    '0',
                    NULL,
                    fug_obt_pardinamico('COD_TIP_CUENTA',
                                        gt.cod_modulo,
                                        gt.cod_modalidad,
                                        ta.cod_moneda,
                                        gt.cod_oficina)) tipo_cta,
             mo.cod_mon_bco_central,
             decode(ta.cod_moneda,
                    v_mon_local,
                    0,
                    th.sal_facturado) mto_mon_origen,
             decode(ta.cod_moneda,
                    v_mon_fuerte,
                    1,
                    fug_obt_cotizacion(v_mon_fuerte,
                                       th.fec_cierre)) cotizacion,
             round(nvl(decode(ta.cod_moneda,
                              v_mon_fuerte,
                              th.sal_facturado,
                              (th.sal_facturado /
                              fug_obt_cotizacion(v_mon_fuerte,
                                                  th.fec_cierre))),
                       0),
                   v_red_fuerte) mto_mon_extranjera,
             ba.nom_completo,
             NULL cod_usu_autorizador,
             'DEUDA DEL MES',
             gt.cod_modalidad,
             gt.cod_modulo cod_mod_padre,
             gt.cod_modalidad cod_mad_padre,
             NULL cod_tra_padre,
             gt.cod_modulo cod_modulo,
             NULL hora,
             NULL cod_usuario,
             NULL tip_ope_cambio,
             null 
        FROM ba_personas     ba,
             ge_cta_clientes gt,
             ta_sal_cierres  th,
             ta_cta_tarjetas ta,
             ba_monedas      mo
       WHERE ba.cod_persona = gt.cod_persona
         AND gt.nro_cuenta = th.nro_cuenta
         AND gt.relacion = 'P'
         AND th.nro_cuenta = ta.nro_cuenta
         AND th.fec_cierre BETWEEN v_fec_desde AND v_fec_hasta
         AND ba.cod_persona = v_cod_persona
         AND ta.cod_moneda = mo.cod_moneda
      UNION ALL -- CAMBIOS
      SELECT nvl((SELECT re.val_maximo
                   FROM ba_cod_referencias re
                  WHERE re.dominio = 'TIP_DOC_OPE_RIESGO'
                    AND re.val_minimo = ba.cod_tip_documento),
                 ba.cod_tip_documento) cod_tip_documento,
             ba.nro_documento,
             lm.nro_documento,
             lm.fecha,
             (SELECT sb.cod_tra_instrumento
                FROM ge_tra_instrumentos     sb,
                     ge_tra_instrumentos_det b
               WHERE sb.cod_tra_instrumento = b.cod_tra_instrumento
                 AND b.cod_tra_padre = lm.cod_tra_padre
                 AND b.cod_mod_padre = lm.cod_mod_padre
                 AND b.cod_mad_padre = lm.cod_mad_padre) cod_tip_instrumento,
             nvl(lm.mto_equ_local,
                 0),
             NULL nro_cuenta,
             decode(fug_obt_pardinamico('COD_TIP_CUENTA',
                                        lm.cod_modulo,
                                        lm.cod_modalidad,
                                        lm.cod_moneda,
                                        lm.cod_oficina),
                    '0',
                    NULL,
                    fug_obt_pardinamico('COD_TIP_CUENTA',
                                        lm.cod_modulo,
                                        lm.cod_modalidad,
                                        lm.cod_moneda,
                                        lm.cod_oficina)) tipo_cta,
             mo.cod_mon_bco_central,
             decode(lm.cod_moneda,
                    v_mon_local,
                    0,
                    lm.monto) mto_mon_origen,
             decode(lm.cod_moneda,
                    v_mon_fuerte,
                    1,
                    fug_obt_cotizacion(v_mon_fuerte,
                                       lm.fecha)) cotizacion,
             round(nvl(decode(lm.cod_moneda,
                              v_mon_fuerte,
                              monto,
                              (monto / fug_obt_cotizacion(v_mon_fuerte,
                                                          lm.fecha))),
                       0),
                   v_red_fuerte) mto_mon_extranjera,
             ba.nom_completo,
             lm.cod_usu_autorizador,
             fug_obt_des_transaccion(lm.cod_modulo,
                                     lm.cod_modalidad,
                                     lm.cod_transaccion),
             lm.cod_modalidad,
             lm.cod_mod_padre,
             lm.cod_mad_padre,
             lm.cod_tra_padre,
             lm.cod_modulo,
             lm.hora,
             lm.cod_usuario,
             lm.cod_tip_ope_cambio tip_ope_cambio,
             lm.cod_transaccion
        FROM ba_personas ba,
             lc_movimientos_his lm,
             (SELECT fecha,
                     hora,
                     cod_usuario,
                     nro_documento,
                     nro_documento2 cod_persona,
                     concepto
                FROM lc_movimientos_his
               WHERE cod_transaccion = 760) cl,
             lc_tip_operaciones c,
             ba_monedas mo
       WHERE lm.fecha BETWEEN v_fec_desde AND v_fec_hasta
         AND lm.cod_tip_ope_cambio(+) = c.cod_tip_operacion
         AND lm.nro_documento = cl.nro_documento(+)
         AND lm.cod_usuario = cl.cod_usuario(+)
         AND lm.fecha = cl.fecha
         AND lm.hora = cl.hora
         AND ba.cod_persona = cl.cod_persona
         AND c.cod_tip_ope_bcp IS NOT NULL -- ESTA ES LA PARTE DE ARRIBA DEL MOVIMIENTO
         AND ba.cod_persona = v_cod_persona
         AND lm.cod_moneda = mo.cod_moneda
         AND ((lm.cod_mod_padre = 7) OR (lm.cod_mod_padre = 9 AND lm.cod_modulo = 7))
         AND lm.reversado = 'N'
         AND ((lm.cod_mad_padre IN (71,
                                    72) AND lm.nro_secuencia = 1) OR
             (lm.cod_mad_padre IN (73,
                                    74) AND
             lm.nro_secuencia IN (1,
                                    2)))
         AND lm.cod_mad_padre IN (71,
                                  72,
                                  73,
                                  74)
      UNION ALL
      SELECT nvl((SELECT re.val_maximo
                   FROM ba_cod_referencias re
                  WHERE re.dominio = 'TIP_DOC_OPE_RIESGO'
                    AND re.val_minimo = ba.cod_tip_documento),
                 ba.cod_tip_documento) cod_tip_documento,
             ba.nro_documento,
             lm.nro_documento,
             lm.fecha,
             (SELECT sb.cod_tra_instrumento
                FROM ge_tra_instrumentos     sb,
                     ge_tra_instrumentos_det b
               WHERE sb.cod_tra_instrumento = b.cod_tra_instrumento
                 AND b.cod_tra_padre = lm.cod_tra_padre
                 AND b.cod_mod_padre = lm.cod_mod_padre
                 AND b.cod_mad_padre = lm.cod_mad_padre) cod_tip_instrumento,
             nvl(lm.mto_equ_local,
                 0),
             NULL nro_cuenta,
             decode(fug_obt_pardinamico('COD_TIP_CUENTA',
                                        lm.cod_modulo,
                                        lm.cod_modalidad,
                                        lm.cod_moneda,
                                        lm.cod_oficina),
                    '0',
                    NULL,
                    fug_obt_pardinamico('COD_TIP_CUENTA',
                                        lm.cod_modulo,
                                        lm.cod_modalidad,
                                        lm.cod_moneda,
                                        lm.cod_oficina)) tipo_cta,
             mo.cod_mon_bco_central,
             decode(lm.cod_moneda,
                    v_mon_local,
                    0,
                    lm.monto) mto_mon_origen,
             decode(lm.cod_moneda,
                    v_mon_fuerte,
                    1,
                    fug_obt_cotizacion(v_mon_fuerte,
                                       lm.fecha)) cotizacion,
             round(nvl(decode(lm.cod_moneda,
                              v_mon_fuerte,
                              monto,
                              (monto / fug_obt_cotizacion(v_mon_fuerte,
                                                          lm.fecha))),
                       0),
                   v_red_fuerte) mto_mon_extranjera,
             ba.nom_completo,
             lm.cod_usu_autorizador,
             fug_obt_des_transaccion(lm.cod_modulo,
                                     lm.cod_modalidad,
                                     lm.cod_transaccion),
             lm.cod_modalidad,
             lm.cod_mod_padre,
             lm.cod_mad_padre,
             lm.cod_tra_padre,
             lm.cod_modulo,
             lm.hora,
             lm.cod_usuario,
             lm.cod_tip_ope_cambio tip_ope_cambio,
             lm.cod_transaccion
        FROM ba_personas ba,
             ge_movimientos lm,
             (SELECT fecha,
                     hora,
                     cod_usuario,
                     nro_documento,
                     nro_documento2 cod_persona,
                     concepto
                FROM ge_movimientos
               WHERE cod_transaccion = 760
                 AND estado = 'N') cl,
             lc_tip_operaciones c,
             ba_monedas mo
       WHERE lm.fecha BETWEEN v_fec_desde AND v_fec_hasta
         AND lm.estado = 'N'
         AND lm.cod_tip_ope_cambio(+) = c.cod_tip_operacion
         AND lm.nro_documento = cl.nro_documento(+)
         AND lm.cod_usuario = cl.cod_usuario(+)
         AND lm.fecha = cl.fecha
         AND lm.hora = cl.hora
         AND ba.cod_persona = cl.cod_persona
         AND c.cod_tip_ope_bcp IS NOT NULL
         AND ba.cod_persona = v_cod_persona
         AND lm.cod_moneda = mo.cod_moneda
         AND ((lm.cod_mod_padre = 7) OR (lm.cod_mod_padre = 9 AND lm.cod_modulo = 7))
         AND lm.reversado = 'N'
         AND ((lm.cod_mad_padre IN (71,
                                    72) AND lm.nro_secuencia = 1) OR
             (lm.cod_mad_padre IN (73,
                                    74) AND
             lm.nro_secuencia IN (1,
                                    2)))
         AND lm.cod_mad_padre IN (71,
                                  72,
                                  73,
                                  74)
         union all   -- CUENTAS CORRIENTES
         select nvl((select re.val_maximo
                     from ba_cod_referencias re
                    where re.dominio = 'TIP_DOC_OPE_RIESGO'
                      and re.val_minimo = ba.cod_tip_documento),
              ba.cod_tip_documento),
              ba.nro_documento,
              cm.nro_documento,
              cm.fecha ,
              (select sb.cod_tra_instrumento
                 from ge_tra_instrumentos sb, ge_tra_instrumentos_det b
                where sb.cod_tra_instrumento = b.cod_tra_instrumento
                  and b.cod_tra_padre = cm.cod_tra_padre
                  and b.cod_mod_padre = cm.cod_mod_padre
                  and b.cod_mad_padre = cm.cod_mad_padre),
              round(nvl(decode(cm.cod_moneda,
                               v_mon_local,
                               cm.monto,
                               (cm.monto *
                               fug_obt_cotizacion(cm.cod_moneda, cm.fecha))),
                        0),
                    v_red_local),
              gi.nro_cuenta nro_cuenta,
              decode(fug_obt_pardinamico('COD_TIP_CUENTA',
                                         cm.cod_modulo,
                                         cm.cod_modalidad,
                                         cm.cod_moneda,
                                         cm.cod_oficina),
                     '0',
                     NULL,
                     fug_obt_pardinamico('COD_TIP_CUENTA',
                                         cm.cod_modulo,
                                         cm.cod_modalidad,
                                         cm.cod_moneda,
                                         cm.cod_oficina)),
              mo.cod_mon_bco_central COD_MONEDA, --linea modificada
              decode(cm.cod_moneda, v_mon_local, 0, cm.monto),
              decode(cm.cod_moneda,
                     v_mon_fuerte,
                     1,
                     fug_obt_cotizacion(v_mon_fuerte, cm.fecha)),
              round(nvl(decode(cm.cod_moneda,
                               v_mon_fuerte,
                               monto,
                               (monto /
                               fug_obt_cotizacion(v_mon_fuerte, cm.fecha))),
                        0),
                    v_red_fuerte),
              ba.nom_completo ,
              NULL,
              fug_obt_des_transaccion(cm.cod_modulo,
                                      cm.cod_modalidad,
                                      cm.cod_transaccion),
              cm.cod_modalidad,
              cm.cod_mod_padre,
              cm.cod_mad_padre,
              cm.cod_tra_padre,
              cm.cod_modulo,
              cm.hora,
              cm.cod_usuario,
              NULL,
              cm.cod_transaccion
         from ba_personas        ba,
              ge_cta_clientes    gi,
              cc_movimientos_his cm,
              ge_transacciones   tr,
              ba_monedas         mo
        where ba.cod_persona = gi.cod_persona
          and gi.nro_cuenta = cm.nro_cuenta
          and gi.relacion = 'P'
          and cm.fecha BETWEEN v_fec_desde AND v_fec_hasta
          and ba.cod_persona = v_cod_persona
          and cm.reversado = 'N'
          and cm.nro_documento IS NOT NULL -- LOS MOV DEL SISTEMA TIENEN NULO ESTE DATO
          and cm.monto IS NOT NULL
          and cm.cod_moneda = mo.cod_moneda
          and cm.cod_transaccion = tr.cod_transaccion
          and cm.cod_modulo = tr.cod_modulo
          and cm.cod_modalidad = tr.cod_modalidad
          and nvl(tr.ve_cliente, 'N') = 'S'; -- SOLO LOS QUE APARECEN EN EL EXTRACTO DEL CLIENTE;                         ;
   CURSOR registros IS
      SELECT *
        FROM ge_gen_ope_riesgo da
       WHERE da.cod_persona = v_cod_persona
         AND da.fec_desde = v_fec_desde
         AND da.fec_hasta = v_fec_hasta;
   ----------------------------------------------------------------------------------------------------
   ----------------------------------------------------------------------------------------------------
   -------------------- CARGAR TABLA ------------------------------------------------------------------
BEGIN
   EXECUTE IMMEDIATE ('truncate table ge_gen_ope_riesgo'); --DYDMR-332. CB.
   
   v_mon_local  := pag_gen.fu_obt_mon_local;
   v_mon_fuerte := pag_gen.fu_obt_mon_fuerte;
   v_red_local  := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                       1,
                                       NULL,
                                       v_mon_local,
                                       NULL);
   v_red_fuerte := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                       1,
                                       NULL,
                                       v_mon_fuerte,
                                       NULL);
   FOR x IN personas LOOP
      BEGIN
         v_cod_persona := x.cod_persona;
         --Obtengo el rango de fecha para la generacion de lo movimientos
         IF p_fec_desde IS NULL THEN
            v_fec_desde := fue_per_dat_adicional(v_cod_persona,
                                                 'FEC_INI_OPE_RIESGO');
         ELSE
            v_fec_desde := p_fec_desde;
         END IF;
         IF p_fec_hasta IS NULL THEN
            v_fec_hasta := fue_per_dat_adicional(v_cod_persona,
                                                 'FEC_FIN_OPE_RIESGO');
         ELSE
            v_fec_hasta := p_fec_hasta;
         END IF;

         FOR i IN movim LOOP
            BEGIN
               v_cod_mon_des_arb      := NULL;
               v_cot_dest             := NULL;
               v_beneficiario         := NULL;
               v_cod_swi_banco        := NULL;
               v_nro_cta_referencia   := NULL;
               v_nom_beneficiario     := NULL;
               v_nom_solicitante      := NULL;
               v_observacion          := NULL;
               v_cod_bco_corresponsal := NULL;
               v_saldo                := NULL;
               v_saldo                := NULL;
               v_cda_beneficiario     := NULL;

               IF i.cod_mod_padre = 7 THEN
                  IF i.cod_mad_padre = 73 THEN
                     -- si es arbitraje
                     BEGIN
                        SELECT mo.cod_mon_bco_central,
                               cotizacion
                          INTO v_cod_mon_des_arb,
                               v_cot_dest
                          FROM lc_movimientos_his lc,
                               ba_monedas         mo
                         WHERE i.hora = lc.hora
                           AND i.fec_operacion = lc.fecha
                           AND i.cod_usuario = lc.cod_usuario
                           AND nro_secuencia = 2
                           AND lc.cod_moneda = mo.cod_moneda;
                     EXCEPTION
                        WHEN no_data_found THEN
                           BEGIN
                              -- OMM 30/05/2016 Se ajusta por Incidencia DYDMR-3946
                              SELECT mo.cod_mon_bco_central,
                                     cotizacion
                                INTO v_cod_mon_des_arb,
                                     v_cot_dest
                                FROM gv_movimientos ge,
                                     ba_monedas     mo
                               WHERE i.hora = ge.hora
                                 AND i.fec_operacion = ge.fecha
                                 AND i.cod_usuario = ge.cod_usuario
                                 AND ge.nro_secuencia = 2
                                 AND ge.cod_moneda = mo.cod_moneda;
                           EXCEPTION
                              WHEN OTHERS THEN
                                 raise_application_error(-20000, 'Error en generación comp_1 ' || SQLERRM);
                           END;
                        WHEN OTHERS THEN
                           raise_application_error(-20000, 'Error en generación comp_2 ' || SQLERRM);
                     END;
                  END IF;

                  BEGIN
                     SELECT o.afe_transferencia
                       INTO v_afe_transf
                       FROM lc_tip_operaciones o
                      WHERE o.cod_tip_operacion = i.tip_ope_cambio;
                     -- obtenemos datos de la transferencia
                     IF v_afe_transf = 'S' THEN
                        SELECT lt.cod_aba_banco,
                               lt.cod_swi_banco,
                               lt.nro_cta_referencia,
                               substr(lt.nom_beneficiario,
                                      1,
                                      100),
                               lt.nom_solicitante,
                               lt.cod_bco_corresponsal,
                               fug_obt_des_banco(lt.cod_bco_corresponsal),
                               substr(lt.nom_beneficiario,
                                      1,
                                      100)
                          INTO v_cod_aba_banco,
                               v_cod_swi_banco,
                               v_nro_cta_referencia,
                               v_nom_beneficiario,
                               v_nom_solicitante,
                               v_cod_bco_corresponsal,
                               v_banco,
                               v_beneficiario
                          FROM lc_transferencias lt
                         WHERE lt.nro_operacion = i.nro_operacion;
                     END IF;
                  EXCEPTION
                     WHEN OTHERS THEN
                        NULL;
                  END;
               END IF;
               --
               IF i.cod_modulo = 3 THEN
                  IF i.nro_cuenta IS NOT NULL THEN
                     BEGIN
                        SELECT gc.sal_contable
                          INTO v_saldo
                          FROM ge_cuentas gc
                         WHERE gc.nro_cuenta = i.nro_cuenta;
                        BEGIN
                           SELECT substr(beneficiario,
                                         1,
                                         100)
                             INTO v_cda_beneficiario
                             FROM ah_cta_certificados ac
                            WHERE ac.nro_cuenta = i.nro_cuenta;
                        EXCEPTION
                           WHEN OTHERS THEN
                              v_cda_beneficiario := NULL;
                        END;
                     EXCEPTION
                        WHEN OTHERS THEN
                           raise_application_error(-20002,'Error en generación comp_3 ' || SQLERRM);
                     END;
                  END IF;
                  IF v_cda_beneficiario IS NOT NULL THEN
                     v_beneficiario := v_cda_beneficiario;
                  ELSE
                     v_beneficiario := v_nom_beneficiario;
                  END IF;
                  -- OBTENGO EL NUMERO DE FACTURA DE LAS OPERACIONES DE AHORROS
                  IF i.cod_modalidad = 31 AND i.nro_operacion IS NULL THEN
                     BEGIN
                        SELECT nro_factura
                          INTO v_nro_factura
                          FROM cb_lib_ventas_det a
                         WHERE a.fecha = i.fec_operacion
                           AND a.hora = i.hora
                           AND a.cod_usuario = i.cod_usuario;
                     EXCEPTION
                        WHEN no_data_found THEN
                           NULL;
                        WHEN OTHERS THEN
                           raise_application_error(-20000,'Error en generación comp_4 ' || SQLERRM);
                     END;
                  END IF;
               END IF;



               -- se pasa null en el código de entidad porque está como default en la tabla
               INSERT INTO ge_gen_ope_riesgo
                  (cod_persona,
                   fec_desde,
                   fec_hasta,
                   cod_tip_documento,
                   --1
                   nro_documento,
                   nro_operacion,
                   fec_operacion,
                   cod_tip_instrumento,
                   --5
                   mto_equ_local,
                   nro_cuenta,
                   tip_cuenta,
                   cod_moneda,
                   mto_mon_origen,
                   --10
                   cotizacion,
                   mto_mon_extranjera,
                   cod_mon_destino,
                   cot_mon_destino,
                   --
                   cod_oficina,
                   nom_ent_externa,
                   nom_ofi_ent_externa,
                   nro_cta_ent_externa,
                   cod_pai_ent_externa,
                   --20
                   nom_ciu_ent_externa,
                   nro_cheque,
                   beneficiario,
                   ordenante,
                   nro_boleta,
                   --25
                   motivo,
                   observacion,
                   comentario,
                   saldo,
                   cod_pai_bco_intermediario,
                   --30
                   nom_bco_intermediario,
                   cod_aba_bco_intermediario,
                   cod_swi_bco_intermediario,
                   nom_corresponsal) --34
               VALUES
                  (v_cod_persona,
                   v_fec_desde,
                   v_fec_hasta,
                   i.cod_tip_documento,
                   i.nro_documento,
                   i.nro_operacion,
                   i.fec_operacion,
                   i.cod_tip_instrumento, --a veces lo inserta nulo porque en sus movimientos no se encuentra el equivalente
                   i.mto_equ_local,
                   i.nro_cuenta,
                   i.tip_cuenta,
                   i.cod_moneda,
                   i.mto_mon_origen,
                   i.cotizacion,
                   i.mto_mon_extranjera,
                   v_cod_mon_des_arb,
                   v_cot_dest,
                   --                    null,--15  se inserta null porque el valor está como default en la tabla
                   1,
                   --aqui está faltando la agencia
                   substr(v_banco,
                          1,
                          30),
                   -- corresponsal para transferencias
                   NULL,
                   -- sucursal del banco corresopnsal
                   v_nro_cta_referencia,
                   NULL,
                   --20
                   NULL,
                   NULL,
                   substr(v_beneficiario,
                          1,
                          100),
                   substr(v_nom_solicitante,
                          1,
                          100),
                   nvl(i.nro_operacion,
                       v_nro_factura),
                   --25
                   substr(i.motivo,
                          1,
                          50), -- Debe ser 50 s/ Res 16. DYDMR-332. CB.
                   substr(v_observacion,
                          1,
                          50),
                   NULL,
                   v_saldo,
                   NULL,
                   --30
                   NULL,
                   substr(TRIM(v_cod_aba_banco),
                          1,
                          18),
                   substr(TRIM(v_cod_swi_banco),
                          1,
                          18),
                   substr(TRIM(v_banco),
                          1,
                          30));
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Error en generación comp_5 ' || SQLERRM);
            END;

        ------Alejandro Ferreira 20/11/2013------
     ------Si inserta el codigo de instrumento nulo, se busca el movimiento correspondiente
     ------se pregunta que tipo de movimiento es C o D y se setea el codigo de instrumento correspondiente
     ------sin tener en cuenta la parametrizaciones pero si la resolucion 16 segun SEPRELAD

            if i.cod_tip_instrumento is null then
                
                  begin 
                    select tipo 
                    into   v_tip_movimiento
                    from   ge_transacciones 
                    where cod_transaccion = i.cod_transaccion
                    and   cod_modulo = i.cod_modulo
                    and   cod_modalidad = i.cod_modalidad;
                  exception 
                  when others then 
                      raise_application_error(-20009,'Error en obt trans. '||i.cod_transaccion ||'-'||i.cod_modulo||'-'||i.cod_modalidad||'-'||sqlerrm );  
                  end;   
                    --c.cod_tip_movimiento := v_tip_movimiento;
                  if v_tip_movimiento = 'D' then
                     select inst.cod_tra_instrumento
                     into v_cod_tra_instrumento
                     from ge_tra_instrumentos inst
                     where cod_tra_instrumento = 140001;
                  else
                     select inst.cod_tra_instrumento
                     into v_cod_tra_instrumento
                     from ge_tra_instrumentos inst
                     where cod_tra_instrumento = 140002;
                  end if;

                  --seteo la variable--
                  update ge_gen_ope_riesgo ope
                  set ope.cod_tip_instrumento = v_cod_tra_instrumento
                  where ope.cod_persona = v_cod_persona
                  and ope.fec_operacion = i.fec_operacion
                  and ope.nro_operacion = i.nro_operacion;

               
            end if;
         END LOOP;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000,'Error en generación comp_6 ' || SQLERRM);
      END;
   END LOOP;

   ----------------------------------------------------------------------------------------------------
   ----------------------------------------------------------------------------------------------------
   -------------------- GENERAR ARCHIVO ------------------------------------------------------------------
   FOR x IN personas LOOP
      BEGIN
         v_cod_persona := x.cod_persona;

         IF utl_file.is_open(v_archivo) THEN
            utl_file.fclose(v_archivo);
         END IF;
         v_directorio := 'FONDOS';
         v_nom_ascii  := 'SEPRELAD_ITC_' || v_cod_persona || '.TXT';
         v_archivo    := utl_file.fopen(v_directorio,
                                        v_nom_ascii,
                                        'w');
         ------ CARGAR CABECERA
         v_seprelad := 'COD_TIPO_ID'; --1
         v_seprelad := v_seprelad || chr(9) || 'NRO_IDENTIFICACION'; --2
         v_seprelad := v_seprelad || chr(9) || 'NRO_OPERACION'; --3
         v_seprelad := v_seprelad || chr(9) || 'F_OPERACION'; --4
         v_seprelad := v_seprelad || chr(9) || 'COD_TIPO_INSTRUMENTO'; --5
         v_seprelad := v_seprelad || chr(9) || 'MTO_MONEDA_LOCAL'; --6
         v_seprelad := v_seprelad || chr(9) || 'NRO_CTA_SO'; --7
         v_seprelad := v_seprelad || chr(9) || 'TIPO_CTA'; --8
         v_seprelad := v_seprelad || chr(9) || 'COD_MONEDA'; --11
         v_seprelad := v_seprelad || chr(9) || 'MTO_MONEDA_ORIGEN'; --12
         v_seprelad := v_seprelad || chr(9) || 'COTIZACION'; --13
         v_seprelad := v_seprelad || chr(9) || 'MONTO_DOLARES'; --14
         v_seprelad := v_seprelad || chr(9) || 'COD_MONEDA_DESTINO'; --15
         v_seprelad := v_seprelad || chr(9) || 'COTIZ_MONEDA_DESTINO'; --16
         v_seprelad := v_seprelad || chr(9) || 'COD_ENTIDAD_SO'; --9
         v_seprelad := v_seprelad || chr(9) || 'COD_SUCURSAL_SO'; --10
         v_seprelad := v_seprelad || chr(9) || 'COD_OTRA_ENTIDAD'; --17
         v_seprelad := v_seprelad || chr(9) || 'COD_SUC_OTRA_ENTIDAD'; --18
         v_seprelad := v_seprelad || chr(9) || 'NRO_CTA_OTRA_ENTIDAD'; --19
         v_seprelad := v_seprelad || chr(9) || 'COD_PAIS_OTRA_ENTIDAD'; --20
         v_seprelad := v_seprelad || chr(9) || 'CIUDAD_OTRA_ENTIDAD'; --21
         v_seprelad := v_seprelad || chr(9) || 'NRO_CHEQUE'; --22
         v_seprelad := v_seprelad || chr(9) || 'BENEFICIARIO'; --23
         v_seprelad := v_seprelad || chr(9) || 'ORDENANTE'; --24
         v_seprelad := v_seprelad || chr(9) || 'NRO_DOCUMENTO'; --25
         v_seprelad := v_seprelad || chr(9) || 'MOTIVO'; --26
         v_seprelad := v_seprelad || chr(9) || 'OBSERVACION'; --27
         v_seprelad := v_seprelad || chr(9) || 'COMENTARIOS'; --28
         v_seprelad := v_seprelad || chr(9) || 'SALDO'; --29
         v_seprelad := v_seprelad || chr(9) || 'COD_PAIS_BCO_INTERMEDIARIO'; --30
         v_seprelad := v_seprelad || chr(9) || 'BCO_INTERMEDIARIO'; --31
         v_seprelad := v_seprelad || chr(9) || 'COD_ABA'; --32
         v_seprelad := v_seprelad || chr(9) || 'COD_SWIFT'; --33
         v_seprelad := v_seprelad || chr(9) || 'CORRESPONSAL'; --34
         utl_file.put_line(v_archivo,
                           v_seprelad);
         v_seprelad := NULL;

         FOR i IN registros LOOP
            BEGIN

               v_seprelad := i.cod_tip_documento; --1
               v_seprelad := v_seprelad || chr(9) || i.nro_documento; --2
               v_seprelad := v_seprelad || chr(9) || i.nro_operacion; --3
               v_seprelad := v_seprelad || chr(9) || to_char(i.fec_operacion,
                                                             'YYYY-MM-DD'); --4
               v_seprelad := v_seprelad || chr(9) || i.cod_tip_instrumento; --5
               v_seprelad := v_seprelad || chr(9) || i.mto_equ_local; --6
               v_seprelad := v_seprelad || chr(9) || i.nro_cuenta; --7
               v_seprelad := v_seprelad || chr(9) || i.tip_cuenta; --8
               v_seprelad := v_seprelad || chr(9) || i.cod_moneda; --11
               v_seprelad := v_seprelad || chr(9) || REPLACE(to_char(i.mto_mon_origen),
                                                             ',',
                                                             '.'); --12
               v_seprelad := v_seprelad || chr(9) || REPLACE(to_char(i.cotizacion),
                                                             ',',
                                                             '.'); --13
               v_seprelad := v_seprelad || chr(9) || REPLACE(to_char(i.mto_mon_extranjera),
                                                             ',',
                                                             '.'); --14
               v_seprelad := v_seprelad || chr(9) || i.cod_mon_destino; --15
               v_seprelad := v_seprelad || chr(9) || REPLACE(to_char(i.cot_mon_destino),
                                                             ',',
                                                             '.'); --16
               v_seprelad := v_seprelad || chr(9) || i.cod_entidad; --9
               v_seprelad := v_seprelad || chr(9) || i.cod_oficina; --10
               v_seprelad := v_seprelad || chr(9) || i.nom_ent_externa; --17
               v_seprelad := v_seprelad || chr(9) || i.nom_ofi_ent_externa; --18
               v_seprelad := v_seprelad || chr(9) || i.nro_cheque; --19
               v_seprelad := v_seprelad || chr(9) || i.cod_pai_ent_externa; --20
               v_seprelad := v_seprelad || chr(9) || i.nom_ciu_ent_externa; --21
               v_seprelad := v_seprelad || chr(9) || i.nro_cheque; --22
               v_seprelad := v_seprelad || chr(9) || i.beneficiario; --23
               v_seprelad := v_seprelad || chr(9) || i.ordenante; --24
               v_seprelad := v_seprelad || chr(9) || i.nro_boleta; --25
               v_seprelad := v_seprelad || chr(9) || i.motivo; --26
               v_seprelad := v_seprelad || chr(9) || i.observacion; --27
               v_seprelad := v_seprelad || chr(9) || v_observacion; --28
               v_seprelad := v_seprelad || chr(9) || REPLACE(to_char(i.saldo),
                                                             ',',
                                                             '.'); --29
               v_seprelad := v_seprelad || chr(9) || i.cod_pai_bco_intermediario; --30
               v_seprelad := v_seprelad || chr(9) || i.nom_bco_intermediario; --31
               v_seprelad := v_seprelad || chr(9) || i.cod_aba_bco_intermediario; --32
               v_seprelad := v_seprelad || chr(9) || i.cod_swi_bco_intermediario; --33
               v_seprelad := v_seprelad || chr(9) || i.nom_corresponsal; --34
               utl_file.put_line(v_archivo,
                                 v_seprelad);
            EXCEPTION

               WHEN no_data_found THEN
                  --- Fin del archivo
                  utl_file.fclose(v_archivo);
               WHEN utl_file.invalid_path THEN
                  utl_file.fclose(v_archivo);
                  raise_application_error(-20000,
                                          'Directorio invalido');
               WHEN utl_file.invalid_mode THEN
                  utl_file.fclose(v_archivo);
                  raise_application_error(-20000,
                                          'Modo invalido');
               WHEN utl_file.invalid_filehandle THEN
                  utl_file.fclose(v_archivo);
                  raise_application_error(-20000,
                                          'Invalida Filehandle');
               WHEN utl_file.invalid_operation THEN
                  --- Fin del archivo
                  utl_file.fclose(v_archivo);
               WHEN utl_file.read_error THEN
                  utl_file.fclose(v_archivo);
                  raise_application_error(-20000,
                                          'Lectura errada');
               WHEN utl_file.write_error THEN
                  utl_file.fclose(v_archivo);
                  raise_application_error(-20000,
                                          'Escritura errada');
               WHEN utl_file.internal_error THEN
                  utl_file.fclose(v_archivo);
                  raise_application_error(-20000,
                                          'Error interno');
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Error en generación comp_7 ' || SQLERRM);
            END;
         END LOOP; -- FIN CURSOR MOVIM

         UPDATE ba_per_dat_adicionales
            SET val_parametro = 'N'
          WHERE parametro = 'GEN_OPE_RIESGO'
            AND cod_persona = x.cod_persona;

      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Error en generación comp_8 ' || SQLERRM);
      END;
   END LOOP; -- FIN CURSOR PERSONAS
   utl_file.fclose(v_archivo);

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20010,
                              'Error al generar operaciones sospechosas para la persona = ' ||
                              v_cod_persona || SQLERRM);
END;
/

