CREATE OR REPLACE PACKAGE BODY IT.pag_deb IS
   v_hora             ge_movimientos.hora%TYPE;
   v_nro_secuencia    ge_movimientos.nro_secuencia%TYPE := 0;
   v_mto_deb_ml       ge_movimientos.monto%TYPE;
   v_mto_gan_ml       ge_movimientos.monto%TYPE;
   v_mto_seg_ml       ge_movimientos.monto%TYPE;
   v_mto_imp_ml       ge_movimientos.monto%TYPE;
   v_cod_ente         ge_entes.cod_ente%TYPE := fu_obt_ente;
   c_cod_tra_padre    ge_movimientos.cod_transaccion%TYPE := fug_obt_parentes(v_cod_ente,
                                                                              'TRA_PAD_SEG_TAR_DEB');
   c_cod_tra_seguro   ge_movimientos.cod_transaccion%TYPE := fug_obt_parentes(v_cod_ente,
                                                                              'TRA_CRE_SEG_TAR_DEB');
   c_cod_tra_ganancia ge_movimientos.cod_transaccion%TYPE := fug_obt_parentes(v_cod_ente,
                                                                              'TRA_GAN_SEG_TAR_DEB');
   c_cod_tra_dis_gan  ge_movimientos.cod_transaccion%TYPE := fug_obt_parentes(v_cod_ente,
                                                                              'TRA_DIS_SEG_TAR_DEB');
   c_cod_tra_alta     ge_movimientos.cod_transaccion%TYPE := fug_obt_parentes(v_cod_ente,
                                                                              'TRA_ALT_SEG_TAR_DEB');
   c_cod_tra_iva      ge_movimientos.cod_transaccion%TYPE := fug_obt_parentes(v_cod_ente,
                                                                              'TRA_IVA_SEG_TAR_DEB');
   /*c_cod_tra_costo    ge_movimientos.cod_transaccion%TYPE := fug_obt_parentes(v_cod_ente,
   'TRA_COS_SEG_TAR_DEB');*/
   c_mto_seguro       ge_movimientos.monto%TYPE := fug_obt_parentes(v_cod_ente,
                                                                    'MTO_CRE_SEG_TAR_DEB');
   c_mto_debito       ge_movimientos.monto%TYPE := fug_obt_parentes(v_cod_ente,
                                                                    'MTO_DEB_SEG_TAR_DEB');
   v_mto_debito       ge_movimientos.monto%TYPE;
   v_mto_ganancia     ge_movimientos.monto%TYPE;
   v_mto_seguro       ge_movimientos.monto%TYPE;
   v_mto_impuesto     ge_movimientos.monto%TYPE;
   v_cod_tas_ganancia ge_movimientos.cod_tasa%TYPE;
   v_val_tas_ganancia ge_movimientos.val_tasa%TYPE;
   v_cod_tra_impuesto ge_movimientos.cod_transaccion%TYPE;
   v_cod_tas_impuesto ge_movimientos.cod_tasa%TYPE;
   v_val_tas_impuesto ge_movimientos.val_tasa%TYPE;
   v_cod_mon_local    ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
   v_cotizacion       ge_cotizaciones.val_conversion%TYPE;
   v_redondeo         NUMBER(5);
   v_cod_oficina      ba_oficinas.cod_oficina%TYPE := fug_obt_ofi_usuario(USER);
   v_fec_actual       ge_movimientos.fecha%TYPE := pag_cal.fu_obt_fec_actual(4);
   rg_movs            ge_movimientos%ROWTYPE;
   v_es_nocturno      VARCHAR2(1) := 'N';
   v_fec_movimiento   date;

   FUNCTION fu_obt_ente RETURN VARCHAR2 IS
   BEGIN
      SELECT cod_ente
        INTO v_cod_ente
        FROM ge_entes
       WHERE tipo = 'ST'
         AND rownum = 1;
      RETURN v_cod_ente;
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000, 'Ente para seguro c/fraude TD no definido');
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Al Obt.Ente:' || SQLERRM);
   END fu_obt_ente;

   PROCEDURE pr_ins_seg_fra IS
      v_mto_ganancia     ge_movimientos.monto%TYPE;
      --v_mto_credito      ge_movimientos.monto%TYPE;
      v_mto_cre_ml       ge_movimientos.monto%TYPE;
      v_mto_neto         ge_movimientos.monto%TYPE;
      v_mto_net_ml       ge_movimientos.monto%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_cod_mon_anterior ba_monedas.cod_moneda%TYPE;
      v_cantidad         NUMBER;
      v_mto_imp_cta      ge_movimientos.monto%TYPE;
      v_mto_acu_ml       ge_movimientos.monto%TYPE;
      v_mto_acumulado    ge_movimientos.monto%TYPE;
      v_por_ganancia     NUMBER(16, 4);
      v_nro_cta_local    ge_cuentas.nro_cuenta%TYPE := fug_obt_parentes(v_cod_ente,
                                                                        'CTA_SEG_TAR_DEB_GS');
     CURSOR c_altas IS
         SELECT DISTINCT t.nro_cuenta, MAX(nvl(fec_activacion, fec_ingreso)) fec_activacion,
                         g.cod_moneda, t.embozado, t.nro_tarjeta, t.fec_vencimiento, p.cod_persona,
                         t.nro_emision
           FROM ah_tar_debitos t, ba_per_fisicas p, ge_cuentas g
          WHERE t.nro_cuenta = g.nro_cuenta
            AND g.cod_modulo in (3,4)
            AND t.cod_persona = p.cod_persona
            AND p.cod_persona = fug_obt_cli_principal(t.nro_cuenta)
            AND t.tar_activa = 'S'
            AND g.estado = 'N'
            AND t.cod_est_solicitud NOT IN (15, 16, 17)
            AND t.nro_tarjeta IS NOT NULL
            AND t.adherente = '00'
            AND t.nro_emision = (SELECT MAX(d.nro_emision)
                                   FROM ah_tar_debitos d
                                  WHERE d.nro_cuenta = t.nro_cuenta
                                    AND d.cod_persona = t.cod_persona
                                    AND d.adherente = t.adherente
                                    AND d.nro_bin = t.nro_bin)
            /*AND EXISTS (SELECT 1
                          FROM gv_movimientos g
                         WHERE g.nro_cuenta = t.nro_cuenta
                           AND g.fecha > v_fec_movimiento)*/
            --- DYDMR-2117
            AND ( EXISTS (SELECT 1
                            FROM ah_movimientos_his g
                           WHERE g.nro_cuenta = t.nro_cuenta
                             AND g.fecha > v_fec_movimiento
                             AND g.reversado = 'N') OR
                  EXISTS (SELECT 1
                            FROM cc_movimientos_his g
                           WHERE g.nro_cuenta = t.nro_cuenta
                             AND g.fecha > v_fec_movimiento
                             AND g.reversado = 'N'))
            AND NOT EXISTS (SELECT 1
                   FROM ge_seg_fraude f
                  WHERE f.nro_cuenta = t.nro_cuenta
                    AND v_fec_actual >= f.fec_alta
                    AND v_fec_actual < add_months(f.fec_alta, 12))
          GROUP BY g.cod_moneda, t.nro_cuenta, t.embozado, t.nro_tarjeta, t.fec_vencimiento,
                   p.cod_persona, t.nro_emision
          ORDER BY g.cod_moneda, t.nro_cuenta, t.embozado, t.nro_tarjeta, t.fec_vencimiento,
                   p.cod_persona, t.nro_emision;
      CURSOR c_seguros IS
         SELECT /*COUNT(1) cantidad, SUM(mto_anual)*/ mto_anual, /*SUM(mto_seguro)*/ mto_seguro,
                /*SUM(mto_ganancia)*/ mto_ganancia, /*SUM(mto_impuesto)*/ mto_impuesto,
                cod_moneda, cotizacion, ano, nro_cuenta
           FROM ge_seg_fraude t
          WHERE fec_alta = v_fec_actual
            AND estado = 'A'
          ORDER BY cod_moneda, cotizacion, nro_cuenta;
   BEGIN
      v_hora := to_char(SYSDATE, 'HH24:MI:SS');
      v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
      v_fec_movimiento := to_date('01/'||to_char(add_months(v_fec_actual,-1),'mm/yyyy'),'dd/mm/yyyy');
      --- Genera el Inventario
      v_cod_mon_anterior := null;
      FOR i IN c_altas LOOP
         v_mto_ganancia := 0;
         v_mto_impuesto := 0;
         --v_mto_gan_ml   := 0;
         --v_mto_imp_ml   := 0;
         --pag_cta.pr_obt_cuenta(i.nro_cuenta);
         -- Calcular impuesto
         v_mto_gan_ml := c_mto_debito - c_mto_seguro;
         v_mto_seguro := c_mto_seguro;
         pag_cta.pr_obt_cuenta(i.nro_cuenta);
         IF v_cod_mon_anterior IS NULL OR
            v_cod_mon_anterior <> i.cod_moneda THEN
            /*
            || DYDMR-1899 ITGF - Resumen cuadre total del balance 12/05/2015 - SC 16587
            */
            v_nro_cuenta := fug_obt_parentes(v_cod_ente, 'CTA_SEG_TAR_DEB_' || i.cod_moneda);
            IF v_nro_cuenta IS NULL THEN
               raise_application_error(-20000, 'No se encuentra Cta.Seguro p/moneda' || i.cod_moneda);
            END IF;
            prg_obt_car_impuesto(v_cod_oficina, v_nro_cuenta, v_cod_mon_local,
                                 4, 41, c_cod_tra_alta, v_mto_seguro, v_cod_tra_impuesto, v_cod_tas_impuesto,
                                 v_val_tas_impuesto, v_mto_imp_ml);
            ---
            v_cotizacion       := NULL;
            v_redondeo         := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                      4, 41,
                                                      i.cod_moneda);
            v_cod_mon_anterior := i.cod_moneda;
            v_mto_seg_ml := c_mto_debito - v_mto_imp_ml;
            IF v_cod_mon_local = pag_cta.g_ctas.cod_moneda THEN
               v_mto_ganancia := nvl(v_mto_gan_ml, 0);
               v_mto_seguro   := nvl(v_mto_seg_ml, 0);
               v_mto_impuesto := nvl(v_mto_imp_ml, 0);
               --v_mto_imp_ml   := 0;
            ELSE
               v_cotizacion   := fug_obt_cotizacion(pag_cta.g_ctas.cod_moneda);
               v_mto_ganancia := round((nvl(v_mto_gan_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
               v_mto_seguro   := round((nvl(v_mto_seg_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
               v_mto_impuesto := round((nvl(v_mto_imp_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
            END IF;
         END IF;
         --- DYDMR-1899 ITGF - Resumen cuadre total del balance 12/05/2015 - SC 16587
         --- Obtener si la cuenta paga IVA
         v_mto_seguro := c_mto_seguro;
         prg_obt_car_impuesto(pag_cta.g_ctas.cod_oficina, i.nro_cuenta, v_cod_mon_local,
                              pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                              c_cod_tra_alta, v_mto_seguro, v_cod_tra_impuesto, v_cod_tas_impuesto,
                              v_val_tas_impuesto, v_mto_imp_cta);
         IF nvl(v_mto_imp_cta,0) = 0 THEN
            v_mto_gan_ml := nvl(v_mto_gan_ml, 0) - nvl(v_mto_imp_ml,0);
         END IF;
         ---
         BEGIN
            INSERT INTO ge_seg_fraude
               (ano, nro_cuenta, fec_activacion, cod_moneda, mto_anual, mto_seguro, mto_ganancia,
                mto_acumulado, fec_alta, estado, cotizacion, embozado, nro_tarjeta, fec_vencimiento,
                cod_persona, nro_emision, cod_oficina, mto_impuesto)
            VALUES
               (to_number(to_char(v_fec_actual, 'yyyy')), i.nro_cuenta, i.fec_activacion,
                pag_cta.g_ctas.cod_moneda, c_mto_debito, v_mto_seg_ml, v_mto_gan_ml, 0, v_fec_actual,
                'A', v_cotizacion, i.embozado, i.nro_tarjeta, i.fec_vencimiento, i.cod_persona,
                i.nro_emision, v_cod_oficina, v_mto_imp_cta);
         EXCEPTION
            WHEN dup_val_on_index THEN
               NULL;
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Al Ins.GE_SEG_FRAUDE:' || SQLERRM);
         END;
      END LOOP;
      /*
      || Movimientos por el Alta
      || ALTA DE LA POLIZA por SEGURO CONTRA FRAUDE A COBRAR TD
      || se divide en v_mto_seguro y v_mto_neto
      || debido a que el IVA es solo para la aseguradora
      */
      --v_mto_credito      := 0;
      v_cod_mon_anterior := null;
      v_por_ganancia     := (c_mto_seguro * 100) / c_mto_debito;
      v_nro_secuencia    := 0;
      FOR j IN c_seguros LOOP
         v_mto_gan_ml := j.mto_ganancia;
         v_mto_seg_ml := j.mto_seguro;
         --v_mto_imp_ml := j.mto_anual - j.mto_seguro;
         --v_mto_cre_ml := j.mto_anual - j.mto_ganancia;
         v_mto_cre_ml := j.mto_anual * v_por_ganancia / 100;
         v_cotizacion := j.cotizacion;
         v_mto_seguro := c_mto_seguro;
         --- DYDMR-1899 ITGF - Resumen cuadre total del balance 12/05/2015 - SC 16587
         IF v_cod_mon_anterior IS NULL OR --para 1era vez
            v_cod_mon_anterior <> j.cod_moneda THEN
            v_nro_cuenta := fug_obt_parentes(v_cod_ente, 'CTA_SEG_TAR_DEB_'
                         || nvl(v_cod_mon_anterior, j.cod_moneda));
            IF v_nro_cuenta IS NULL THEN
               raise_application_error(-20000, 'No se encuentra Cta.Seguro p/moneda'
                                               || nvl(v_cod_mon_anterior, j.cod_moneda));
            END IF;
            prg_obt_car_impuesto(v_cod_oficina, v_nro_cuenta, v_cod_mon_local,
                                 4, 41, c_cod_tra_alta, v_mto_seguro, v_cod_tra_impuesto, v_cod_tas_impuesto,
                                 v_val_tas_impuesto, v_mto_imp_ml);
            v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                 4, 41,
                                                 nvl(v_cod_mon_anterior, j.cod_moneda));
            IF nvl(v_cod_mon_anterior, j.cod_moneda) <> j.cod_moneda THEN --Corte por moneda
               --- Acreditar en la cuenta
               IF v_nro_secuencia > 990 THEN
                  --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
                  v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
                  v_nro_secuencia := -999;
               END IF;
               --IF v_cod_mon_local = v_cod_mon_anterior THEN
                  v_mto_acumulado := nvl(v_mto_acu_ml, 0);
                  v_mto_acu_ml    := 0;
               /*ELSE
                  v_mto_acumulado := round((nvl(v_mto_acu_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
               END IF;*/
               /*
               BEGIN
                  v_tasa := fug_obt_val_tasa(4, 41, v_cod_oficina, v_nro_cuenta, j.cod_moneda,
                                             v_mto_imp_ml, 'N', NULL, c_cod_tra_iva, NULL);
               EXCEPTION
                  WHEN OTHERS THEN
                     raise_application_error(-20000, 'Al Obt.Val Tasa:' || c_cod_tra_iva);
               END;*/
               --- DYDMR-2064
               PAG_CTA.PR_SET_VARIABLES(user,
                                        v_fec_actual,
                                        c_cod_tra_padre,
                                        'N',-- estado
                                        'N',-- reversado
                                        v_nro_secuencia,
                                        null,
                                        v_cod_oficina,
                                        4,
                                        41);
               --- DYD-SDSL-2878: Acreditación siempre debe ser en GS.              
               pag_cta.pr_act_operacion(/*v_nro_cuenta*/v_nro_cta_local, v_hora, 'C',
                                        /*v_cod_mon_anterior*/v_cod_mon_local, v_mto_acumulado,
                                        c_cod_tra_padre, 602, nvl(v_cantidad,0), v_cotizacion,
                                        v_cod_oficina, 4, 41, NULL, NULL, 'Alta Deb.Aut.Seg.c/Fraude',
                                        'S', v_nro_secuencia, v_fec_actual, NULL, NULL, v_mto_acu_ml);
               IF pag_cta.g_cod_error <> 0 THEN
                  raise_application_error(-20000,
                                          'Error Act.Operación.Cta.Seguro ' || v_nro_cuenta || '-' ||
                                           pag_cta.g_msj_error);
               END IF;
            END IF;
            v_mto_acu_ml    := 0;
            v_mto_acumulado := 0;
            v_cantidad      := 0;
         END IF;
         -- Si el monto del impuesto es 0, hay que restar de la acreditación
         v_mto_acu_ml := nvl(v_mto_acu_ml, 0) + nvl(v_mto_cre_ml, 0);
         v_cantidad   := nvl(v_cantidad,0) + 1;
         v_mto_net_ml := nvl(v_mto_seg_ml, 0);
         IF nvl(j.mto_impuesto,0) = 0 THEN
            v_mto_net_ml := nvl(v_mto_net_ml, 0) - nvl(v_mto_imp_ml, 0);
         END IF;
         IF v_cod_mon_local = j.cod_moneda THEN
            v_mto_ganancia := nvl(v_mto_gan_ml, 0);
            --v_mto_seguro   := nvl(v_mto_seg_ml, 0);
            v_mto_impuesto := nvl(v_mto_imp_ml, 0);
            --v_mto_credito  := nvl(v_mto_cre_ml, 0);
            v_mto_neto     := nvl(v_mto_net_ml, 0);
            --v_mto_seg_ml   := 0;
            v_mto_gan_ml   := 0;
            --v_mto_imp_ml   := 0;
            v_mto_net_ml   := 0;
         ELSE
            v_redondeo     := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 4, 41, j.cod_moneda);
            v_mto_ganancia := round((nvl(v_mto_gan_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
            --v_mto_seguro   := round((nvl(v_mto_seg_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
            v_mto_impuesto := round((nvl(v_mto_imp_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
            --v_mto_credito  := round((nvl(v_mto_cre_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
            v_mto_neto     := round((nvl(v_mto_net_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
            --
         END IF;
         /*
         || crédito a la aseguradora
         */
         /* -- No hace falta 2 movimientos. No se genera IVA en PAB_IVA
         IF v_mto_seguro <> 0 THEN
            v_nro_secuencia := v_nro_secuencia + 1;
            IF v_nro_secuencia > 990 THEN
               --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
               v_nro_secuencia := -999;
            END IF;
            rg_movs.cod_transaccion := c_cod_tra_alta;
            rg_movs.cod_modulo      := 4;
            rg_movs.cod_modalidad   := 41;
            rg_movs.cod_tra_padre   := c_cod_tra_padre;
            rg_movs.cod_mod_padre   := 4;
            rg_movs.cod_mad_padre   := 41;
            rg_movs.monto           := v_mto_seguro;
            rg_movs.cod_moneda      := j.cod_moneda;
            --
            rg_movs.nro_cuenta     := NULL;
            rg_movs.cod_oficina    := v_cod_oficina;
            rg_movs.cod_usuario    := USER;
            rg_movs.hora           := v_hora;
            rg_movs.fecha          := v_fec_actual;
            rg_movs.nro_secuencia  := v_nro_secuencia;
            rg_movs.fec_valor      := v_fec_actual;
            rg_movs.nro_documento  := j.ano;--j.cantidad;
            rg_movs.cod_tasa       := NULL;
            rg_movs.val_tasa       := NULL;
            rg_movs.cotizacion     := v_cotizacion;
            rg_movs.mto_equ_local  := v_mto_seg_ml;
            rg_movs.emi_aviso      := 'N';
            rg_movs.cod_ofi_origen := v_cod_oficina;
            rg_movs.concepto       := 'Debito Automático Seguro conta Fraude';
            rg_movs.estado         := 'N';
            rg_movs.est_cuenta     := 'N';
            rg_movs.reversado      := 'N';
            rg_movs.emi_aviso      := 'N';
            rg_movs.nro_caja       := NULL;
            rg_movs.cod_rubro      := NULL;
            rg_movs.tip_mov_rubro  := 'D';
            pag_gen.pr_ins_ge_movimiento(rg_movs, v_es_nocturno);
         END IF;*/
         /*
         || Monto Neto: IVA * 10%
         */
         IF v_mto_neto <> 0 THEN
            v_nro_secuencia := v_nro_secuencia + 1;
            IF v_nro_secuencia > 990 THEN
               --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
               v_nro_secuencia := -999;
            END IF;
            rg_movs.cod_transaccion := c_cod_tra_alta;
            rg_movs.cod_modulo      := 4;
            rg_movs.cod_modalidad   := 41;
            rg_movs.cod_tra_padre   := c_cod_tra_padre;
            rg_movs.cod_mod_padre   := 4;
            rg_movs.cod_mad_padre   := 41;
            rg_movs.monto           := v_mto_neto;
            rg_movs.cod_moneda      := j.cod_moneda;
            --
            rg_movs.nro_cuenta     := NULL;
            rg_movs.cod_oficina    := v_cod_oficina;
            rg_movs.cod_usuario    := USER;
            rg_movs.hora           := v_hora;
            rg_movs.fecha          := v_fec_actual;
            rg_movs.nro_secuencia  := v_nro_secuencia;
            rg_movs.fec_valor      := v_fec_actual;
            rg_movs.nro_documento  := j.ano;--j.cantidad;
            rg_movs.cod_tasa       := NULL;
            rg_movs.val_tasa       := v_val_tas_impuesto;
            rg_movs.cotizacion     := v_cotizacion;
            rg_movs.mto_equ_local  := v_mto_net_ml;
            rg_movs.emi_aviso      := 'N';
            rg_movs.cod_ofi_origen := v_cod_oficina;
            rg_movs.concepto       := 'Alta Deb.Aut.Seg.c/Fraude';
            rg_movs.estado         := 'N';
            rg_movs.est_cuenta     := 'N';
            rg_movs.reversado      := 'N';
            rg_movs.emi_aviso      := 'N';
            rg_movs.nro_caja       := NULL;
            rg_movs.cod_rubro      := NULL;
            rg_movs.tip_mov_rubro  := 'D';
            rg_movs.referencia     := j.nro_cuenta;
            pag_gen.pr_ins_ge_movimiento(rg_movs, v_es_nocturno);
         END IF;
         /*
         || IVA
         */
         IF v_mto_impuesto <> 0 THEN
            v_nro_secuencia := v_nro_secuencia + 1;
            IF v_nro_secuencia > 990 THEN
               --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
               v_nro_secuencia := -999;
            END IF;
            rg_movs.cod_transaccion := c_cod_tra_iva;
            rg_movs.cod_modulo      := 4;
            rg_movs.cod_modalidad   := 41;
            rg_movs.cod_tra_padre   := c_cod_tra_padre;
            rg_movs.cod_mod_padre   := 4;
            rg_movs.cod_mad_padre   := 41;
            rg_movs.monto           := v_mto_impuesto;
            rg_movs.cod_moneda      := j.cod_moneda;
            --
            rg_movs.nro_cuenta     := NULL;
            rg_movs.cod_oficina    := v_cod_oficina;
            rg_movs.cod_usuario    := USER;
            rg_movs.hora           := v_hora;
            rg_movs.fecha          := v_fec_actual;
            rg_movs.nro_secuencia  := v_nro_secuencia;
            rg_movs.fec_valor      := v_fec_actual;
            rg_movs.nro_documento  := j.ano;--j.cantidad;
            rg_movs.cod_tasa       := v_cod_tas_impuesto;
            rg_movs.val_tasa       := v_val_tas_impuesto;
            rg_movs.cotizacion     := v_cotizacion;
            rg_movs.mto_equ_local  := v_mto_imp_ml;
            rg_movs.emi_aviso      := 'N';
            rg_movs.cod_ofi_origen := v_cod_oficina;
            rg_movs.concepto       := 'Alta Deb.Aut.Seg.c/Fraude';
            rg_movs.estado         := 'N';
            rg_movs.est_cuenta     := 'N';
            rg_movs.reversado      := 'N';
            rg_movs.emi_aviso      := 'N';
            rg_movs.nro_caja       := NULL;
            rg_movs.cod_rubro      := NULL;
            rg_movs.tip_mov_rubro  := 'D';
            rg_movs.referencia     := j.nro_cuenta;
            pag_gen.pr_ins_ge_movimiento(rg_movs, v_es_nocturno);
         END IF;
         /*
         || crédito por la ganancia
         */
         IF v_mto_ganancia <> 0 THEN
            v_nro_secuencia := v_nro_secuencia + 1;
            IF v_nro_secuencia > 990 THEN
               --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
               v_nro_secuencia := -999;
            END IF;
            rg_movs.cod_transaccion := c_cod_tra_ganancia;
            rg_movs.cod_modulo      := 4;
            rg_movs.cod_modalidad   := 41;
            rg_movs.cod_tra_padre   := c_cod_tra_padre;
            rg_movs.cod_mod_padre   := 4;
            rg_movs.cod_mad_padre   := 41;
            rg_movs.monto           := v_mto_ganancia;
            rg_movs.cod_moneda      := j.cod_moneda;
            --
            rg_movs.nro_cuenta     := NULL;
            rg_movs.cod_oficina    := v_cod_oficina;
            rg_movs.cod_usuario    := USER;
            rg_movs.hora           := v_hora;
            rg_movs.fecha          := v_fec_actual;
            rg_movs.nro_secuencia  := v_nro_secuencia;
            rg_movs.fec_valor      := v_fec_actual;
            rg_movs.nro_documento  := j.ano;--j.cantidad;
            rg_movs.cod_tasa       := NULL;
            rg_movs.val_tasa       := NULL;
            rg_movs.cotizacion     := v_cotizacion;
            rg_movs.mto_equ_local  := v_mto_gan_ml;
            rg_movs.emi_aviso      := 'N';
            rg_movs.cod_ofi_origen := v_cod_oficina;
            rg_movs.concepto       := 'Alta Deb.Aut.Seg.c/Fraude';
            rg_movs.estado         := 'N';
            rg_movs.est_cuenta     := 'N';
            rg_movs.reversado      := 'N';
            rg_movs.emi_aviso      := 'N';
            rg_movs.nro_caja       := NULL;
            rg_movs.cod_rubro      := NULL;
            rg_movs.tip_mov_rubro  := 'C';
            rg_movs.referencia     := j.nro_cuenta;
            pag_gen.pr_ins_ge_movimiento(rg_movs, v_es_nocturno);
         END IF;
         v_cod_mon_anterior := j.cod_moneda;
      END LOOP;
      IF v_nro_secuencia > 990 THEN
         --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
         v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
         v_nro_secuencia := -999;
      END IF;
      v_nro_cuenta := fug_obt_parentes(v_cod_ente, 'CTA_SEG_TAR_DEB_' || v_cod_mon_anterior);
      IF v_nro_cuenta IS NULL THEN
         raise_application_error(-20000, 'No se encuentra Cta.Seguro p/moneda' || v_cod_mon_anterior);
      END IF;
      --IF v_cod_mon_local = v_cod_mon_anterior THEN
         v_mto_acumulado := nvl(v_mto_acu_ml, 0);
         v_mto_acu_ml    := 0;
      /*ELSE
         v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                              4,
                                              41,
                                              v_cod_mon_anterior);
         v_mto_acumulado  := round((nvl(v_mto_acu_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
      END IF;*/
      --- DYDMR-2064
      PAG_CTA.PR_SET_VARIABLES(user,
                               v_fec_actual,
                               c_cod_tra_padre,
                               'N',-- estado
                               'N',-- reversado
                               v_nro_secuencia,
                               null,
                               v_cod_oficina,
                               4,
                               41);
      --- DYD-SDSL-2878: Acreditación siempre debe ser en GS.
      pag_cta.pr_act_operacion(/*v_nro_cuenta*/v_nro_cta_local, v_hora, 'C',
                               /*v_cod_mon_anterior*/v_cod_mon_local, v_mto_acumulado,
                               c_cod_tra_padre, 602, v_cantidad, v_cotizacion, v_cod_oficina, 4,
                               41, NULL, NULL, 'Alta Deb.Aut.Seg.c/Fraude', 'S',
                               v_nro_secuencia, v_fec_actual, NULL, NULL, v_mto_acu_ml);
      IF pag_cta.g_cod_error <> 0 THEN
         raise_application_error(-20000,
                                 'Error Act.Operación.Cta.Seguro ' || v_nro_cuenta || '-' ||
                                  pag_cta.g_msj_error);
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'PR_INS_SEG_FRA:' || SQLERRM);
   END pr_ins_seg_fra;

   PROCEDURE pr_deb_seg_fra(p_nro_cta_debito ge_cuentas.nro_cuenta%TYPE DEFAULT NULL,
                            p_mes_cuota      ge_seg_fraude_det.mes%TYPE DEFAULT NULL,
                            p_hora           IN OUT ge_movimientos.hora%TYPE,
                            p_nro_secuencia  IN OUT ge_movimientos.nro_secuencia%TYPE,
                            p_tip_proceso    varchar2 DEFAULT 'C') IS
      v_tip_proceso        VARCHAR2(1);
      --- DYD-SDSL-2878
      v_fec_implementacion ge_movimientos.fecha%TYPE; /*:= fug_obt_parentes(v_cod_ente,
                                                              'FEC_IMP_SEG_TAR_DEB');*/
      --v_mes_implementacion NUMBER(6); /*:= to_number(to_char(v_fec_implementacion, 'yyyymm'));*/
      --v_mes_activacion     NUMBER(6);
      --v_fec_pri_dia_habil  ge_calendarios.pri_dia_mes_habil%TYPE;
      v_procesa            VARCHAR2(1);
      v_est_modulo         ba_modulos.estado%TYPE;
      v_horario            VARCHAR2(1) := 'D';
      v_debita             VARCHAR2(1);
      v_cobrado            VARCHAR2(1);
      v_nvo_estado         ah_cta_vistas.estado%TYPE;
      v_sal_disponible     NUMBER;
      v_nro_cuota          ge_seg_fraude_det.nro_cuota%TYPE;
      v_por_ganancia       NUMBER(16, 4);
      v_gan_aux_ml         ge_movimientos.monto%TYPE;
      v_imp_aux_ml         ge_movimientos.monto%TYPE;
      v_iva_costo          ge_movimientos.monto%TYPE;
      v_imp_exo_ml         ge_movimientos.monto%TYPE;
      v_mto_neto           ge_movimientos.monto%TYPE;
      v_mto_net_ml         ge_movimientos.monto%TYPE;
      v_val_tasa           NUMBER;
      c_mto_cuota          ge_seg_fraude.mto_anual%TYPE;
      v_nro_proceso        ge_seg_fraude_det.nro_proceso%TYPE;
      v_cod_mon_anterior   ba_monedas.cod_moneda%TYPE;
      v_nro_cuenta         ge_cuentas.nro_cuenta%TYPE;
      v_error              ge_seg_fraude_det.error%TYPE;
      v_mes_cuota          ge_seg_fraude_det.mes%TYPE;
      CURSOR c_tar_debitos IS
         SELECT t.ano, t.nro_cuenta, t.fec_activacion, t.mto_anual, t.mto_seguro, t.mto_ganancia,
                t.cod_moneda
           FROM ge_seg_fraude t
          WHERE (t.nro_cuenta = p_nro_cta_debito OR p_nro_cta_debito IS NULL)
            AND t.estado = 'A'
          ORDER BY t.cod_moneda, t.nro_cuenta;
      CURSOR c_cobros IS
         SELECT b.nro_cuenta, b.mto_debito, b.mto_ganancia, b.iva_pago, b.iva_costo, a.cod_moneda,
                b.cotizacion, b.nro_cuota, b.ano, b.mes
           FROM ge_seg_fraude a, ge_seg_fraude_det b
          WHERE a.ano = b.ano
            AND a.nro_cuenta = b.nro_cuenta
            AND b.cobrado = 'S'
            AND b.nro_proceso = v_nro_proceso
          ORDER BY a.cod_moneda, b.nro_cuenta;
   BEGIN
      --- DYD-SDSL-2878
      v_fec_implementacion := to_date(fug_obt_parentes(v_cod_ente,'FEC_IMP_SEG_TAR_DEB'),'dd/mm/yyyy');
      --v_mes_implementacion := to_number(to_char(v_fec_implementacion, 'yyyymm'));
      --- DYDMR-2117
      IF nvl(p_nro_secuencia, 0) = 0 THEN
         v_nro_secuencia := 0;
      ELSE
         v_nro_secuencia := p_nro_secuencia;
      END IF;
      ---
      IF p_hora IS NULL THEN
         v_hora := to_char(SYSDATE, 'HH24:MI:SS');
         v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
         --v_fec_pri_dia_habil := pag_cal.fu_obt_fec_pri_dia_mes_habil(4);
      ELSE
         v_hora := p_hora;
      END IF;
      ---
      IF v_cod_oficina is null THEN
         v_cod_oficina := fug_obt_ofi_matriz;
      END IF;
      ---      
      IF nvl(pae_cnf.g_programa, 'X') = 'GPPAGSUE' or nvl(p_tip_proceso,'C') = 'N' THEN
         v_tip_proceso := 'N'; -- Nomina
      ELSE
         v_tip_proceso := 'C'; -- Cliente no nomina
      END IF;
      v_est_modulo  := pae_cnf.fu_obt_est_modulo(4);
      IF v_est_modulo = 2 THEN
         v_horario     := 'D'; -- N=Cerrado, D=Abierto
         v_es_nocturno := 'N'; -- N=Abierto,  S=Cerrado
      ELSE
         v_horario     := 'N'; -- N=Cerrado, D=Abierto
         v_es_nocturno := 'S'; -- N=Abierto,  S=Cerrado
      END IF;
      pag_cta.g_horario := v_horario;
      ---
      BEGIN
         SELECT MAX(nvl(nro_proceso, 0)) + 1
           INTO v_nro_proceso
           FROM ge_seg_fraude_det;
      EXCEPTION
         WHEN no_data_found THEN
            v_nro_proceso := 1;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Al Consultar Nro.Proceso:' || SQLERRM);
      END;
      IF v_nro_proceso IS NULL THEN
         v_nro_proceso := 1;
      END IF;
      ---
      v_por_ganancia := (c_mto_seguro * 100) / c_mto_debito;
      FOR i IN c_tar_debitos LOOP
         v_procesa      := 'N';
         v_mto_ganancia := 0;
         v_mto_impuesto := 0;
         v_mto_gan_ml   := 0;
         v_mto_seg_ml   := 0;
         v_mto_imp_ml   := 0;
         v_gan_aux_ml   := 0;
         v_imp_aux_ml   := 0;
         v_iva_costo    := 0;
         v_imp_exo_ml   := 0;
         v_val_tasa     := 0;
         v_error        := null;
         c_mto_cuota    := i.mto_anual / 12;
         pag_cta.pr_obt_cuenta(i.nro_cuenta);
         /*
         || Verifica si ya se cobro la comisión en el mes
         */
         v_cobrado := 'N';
         v_debita  := 'N';
         --- DYDMR-2117
         IF p_mes_cuota IS NOT NULL AND p_nro_cta_debito IS NOT NULL THEN
            v_mes_cuota := p_mes_cuota;
         ELSE
            v_mes_cuota := to_number(to_char(v_fec_actual, 'mm'));
         END IF;
         ---
         BEGIN
            SELECT 'S'
              INTO v_cobrado
              FROM ge_seg_fraude_det
             WHERE ano = i.ano
               AND nro_cuenta = i.nro_cuenta
               AND mes = v_mes_cuota;
         EXCEPTION
            WHEN no_data_found THEN
               v_cobrado := 'N';
            WHEN too_many_rows THEN
               v_cobrado := 'S';
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Al Obt.Cobros Anteriores:' || SQLERRM);
         END;
         IF v_cobrado = 'N' THEN
            IF v_tip_proceso = 'C' /*OR p_nro_cta_debito IS NOT NULL*/ THEN
               -- Solo si No es Nomina
               IF i.fec_activacion > v_fec_implementacion OR
                  --- DYDMR-2117
                  v_fec_actual >= add_months(i.fec_activacion,12) THEN
                  v_debita := 'S';
               END IF;
            ELSE
               -- Es Nomina y se cobra siempre
               /*IF v_fec_actual = v_fec_pri_dia_habil AND
                  (pag_cta.g_ctas.cod_ente IS NULL OR p_nro_cta_debito IS NOT NULL) THEN*/
                  v_debita := 'S';
               --END IF;
            END IF;
         END IF;
         --- DYDMR-2117
         IF v_debita = 'S' THEN
            -- Calcular impuesto
            IF v_cod_mon_anterior IS NULL OR
               v_cod_mon_anterior <> i.cod_moneda THEN
               IF v_cod_mon_local = pag_cta.g_ctas.cod_moneda THEN
                  v_cotizacion := NULL;
               ELSE
                  v_cotizacion := fug_obt_cotizacion(pag_cta.g_ctas.cod_moneda);
               END IF;
               v_redondeo         := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                         pag_cta.g_ctas.cod_modulo,
                                                         pag_cta.g_ctas.cod_modalidad,
                                                         pag_cta.g_ctas.cod_moneda);
               v_cod_mon_anterior := i.cod_moneda;
               v_nro_cuenta       := fug_obt_parentes(v_cod_ente, 'CTA_SEG_TAR_DEB_' || i.cod_moneda);
               IF v_nro_cuenta IS NULL THEN
                  raise_application_error(-20000,
                                          'No se encuentra Cta.Seguro p/moneda' || i.cod_moneda);
               END IF;
            END IF;
            v_mto_gan_ml := c_mto_cuota;
            prg_obt_car_impuesto(pag_cta.g_ctas.cod_oficina, v_nro_cuenta, v_cod_mon_local,
                                 pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                                 c_cod_tra_seguro, v_mto_gan_ml, v_cod_tra_impuesto,
                                 v_cod_tas_ganancia, v_val_tas_ganancia, v_mto_imp_ml);
            -- Calcular impuesto
            v_gan_aux_ml := (c_mto_cuota * v_por_ganancia) / 100;
            prg_obt_car_impuesto(pag_cta.g_ctas.cod_oficina, v_nro_cuenta, v_cod_mon_local,
                                 pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                                 c_cod_tra_seguro, v_gan_aux_ml, v_cod_tra_impuesto,
                                 v_cod_tas_ganancia, v_val_tas_ganancia, v_imp_aux_ml);
            v_mto_gan_ml := c_mto_cuota - v_imp_aux_ml;
            IF v_cod_mon_local = pag_cta.g_ctas.cod_moneda THEN
               v_mto_ganancia := nvl(v_mto_gan_ml, 0);
               v_iva_costo    := nvl(v_imp_aux_ml, 0);
            ELSE
               v_mto_ganancia := round((nvl(v_mto_gan_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
               v_iva_costo    := round((nvl(v_imp_aux_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
            END IF;
            --- Verifica si tiene exonerado el IVA
            v_mto_deb_ml := nvl(v_mto_gan_ml, 0);
            prg_obt_car_impuesto(pag_cta.g_ctas.cod_oficina, i.nro_cuenta, v_cod_mon_local,
                                 pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                                 c_cod_tra_seguro, v_mto_deb_ml, v_cod_tra_impuesto,
                                 v_cod_tas_ganancia, v_val_tas_ganancia, v_imp_exo_ml);
            IF v_imp_exo_ml = 0 THEN
               v_mto_deb_ml := nvl(v_mto_gan_ml, 0) - nvl(v_imp_aux_ml,0);
               v_mto_debito := nvl(v_mto_ganancia, 0) - nvl(v_iva_costo,0);
               v_mto_imp_ml := 0;
               v_imp_aux_ml := 0;
               v_iva_costo  := 0;
            ELSE
               v_mto_deb_ml := nvl(v_mto_gan_ml, 0) + nvl(v_imp_aux_ml, 0);
               v_mto_debito := nvl(v_mto_ganancia, 0) + nvl(v_iva_costo, 0);
            END IF;
            /*
            || debito a la cuenta
            */
            BEGIN
               SELECT MAX(nvl(nro_cuota, 0)) + 1
                 INTO v_nro_cuota
                 FROM ge_seg_fraude_det
                WHERE ano = i.ano
                  AND nro_cuenta = i.nro_cuenta;
            EXCEPTION
               WHEN no_data_found THEN
                  v_nro_cuota := 1;
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Al Consultar Cuota:' || SQLERRM);
            END;
            IF v_nro_cuota IS NULL THEN
               v_nro_cuota := 1;
            END IF;
            IF MOD(v_nro_cuota, 12) = 0 THEN
               v_nro_cuota := 12;
               UPDATE ge_seg_fraude
                  SET estado = 'P'
                WHERE nro_cuenta = i.nro_cuenta
                  AND ano = i.ano
                  AND estado = 'A';
            ELSE
               v_nro_cuota := v_nro_cuota - (floor(v_nro_cuota / 12) * 12);
            END IF;
            IF nvl(v_mto_debito, 0) <> 0 THEN
               pag_cta.pr_ver_operacion(i.nro_cuenta, 503, 4, 41, 'D', pag_cta.g_ctas.cod_moneda,
                                        v_mto_debito, v_cod_oficina,
                                        /*variables out*/ pag_cta.g_ctas.cod_modulo,
                                        pag_cta.g_ctas.cod_modalidad, v_nvo_estado, v_sal_disponible,
                                        v_procesa);
               IF pag_cta.g_cod_error <> 0 or v_procesa = 'N' THEN --MDPSETADE-74
                  --IF pag_cta.g_cod_error IN (25, 29, 31, 36) THEN
                     -- No dispone de saldo suficiente
                     BEGIN
                        INSERT INTO ge_mov_pendientes
                           (cod_usuario, hora, cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
                            cod_moneda, cod_tra_padre, cod_transaccion, fecha, monto, estado,
                            cod_ofi_origen, cod_tasa, val_tasa, cod_mod_padre, cod_mad_padre,
                            nro_documento, concepto, saldo, car_manual)
                        VALUES
                           (USER, v_hora, pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                            pag_cta.g_ctas.cod_oficina, i.nro_cuenta, pag_cta.g_ctas.cod_moneda,
                            c_cod_tra_padre, c_cod_tra_seguro, v_fec_actual, v_mto_debito, 'I',
                            v_cod_oficina, NULL
                            /*665*/, 0, 4, 41, v_nro_cuota,
                            'Deb.Auto.Seg.c/Fraude: mes '||v_mes_cuota||'/'||i.ano,
                            v_mto_debito, 'S');
                     EXCEPTION
                        WHEN OTHERS THEN
                           raise_application_error(-20000,
                                                   'Error: Cta.' || i.nro_cuenta || '-' || SQLERRM);
                     END;
                  --END IF;
                  v_error   := substr(pag_cta.g_cod_error || '-' || pag_cta.g_msj_error,1,4000);
                  v_procesa := 'N';
               END IF;
            ELSE
               v_error   := 'Monto Debito es Cero';
               v_procesa := 'N';
            END IF;
            ---
            BEGIN
               INSERT INTO ge_seg_fraude_det
                  (nro_proceso, ano, nro_cuenta, nro_cuota, mes, cobrado, contabilizado, mto_debito,
                   mto_ganancia, iva_pago, iva_costo, cotizacion, error)
               VALUES
                  (v_nro_proceso, i.ano, i.nro_cuenta, v_nro_cuota,
                   /*to_number(to_char(v_fec_actual, 'mm'))*/ v_mes_cuota,--- DYDMR-2117
                   v_procesa, 'N', v_mto_deb_ml,
                   v_mto_gan_ml, v_mto_imp_ml, v_imp_aux_ml, v_cotizacion, v_error);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Al Ins.GE_SEG_FRAUDE_DET:' || SQLERRM);
            END;
         END IF;
      END LOOP;
      ---
      FOR j IN c_cobros LOOP
         v_mto_deb_ml := j.mto_debito;
         v_mto_imp_ml := j.iva_pago;
         v_cotizacion := j.cotizacion;
         v_nro_cuenta := fug_obt_parentes(v_cod_ente, 'CTA_SEG_TAR_DEB_' || j.cod_moneda);
         IF v_nro_cuenta IS NULL THEN
            raise_application_error(-20000, 'No se encuentra Cta.Seguro p/moneda' || j.cod_moneda);
         END IF;
         prg_obt_car_impuesto(v_cod_oficina, j.nro_cuenta, v_cod_mon_local, 4, 41, c_cod_tra_padre,
                              j.mto_debito, v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto,
                              j.iva_pago);
         v_mto_net_ml := v_mto_deb_ml - v_mto_imp_ml;
         IF v_cod_mon_local = j.cod_moneda THEN
            v_mto_impuesto := nvl(v_mto_imp_ml, 0);
            v_mto_neto     := nvl(v_mto_net_ml, 0);
            v_mto_debito   := nvl(v_mto_deb_ml, 0);
            v_mto_imp_ml   := 0;
            v_mto_net_ml   := 0;
            v_mto_deb_ml   := 0;
         ELSE
            v_redondeo     := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 4, 41, j.cod_moneda);
            v_mto_impuesto := round((nvl(v_mto_imp_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
            v_mto_neto     := round((nvl(v_mto_net_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
            v_mto_debito   := round((nvl(v_mto_deb_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
         END IF;
         --- DEBITAR de la cuenta
         IF v_nro_secuencia >= 990 THEN
            --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
            v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
            v_nro_secuencia := -999;
         END IF;
         pag_cta.pr_obt_cuenta(j.nro_cuenta);
         --- DYDMR-2064
         PAG_CTA.PR_SET_VARIABLES(user,
                                  v_fec_actual,
                                  c_cod_tra_padre,
                                  'N',-- estado
                                  'N',-- reversado
                                  v_nro_secuencia,
                                  null,
                                  v_cod_oficina,
                                  4,
                                  41);
         ---
         pag_cta.pr_act_operacion(j.nro_cuenta, v_hora, 'D', j.cod_moneda,
                                  round(v_mto_debito, v_redondeo), c_cod_tra_padre, 503, j.nro_cuota,
                                  v_cotizacion, v_cod_oficina, 4, 41, NULL, NULL,
                                  'Deb.Auto.Seg.c/Fraude: mes '||j.mes||'/'||j.ano,
                                  'S', v_nro_secuencia,
                                  v_fec_actual, NULL, NULL, v_mto_deb_ml);
         IF pag_cta.g_cod_error <> 0 THEN
            IF pag_cta.g_cod_error IN (25, 29, 31, 36) THEN
               -- No dispone de saldo suficiente
               BEGIN
                  INSERT INTO ge_mov_pendientes
                     (cod_usuario, hora, cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
                      cod_moneda, cod_tra_padre, cod_transaccion, fecha, monto, estado,
                      cod_ofi_origen, cod_tasa, val_tasa, cod_mod_padre, cod_mad_padre,
                      nro_documento, concepto, saldo, car_manual)
                  VALUES
                     (USER, v_hora, pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                      pag_cta.g_ctas.cod_oficina, j.nro_cuenta, pag_cta.g_ctas.cod_moneda,
                      c_cod_tra_padre, c_cod_tra_seguro, v_fec_actual, v_mto_debito, 'I',
                      v_cod_oficina, NULL
                      /*665*/, 0, 4, 41, v_nro_cuota,
                      'Deb.Auto.Seg.c/Fraude: mes '||j.mes||'/'||j.ano,
                      v_mto_debito, 'S');
               EXCEPTION
                  WHEN OTHERS THEN
                     v_error := substr(SQLERRM,1,4000);
               END;
            ELSE
               v_error := substr(pag_cta.g_cod_error || '-' || pag_cta.g_msj_error,1,4000);
            END IF;
            ---
            UPDATE ge_seg_fraude_det
               SET cobrado = 'N',
                   error   = v_error
             WHERE nro_cuenta = j.nro_cuenta
               AND ano = j.ano
               AND nro_cuota = j.nro_cuota;
         ELSE
            /*
            || crédito al seguro porción gravada
            */
            IF v_mto_neto <> 0 THEN
               --- DYD-SDSL-2878: Tiene que seguir la secuencia del debito
               /*IF v_nro_secuencia > 990 THEN
                  --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
                  v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
                  v_nro_secuencia := -999;
               END IF;*/
               v_nro_secuencia         := v_nro_secuencia + 1;
               rg_movs.cod_transaccion := c_cod_tra_seguro;
               rg_movs.cod_modulo      := pag_cta.G_CTAS.cod_modulo;--4;
               rg_movs.cod_modalidad   := pag_cta.G_CTAS.cod_modalidad;--41;
               rg_movs.cod_tra_padre   := c_cod_tra_padre;
               rg_movs.cod_mod_padre   := 4;
               rg_movs.cod_mad_padre   := 41;
               rg_movs.monto           := v_mto_neto;
               rg_movs.cod_moneda      := j.cod_moneda;
               --
               rg_movs.nro_cuenta     := NULL;
               rg_movs.cod_oficina    := v_cod_oficina;
               rg_movs.cod_usuario    := USER;
               rg_movs.hora           := v_hora;
               rg_movs.fecha          := v_fec_actual;
               rg_movs.nro_secuencia  := v_nro_secuencia;
               rg_movs.fec_valor      := v_fec_actual;
               rg_movs.nro_documento  := j.nro_cuota;
               rg_movs.cod_tasa       := v_cod_tas_impuesto;
               rg_movs.val_tasa       := v_val_tas_impuesto;
               rg_movs.cotizacion     := v_cotizacion;
               rg_movs.mto_equ_local  := v_mto_net_ml;
               rg_movs.emi_aviso      := 'N';
               rg_movs.cod_ofi_origen := v_cod_oficina;
               rg_movs.concepto       := 'Deb.Auto.Seg.c/Fraude: mes '||j.mes||'/'||j.ano;
               rg_movs.estado         := 'N';
               rg_movs.est_cuenta     := 'N';
               rg_movs.reversado      := 'N';
               rg_movs.emi_aviso      := 'N';
               rg_movs.nro_caja       := NULL;
               rg_movs.cod_rubro      := NULL;
               rg_movs.tip_mov_rubro  := 'C';
               rg_movs.referencia     := j.nro_cuenta;
               pag_gen.pr_ins_ge_movimiento(rg_movs, v_es_nocturno);
            END IF;
            /*
            || IVA
            */
            IF v_mto_impuesto <> 0 THEN
               --- DYD-SDSL-2878: Tiene que seguir la secuencia del debito
               /*IF v_nro_secuencia > 990 THEN
                  --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
                  v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
                  v_nro_secuencia := -999;
               END IF;*/
               v_nro_secuencia         := v_nro_secuencia + 1;
               rg_movs.cod_transaccion := v_cod_tra_impuesto;
               rg_movs.cod_modulo      := pag_cta.G_CTAS.cod_modulo;--4;
               rg_movs.cod_modalidad   := pag_cta.G_CTAS.cod_modalidad;--41;
               rg_movs.cod_tra_padre   := c_cod_tra_padre;
               rg_movs.cod_mod_padre   := 4;
               rg_movs.cod_mad_padre   := 41;
               rg_movs.monto           := v_mto_impuesto;
               rg_movs.cod_moneda      := j.cod_moneda;
               --
               rg_movs.nro_cuenta     := NULL;
               rg_movs.cod_oficina    := v_cod_oficina;
               rg_movs.cod_usuario    := USER;
               rg_movs.hora           := v_hora;
               rg_movs.fecha          := v_fec_actual;
               rg_movs.nro_secuencia  := v_nro_secuencia;
               rg_movs.fec_valor      := v_fec_actual;
               rg_movs.nro_documento  := j.nro_cuota;
               rg_movs.cod_tasa       := v_cod_tas_impuesto;
               rg_movs.val_tasa       := v_val_tas_impuesto;
               rg_movs.cotizacion     := v_cotizacion;
               rg_movs.mto_equ_local  := v_mto_imp_ml;
               rg_movs.emi_aviso      := 'N';
               rg_movs.cod_ofi_origen := v_cod_oficina;
               rg_movs.concepto       := 'Deb.Auto.Seg.c/Fraude: mes '||j.mes||'/'||j.ano;
               rg_movs.estado         := 'N';
               rg_movs.est_cuenta     := 'N';
               rg_movs.reversado      := 'N';
               rg_movs.emi_aviso      := 'N';
               rg_movs.nro_caja       := NULL;
               rg_movs.cod_rubro      := NULL;
               rg_movs.tip_mov_rubro  := 'C';
               rg_movs.referencia     := j.nro_cuenta;
               pag_gen.pr_ins_ge_movimiento(rg_movs, v_es_nocturno);
            END IF;
         END IF;
         --pr_gen_ganancia(j.nro_cuenta, v_hora, v_nro_secuencia, v_es_nocturno);
      END LOOP;
      --pr_gen_ganancia; -- Se lleva dentro del cursor
      --- DYDMR-2117
      p_nro_secuencia := v_nro_secuencia;
      p_hora          := v_hora;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'PR_DEB_SEG_FRA:' || SQLERRM);
   END pr_deb_seg_fra;

   PROCEDURE pr_gen_ganancia(p_nro_cta_debito IN ge_cuentas.nro_cuenta%TYPE DEFAULT NULL,
                             p_hora           IN OUT ge_movimientos.hora%TYPE,
                             p_nro_secuencia  IN OUT ge_movimientos.nro_secuencia%TYPE,
                             p_es_nocturno    IN VARCHAR2 DEFAULT 'N') IS
      v_por_ganancia  NUMBER(16, 4);
      v_imp_ano_ml    ge_movimientos.monto%TYPE;
      v_iva_costo     ge_movimientos.monto%TYPE;
      v_nro_cuenta    ge_cuentas.nro_cuenta%TYPE;
      v_val_tasa      NUMBER;
      v_mto_acumulado ge_movimientos.monto%TYPE;
      v_cod_ente      ge_entes.cod_ente%TYPE := fu_obt_ente;
      CURSOR c_ganancia IS
         SELECT /*COUNT(*/b.nro_cuenta/*) cantidad*/, round(/*SUM*/(a.mto_ganancia) / 12,0) mto_gan_anual,
                /*SUM(*/b.iva_costo/*)*/ iva_costo, a.cod_moneda, b.cotizacion, b.ano, b.mes, b.mto_debito,
                b.nro_cuota
           FROM ge_seg_fraude a, ge_seg_fraude_det b
          WHERE a.nro_cuenta = b.nro_cuenta
            AND a.ano = b.ano
            AND b.cobrado = 'S'
            AND b.contabilizado = 'N'
            AND p_nro_cta_debito is null
          UNION
         SELECT b.nro_cuenta, round((a.mto_ganancia) / 12,0),
                b.iva_costo, a.cod_moneda, b.cotizacion, b.ano, b.mes, b.mto_debito,
                b.nro_cuota
           FROM ge_seg_fraude a, ge_seg_fraude_det b
          WHERE a.nro_cuenta = b.nro_cuenta
            AND a.ano = b.ano
            AND b.cobrado = 'S'
            AND b.contabilizado = 'N'
            AND b.nro_cuenta = p_nro_cta_debito
          ORDER BY cod_moneda, cotizacion;
   BEGIN
      /*v_hora := to_char(SYSDATE, 'HH24:MI:SS');
      v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');*/
      /*
      || Actualiza los movimientos pendientes cobrados
      || Proceso 11 orden 90
      */
      BEGIN
         UPDATE ge_seg_fraude_det t
            SET cobrado = 'S'
         /*
         || DYD-SDSL-2878
         || verifica desde la ultima fecha de cobro,
         || por si no se ejecuto en el cierre
         *//*
          WHERE EXISTS (SELECT 1
                   FROM ge_movimientos a
                  WHERE a.nro_cuenta = t.nro_cuenta
                    AND a.nro_documento = t.nro_cuota
                    AND a.cod_tra_padre = c_cod_tra_padre
                    AND a.cod_transaccion = 503)*/
          WHERE EXISTS (SELECT 1
                  FROM ge_mov_pendientes g
                 WHERE g.nro_cuenta = t.nro_cuenta
                   AND g.nro_documento = t.nro_cuota
                   AND g.cod_tra_padre = c_cod_tra_padre
                   AND g.estado <> 'I'
                   AND g.saldo = 0
                   AND g.fecha = trunc(t.fec_insercion))
            AND t.cobrado = 'N'
            AND t.contabilizado = 'N'
            AND t.nro_cuenta = nvl(p_nro_cta_debito, t.nro_cuenta);
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000,
                                    'Error: Act.Cta.Detalle:'||p_nro_cta_debito||'-'|| SQLERRM);
      END;
      ---
      v_por_ganancia := (c_mto_seguro * 100) / c_mto_debito;
      v_es_nocturno  := nvl(p_es_nocturno, 'N');
      IF p_nro_cta_debito IS NULL THEN
         -- Viene del proceso de cierre
         v_hora := to_char(SYSDATE, 'HH24:MI:SS');
         v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
         ---
         v_nro_secuencia := 0;
      ELSE
         IF p_hora IS NULL THEN
            p_hora := to_char(SYSDATE, 'HH24:MI:SS');
            p_hora := fug_obt_hor_disponible(v_fec_actual, p_hora, USER, 'N');
         END IF;            
         v_hora          := p_hora;
         v_nro_secuencia := nvl(p_nro_secuencia, 0);
      END IF;
      FOR i IN c_ganancia LOOP
          v_cotizacion := NULL;
         -- Calcular impuesto
         v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 4, 41, i.cod_moneda);
         v_nro_cuenta := fug_obt_parentes(v_cod_ente, 'CTA_SEG_TAR_DEB_' || i.cod_moneda);
         IF v_nro_cuenta IS NULL THEN
            raise_application_error(-20000, 'No se encuentra Cta.Seguro p/moneda' || i.cod_moneda);
         END IF;
         v_mto_gan_ml := nvl(i.mto_gan_anual, 0);
         v_mto_deb_ml := nvl(i.mto_gan_anual, 0);
         prg_obt_car_impuesto(v_cod_oficina, v_nro_cuenta, v_cod_mon_local, 4, 41, c_cod_tra_seguro,
                              v_mto_gan_ml, v_cod_tra_impuesto, v_cod_tas_ganancia, v_val_tasa,
                              v_imp_ano_ml);
         IF v_cod_mon_local = i.cod_moneda THEN
            v_mto_ganancia := nvl(v_mto_gan_ml, 0);
            v_iva_costo    := nvl(v_imp_ano_ml, 0);
            v_mto_debito   := nvl(v_mto_deb_ml, 0);
         ELSE
            v_cotizacion   := fug_obt_cotizacion(i.cod_moneda);
            v_mto_ganancia := round((nvl(v_mto_gan_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
            v_iva_costo    := round((nvl(v_imp_ano_ml, 0) / nvl(i.cotizacion, 0)), v_redondeo);
            v_mto_debito   := round((nvl(v_mto_deb_ml, 0) / nvl(i.cotizacion, 0)), v_redondeo);
         END IF;
         /*
         || Debito por la ganancia
         */
         IF v_mto_debito <> 0 THEN
            v_nro_secuencia := v_nro_secuencia + 1;
            IF v_nro_secuencia > 990 THEN
               --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
               v_nro_secuencia := -999;
            END IF;
            rg_movs.cod_transaccion := c_cod_tra_dis_gan;
            rg_movs.cod_modulo      := 4;
            rg_movs.cod_modalidad   := 41;
            rg_movs.cod_tra_padre   := c_cod_tra_padre;
            rg_movs.cod_mod_padre   := 4;
            rg_movs.cod_mad_padre   := 41;
            rg_movs.monto           := v_mto_debito;
            rg_movs.cod_moneda      := i.cod_moneda;
            --
            rg_movs.nro_cuenta    := NULL;
            rg_movs.cod_oficina   := v_cod_oficina;
            rg_movs.cod_usuario   := USER;
            rg_movs.hora          := v_hora;
            rg_movs.fecha         := v_fec_actual;
            rg_movs.nro_secuencia := v_nro_secuencia;
            rg_movs.fec_valor     := v_fec_actual;
            rg_movs.nro_documento := i.nro_cuota;--i.cantidad;
            rg_movs.cod_tasa      := NULL;
            rg_movs.val_tasa      := NULL;
            rg_movs.cotizacion    := v_cotizacion;
            IF v_cod_mon_local = i.cod_moneda THEN
               rg_movs.mto_equ_local := 0;
            ELSE
               rg_movs.mto_equ_local := v_mto_deb_ml;
            END IF;
            rg_movs.emi_aviso      := 'N';
            rg_movs.cod_ofi_origen := v_cod_oficina;
            rg_movs.concepto       := 'Ganancia Deb.Aut.Seg.c/Fraude';
            rg_movs.estado         := 'N';
            rg_movs.est_cuenta     := 'N';
            rg_movs.reversado      := 'N';
            rg_movs.emi_aviso      := 'N';
            rg_movs.nro_caja       := NULL;
            rg_movs.cod_rubro      := NULL;
            rg_movs.tip_mov_rubro  := 'D';
            rg_movs.referencia     := i.nro_cuenta;
            pag_gen.pr_ins_ge_movimiento(rg_movs, v_es_nocturno);
         END IF;
         /*
         || crédito a la aseguradora
         */
         IF v_mto_ganancia <> 0 THEN
            v_nro_secuencia := v_nro_secuencia + 1;
            IF v_nro_secuencia > 990 THEN
               --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
               v_nro_secuencia := -999;
            END IF;
            rg_movs.cod_transaccion := c_cod_tra_padre;
            rg_movs.cod_modulo      := 4;
            rg_movs.cod_modalidad   := 41;
            rg_movs.cod_tra_padre   := c_cod_tra_padre;
            rg_movs.cod_mod_padre   := 4;
            rg_movs.cod_mad_padre   := 41;
            rg_movs.monto           := v_mto_ganancia;
            rg_movs.cod_moneda      := i.cod_moneda;
            --
            rg_movs.nro_cuenta    := NULL;
            rg_movs.cod_oficina   := v_cod_oficina;
            rg_movs.cod_usuario   := USER;
            rg_movs.hora          := v_hora;
            rg_movs.fecha         := v_fec_actual;
            rg_movs.nro_secuencia := v_nro_secuencia;
            rg_movs.fec_valor     := v_fec_actual;
            rg_movs.nro_documento := i.nro_cuota;--i.cantidad;
            rg_movs.cod_tasa      := v_cod_tas_ganancia;
            rg_movs.val_tasa      := v_val_tas_ganancia;
            rg_movs.cotizacion    := v_cotizacion;
            IF v_cod_mon_local = i.cod_moneda THEN
               rg_movs.mto_equ_local := 0;
            ELSE
               rg_movs.mto_equ_local := v_mto_gan_ml;
            END IF;
            rg_movs.emi_aviso      := 'N';
            rg_movs.cod_ofi_origen := v_cod_oficina;
            rg_movs.concepto       := 'Ganancia Deb.Aut.Seg.c/Fraude';
            rg_movs.estado         := 'N';
            rg_movs.est_cuenta     := 'N';
            rg_movs.reversado      := 'N';
            rg_movs.emi_aviso      := 'N';
            rg_movs.nro_caja       := NULL;
            rg_movs.cod_rubro      := NULL;
            rg_movs.tip_mov_rubro  := 'C';
            rg_movs.referencia     := i.nro_cuenta;
            pag_gen.pr_ins_ge_movimiento(rg_movs, v_es_nocturno);
         END IF;
         /*
         || IVA COSTO
         */
         IF v_iva_costo <> 0 THEN
            IF v_nro_secuencia > 990 THEN
               --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
               v_nro_secuencia := -999;
            END IF;
            v_nro_secuencia         := v_nro_secuencia + 1;
            rg_movs.cod_transaccion := c_cod_tra_seguro;
            rg_movs.cod_modulo      := 4;
            rg_movs.cod_modalidad   := 41;
            rg_movs.cod_tra_padre   := c_cod_tra_padre;
            rg_movs.cod_mod_padre   := 4;
            rg_movs.cod_mad_padre   := 41;
            rg_movs.monto           := v_iva_costo;
            rg_movs.cod_moneda      := i.cod_moneda;
            --
            rg_movs.nro_cuenta     := NULL;
            rg_movs.cod_oficina    := v_cod_oficina;
            rg_movs.cod_usuario    := USER;
            rg_movs.hora           := v_hora;
            rg_movs.fecha          := v_fec_actual;
            rg_movs.nro_secuencia  := v_nro_secuencia;
            rg_movs.fec_valor      := v_fec_actual;
            rg_movs.nro_documento  := i.nro_cuota;--i.cantidad;
            rg_movs.cod_tasa       := v_cod_tas_impuesto;
            rg_movs.val_tasa       := v_val_tas_impuesto;
            rg_movs.cotizacion     := v_cotizacion;
            rg_movs.mto_equ_local  := v_imp_ano_ml;
            rg_movs.emi_aviso      := 'N';
            rg_movs.cod_ofi_origen := v_cod_oficina;
            rg_movs.concepto       := 'Ganancia Deb.Aut.Seg.c/Fraude';
            rg_movs.estado         := 'N';
            rg_movs.est_cuenta     := 'N';
            rg_movs.reversado      := 'N';
            rg_movs.emi_aviso      := 'N';
            rg_movs.nro_caja       := NULL;
            rg_movs.cod_rubro      := NULL;
            rg_movs.tip_mov_rubro  := 'C';
            rg_movs.referencia     := i.nro_cuenta;
            pag_gen.pr_ins_ge_movimiento(rg_movs, v_es_nocturno);
         END IF;
         --- Acumular el monto de la ganancia
         v_mto_acumulado := (i.mto_debito * v_por_ganancia) / 100;
         BEGIN
            UPDATE ge_seg_fraude a
               /*SET a.mto_acumulado = a.mto_acumulado + (SELECT (b.mto_debito * v_por_ganancia) / 100
                                                          FROM ge_seg_fraude_det b
                                                         WHERE a.ano = b.ano
                                                           AND a.nro_cuenta = b.nro_cuenta
                                                           AND b.cobrado = 'S'
                                                           AND b.contabilizado = 'N')*/
               SET a.mto_acumulado = a.mto_acumulado + nvl(v_mto_acumulado,0)
             WHERE /*EXISTS (SELECT 1
                      FROM ge_seg_fraude_det b
                     WHERE a.ano = b.ano
                       AND a.nro_cuenta = b.nro_cuenta
                       AND b.cobrado = 'S'
                       AND b.contabilizado = 'N')
               AND */a.nro_cuenta = i.nro_cuenta
               AND a.ano = i.ano;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000,
                                       'Error: Act.Cta.Cabecera:'||i.nro_cuenta||' -' || SQLERRM);
         END;         
         ---
         BEGIN
         --- Actualizar como contabilizado
            UPDATE ge_seg_fraude_det
               SET contabilizado = 'S'
             WHERE cobrado = 'S'
               AND contabilizado = 'N'
               AND nro_cuenta = i.nro_cuenta
               AND ano = i.ano
               AND nro_cuota = i.nro_cuota;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000,
                                       'Error: Act.Cta.Contabilizado -' || SQLERRM);
         END;
         ---
      END LOOP;
      p_hora          := v_hora;
      p_nro_secuencia := nvl(v_nro_secuencia, 0);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'PR_GEN_GANANCIA:' || SQLERRM);
   END pr_gen_ganancia;
   --- DYDMR-2117
   PROCEDURE pr_deb_pag_sue IS
      --- DYD-SDSL-2878      
      /*v_fec_implementacion ge_movimientos.fecha%TYPE; := fug_obt_parentes(v_cod_ente,
                                                                 'FEC_IMP_SEG_TAR_DEB');*/
      --v_mes_implementacion NUMBER(6) := to_number(to_char(v_fec_implementacion, 'yyyymm'));
      CURSOR c_debitos IS
         SELECT DISTINCT a.nro_cuenta nro_cuenta, to_number(to_char(g.fec_proceso, 'mm')) mes
           FROM ge_seg_fraude a, ge_pag_sueldos g
          WHERE a.fec_alta <= g.fec_proceso
            AND a.nro_cuenta = g.nro_cuenta
            AND a.ano <= to_number(to_char(g.fec_proceso, 'yyyy'))
            AND nvl(g.monto, 0) > 0
            AND a.estado = 'A' --MDPSETADE-74
            --- DYD-SDSL-2878: Cuentas nomina se debe cobrar desde la implementacion
            /*AND (to_number(to_char(a.fec_activacion, 'yyyymm')) >= v_mes_implementacion
                 OR
                (add_months(a.fec_activacion,12) >= v_fec_implementacion AND
                 add_months(v_fec_implementacion,12) <= v_fec_actual))*/
            AND NOT EXISTS (SELECT 1
                   FROM ge_seg_fraude_det t
                  WHERE t.ano = a.ano
                    AND t.nro_cuenta = a.nro_cuenta
                    AND t.ano <= to_number(to_char(g.fec_proceso, 'yyyy'))
                    AND t.mes = to_number(to_char(g.fec_proceso, 'mm')))
                  ORDER BY nro_cuenta, mes;
   BEGIN
      v_nro_secuencia := 0;
      ---
      v_hora := to_char(SYSDATE, 'HH24:MI:SS');
      v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
      FOR i IN c_debitos LOOP
         pr_deb_seg_fra(i.nro_cuenta, i.mes, v_hora, v_nro_secuencia, 'N');
      END LOOP;
   END pr_deb_pag_sue;

   PROCEDURE pr_del_seg_fra IS
      c_cod_tra_baja    ge_movimientos.cod_transaccion%TYPE := fug_obt_parentes(v_cod_ente,
                                                                                'TRA_BAJ_SEG_TAR_DEB');
      v_procesa         VARCHAR2(1);
      v_nro_cuenta      ge_cuentas.nro_cuenta%TYPE;
      v_nvo_estado      ah_cta_vistas.estado%TYPE;
      v_sal_disponible  NUMBER;
      v_mto_can_ml      ge_movimientos.monto%TYPE;
      v_mto_cre_ml      ge_movimientos.monto%TYPE;
      v_mto_not_ml      ge_movimientos.monto%TYPE;
      v_mto_cancelacion ge_movimientos.monto%TYPE;
      v_mto_credito     ge_movimientos.monto%TYPE;
      v_mto_nota        ge_movimientos.monto%TYPE;
      CURSOR c_bajas IS
         SELECT COUNT(t.nro_cuenta) cantidad,
                (SUM(g.mto_ganancia) - SUM(g.mto_acumulado)) mto_cancelacion,
                (SUM(g.mto_anual) - SUM(g.mto_ganancia) - SUM(g.mto_acumulado)) mto_debito,
                SUM(g.mto_acumulado) mto_acumulado, g.cod_moneda, g.cotizacion
           FROM ah_tar_debitos t, ge_seg_fraude g
          WHERE t.nro_cuenta = g.nro_cuenta
            AND t.nro_tarjeta = g.nro_tarjeta
            AND t.nro_emision = g.nro_emision
            AND t.cod_persona = g.cod_persona
            AND t.tar_activa = 'N'
            AND g.estado = 'A'
            AND t.adherente = '00'
            AND to_char(nvl(trunc(fec_cancelacion), trunc(add_months(v_fec_actual, -1))), 'yyyymm') =
                to_char(v_fec_actual, 'yyyymm') - 1
            AND t.nro_tarjeta IS NOT NULL
          GROUP BY g.cod_moneda, g.cotizacion;
   BEGIN
      v_hora := to_char(SYSDATE, 'HH24:MI:SS');
      v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
      v_nro_secuencia := 0;
      FOR i IN c_bajas LOOP
         v_cotizacion := NULL;
         v_mto_can_ml := i.mto_cancelacion;
         v_mto_cre_ml := i.mto_cancelacion + i.mto_debito - i.mto_acumulado;
         v_mto_not_ml := i.mto_acumulado;
         v_mto_deb_ml := i.mto_debito;
         -- Calcular impuesto
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 4, 41, i.cod_moneda);
         --
         IF v_cod_mon_local = i.cod_moneda THEN
            v_mto_cancelacion := nvl(v_mto_can_ml, 0);
            v_mto_credito     := nvl(v_mto_cre_ml, 0);
            v_mto_nota        := nvl(v_mto_not_ml, 0);
            v_mto_debito      := nvl(v_mto_deb_ml, 0);
         ELSE
            v_cotizacion      := fug_obt_cotizacion(i.cod_moneda);
            v_mto_cancelacion := round((nvl(v_mto_can_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
            v_mto_credito     := round((nvl(v_mto_cre_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
            v_mto_nota        := round((nvl(v_mto_not_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
            v_mto_debito      := round((nvl(v_mto_deb_ml, 0) / nvl(v_cotizacion, 0)), v_redondeo);
         END IF;
         /*
         || Debito Cancelacion Cuenta Transitoria
         */
         IF v_mto_cancelacion <> 0 THEN
            v_nro_secuencia := v_nro_secuencia + 1;
            IF v_nro_secuencia > 990 THEN
               --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
               v_nro_secuencia := -999;
            END IF;
            rg_movs.cod_transaccion := c_cod_tra_dis_gan;
            rg_movs.cod_modulo      := 4;
            rg_movs.cod_modalidad   := 41;
            rg_movs.cod_tra_padre   := c_cod_tra_padre;
            rg_movs.cod_mod_padre   := 4;
            rg_movs.cod_mad_padre   := 41;
            rg_movs.monto           := v_mto_cancelacion;
            rg_movs.cod_moneda      := i.cod_moneda;
            --
            rg_movs.nro_cuenta     := NULL;
            rg_movs.cod_oficina    := v_cod_oficina;
            rg_movs.cod_usuario    := USER;
            rg_movs.hora           := v_hora;
            rg_movs.fecha          := v_fec_actual;
            rg_movs.nro_secuencia  := v_nro_secuencia;
            rg_movs.fec_valor      := v_fec_actual;
            rg_movs.nro_documento  := i.cantidad;
            rg_movs.cod_tasa       := NULL;
            rg_movs.val_tasa       := NULL;
            rg_movs.cotizacion     := v_cotizacion;
            IF v_cod_mon_local = i.cod_moneda THEN
               rg_movs.mto_equ_local := 0;
            ELSE
               rg_movs.mto_equ_local := v_mto_can_ml;
            END IF;
            rg_movs.emi_aviso      := 'N';
            rg_movs.cod_ofi_origen := v_cod_oficina;
            rg_movs.concepto       := 'Baja Deb.Aut.Seg.c/Fraude';
            rg_movs.estado         := 'N';
            rg_movs.est_cuenta     := 'N';
            rg_movs.reversado      := 'N';
            rg_movs.emi_aviso      := 'N';
            rg_movs.nro_caja       := NULL;
            rg_movs.cod_rubro      := NULL;
            rg_movs.tip_mov_rubro  := 'D';
            pag_gen.pr_ins_ge_movimiento(rg_movs, v_es_nocturno);
         END IF;
         /*
         || Crédito Cancelacion Cuenta Transitoria
         */
         IF v_mto_credito <> 0 THEN
            v_nro_secuencia := v_nro_secuencia + 1;
            IF v_nro_secuencia > 990 THEN
               --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
               v_nro_secuencia := -999;
            END IF;
            rg_movs.cod_transaccion := c_cod_tra_seguro;
            rg_movs.cod_modulo      := 4;
            rg_movs.cod_modalidad   := 41;
            rg_movs.cod_tra_padre   := c_cod_tra_padre;
            rg_movs.cod_mod_padre   := 4;
            rg_movs.cod_mad_padre   := 41;
            rg_movs.monto           := v_mto_credito;
            rg_movs.cod_moneda      := i.cod_moneda;
            --
            rg_movs.nro_cuenta     := NULL;
            rg_movs.cod_oficina    := v_cod_oficina;
            rg_movs.cod_usuario    := USER;
            rg_movs.hora           := v_hora;
            rg_movs.fecha          := v_fec_actual;
            rg_movs.nro_secuencia  := v_nro_secuencia;
            rg_movs.fec_valor      := v_fec_actual;
            rg_movs.nro_documento  := i.cantidad;
            rg_movs.cod_tasa       := v_cod_tas_ganancia;
            rg_movs.val_tasa       := v_val_tas_ganancia;
            rg_movs.cotizacion     := v_cotizacion;
            IF v_cod_mon_local = i.cod_moneda THEN
               rg_movs.mto_equ_local := 0;
            ELSE
               rg_movs.mto_equ_local := v_mto_cre_ml;
            END IF;
            rg_movs.emi_aviso      := 'N';
            rg_movs.cod_ofi_origen := v_cod_oficina;
            rg_movs.concepto       := 'Baja Deb.Aut.Seg.c/Fraude';
            rg_movs.estado         := 'N';
            rg_movs.est_cuenta     := 'N';
            rg_movs.reversado      := 'N';
            rg_movs.emi_aviso      := 'N';
            rg_movs.nro_caja       := NULL;
            rg_movs.cod_rubro      := NULL;
            rg_movs.tip_mov_rubro  := 'C';
            pag_gen.pr_ins_ge_movimiento(rg_movs, v_es_nocturno);
         END IF;
         /*
         || Nota de Crédito por la baja
         */
         IF v_mto_nota <> 0 THEN
            v_nro_secuencia := v_nro_secuencia + 1;
            IF v_nro_secuencia > 990 THEN
               --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
               v_nro_secuencia := -999;
            END IF;
            rg_movs.cod_transaccion := c_cod_tra_baja;
            rg_movs.cod_modulo      := 4;
            rg_movs.cod_modalidad   := 41;
            rg_movs.cod_tra_padre   := c_cod_tra_padre;
            rg_movs.cod_mod_padre   := 4;
            rg_movs.cod_mad_padre   := 41;
            rg_movs.monto           := v_mto_nota;
            rg_movs.cod_moneda      := i.cod_moneda;
            --
            rg_movs.nro_cuenta     := NULL;
            rg_movs.cod_oficina    := v_cod_oficina;
            rg_movs.cod_usuario    := USER;
            rg_movs.hora           := v_hora;
            rg_movs.fecha          := v_fec_actual;
            rg_movs.nro_secuencia  := v_nro_secuencia;
            rg_movs.fec_valor      := v_fec_actual;
            rg_movs.nro_documento  := i.cantidad;
            rg_movs.cod_tasa       := NULL;
            rg_movs.val_tasa       := NULL;
            rg_movs.cotizacion     := v_cotizacion;
            IF v_cod_mon_local = i.cod_moneda THEN
               rg_movs.mto_equ_local := 0;
            ELSE
               rg_movs.mto_equ_local := v_mto_not_ml;
            END IF;
            rg_movs.emi_aviso      := 'N';
            rg_movs.cod_ofi_origen := v_cod_oficina;
            rg_movs.concepto       := 'Baja Deb.Aut.Seg.c/Fraude';
            rg_movs.estado         := 'N';
            rg_movs.est_cuenta     := 'N';
            rg_movs.reversado      := 'N';
            rg_movs.emi_aviso      := 'N';
            rg_movs.nro_caja       := NULL;
            rg_movs.cod_rubro      := NULL;
            rg_movs.tip_mov_rubro  := 'D';
            pag_gen.pr_ins_ge_movimiento(rg_movs, v_es_nocturno);
         END IF;
         /*
         || debito a la aseguradora
         */
         v_procesa := 'N';
         IF nvl(/*v_mto_debito*/v_mto_deb_ml, 0) <> 0 THEN
            v_nro_cuenta := fug_obt_parentes(v_cod_ente, 'CTA_SEG_TAR_DEB_GS'/* || i.cod_moneda*/);
            pag_cta.pr_obt_cuenta(v_nro_cuenta);
            IF v_nro_cuenta IS NULL THEN
               raise_application_error(-20000,
                                       'No se encuentra Cta.Seguro p/moneda' || i.cod_moneda);
            END IF;
            --- DYD-SDSL-2878: Acreditación siempre debe ser en GS.
            pag_cta.pr_ver_operacion(v_nro_cuenta, 503, 4, 41, 'D',
                                     /*pag_cta.g_ctas.cod_moneda*/v_cod_mon_local,
                                     /*v_mto_debito*/nvl(v_mto_deb_ml, 0), v_cod_oficina,
                                     /*variables out*/ pag_cta.g_ctas.cod_modulo,
                                     pag_cta.g_ctas.cod_modalidad, v_nvo_estado, v_sal_disponible,
                                     v_procesa);
            IF pag_cta.g_cod_error <> 0 OR
               v_procesa = 'N' THEN
               /*IF pag_cta.g_cod_error <> 0 THEN
                  IF pag_cta.g_cod_error IN (25, 29, 31, 36) THEN
                     -- No dispone de saldo suficiente
                     BEGIN
                        INSERT INTO ge_mov_pendientes
                           (cod_usuario, hora, cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
                            cod_moneda, cod_tra_padre, cod_transaccion, fecha, monto, estado,
                            cod_ofi_origen, cod_tasa, val_tasa, cod_mod_padre, cod_mad_padre,
                            nro_documento, concepto, saldo, car_manual)
                        VALUES
                           (USER, v_hora, pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                            pag_cta.g_ctas.cod_oficina, v_nro_cuenta, pag_cta.g_ctas.cod_moneda,
                            c_cod_tra_padre, 503, v_fec_actual, v_mto_debito,
                            'I', v_cod_oficina, NULL, 0, 4, 41, i.cantidad, 'Baja Deb.Aut.Seg.c/Fraude',
                            v_mto_debito, 'S');
                     EXCEPTION
                        WHEN OTHERS THEN*/
                           raise_application_error(-20000,
                                                   'Error: Cta.' || v_nro_cuenta || '-' || SQLERRM);
                     /*END;
                  ELSE
                     -- hubo otro error
                     v_procesa := 'N';
                  END IF;
               END IF;*/
            END IF;
         ELSE
            v_procesa := 'N';
         END IF;
         ---
         IF v_procesa = 'S' THEN
            --- DEBITAR de la cuenta
            IF v_nro_secuencia > 990 THEN
               --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
               v_nro_secuencia := -999;
            END IF;
            --- DYDMR-2064
            PAG_CTA.PR_SET_VARIABLES(user,
                                     v_fec_actual,
                                     c_cod_tra_padre,
                                     'N',-- estado
                                     'N',-- reversado
                                     v_nro_secuencia,
                                     null,
                                     v_cod_oficina,
                                     4,
                                     41);
            --- DYD-SDSL-2878: Acreditación siempre debe ser en GS.
            pag_cta.pr_act_operacion(v_nro_cuenta, v_hora, 'D',
                                     /*pag_cta.g_ctas.cod_moneda*/ v_cod_mon_local,
                                     round(/*v_mto_debito*/nvl(v_mto_deb_ml, 0), v_redondeo),
                                     c_cod_tra_padre, 503,
                                     i.cantidad, v_cotizacion, v_cod_oficina, 4, 41, NULL, NULL,
                                     'Debito Automático Seguro conta Fraude', 'S', v_nro_secuencia,
                                     v_fec_actual, NULL, NULL, v_mto_deb_ml);
            IF pag_cta.g_cod_error <> 0 THEN
               raise_application_error(-20000,
                                       'Error Act.Operación.Cta.Debito ' || v_nro_cuenta || '-' ||
                                        pag_cta.g_msj_error);
            END IF;
         END IF;
      END LOOP;
      UPDATE ge_seg_fraude g
         SET estado   = 'C',
             fec_baja =
             (SELECT MAX(nvl(trunc(fec_cancelacion), trunc(t.fec_modificacion)))
                FROM ah_tar_debitos t
               WHERE t.nro_cuenta = g.nro_cuenta
                 AND t.nro_tarjeta = g.nro_tarjeta
                 AND t.nro_emision = g.nro_emision
                 AND t.cod_persona = g.cod_persona
                 AND t.tar_activa = 'N'
                 AND g.estado = 'A'
                 AND t.adherente = '00'
                 AND to_char(nvl(trunc(fec_cancelacion), trunc(add_months(v_fec_actual, -1))), 'yyyymm') =
                     to_char(v_fec_actual, 'yyyymm') - 1
                 AND t.nro_tarjeta IS NOT NULL
               GROUP BY g.cod_moneda, g.cotizacion)
       WHERE EXISTS (SELECT 1
                FROM ah_tar_debitos t
               WHERE t.nro_cuenta = g.nro_cuenta
                 AND t.nro_tarjeta = g.nro_tarjeta
                 AND t.nro_emision = g.nro_emision
                 AND t.cod_persona = g.cod_persona
                 AND t.tar_activa = 'N'
                 AND g.estado = 'A'
                 AND t.adherente = '00'
                 AND to_char(nvl(trunc(fec_cancelacion), trunc(add_months(v_fec_actual, -1))), 'yyyymm') =
                     to_char(v_fec_actual, 'yyyymm') - 1
                 AND t.nro_tarjeta IS NOT NULL
               GROUP BY g.cod_moneda, g.cotizacion);
   END;

   PROCEDURE pr_pro_seg_fra IS
      v_fec_pri_dia_habil ge_calendarios.pri_dia_mes_habil%TYPE;
      v_cantidad          number := 0;
      v_can_av            number := 0;
      v_can_cc            number := 0;
      v_can_baja          number := 0;
   BEGIN
      v_hora              := to_char(SYSDATE, 'HH24:MI:SS');
      v_hora              := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
      v_fec_pri_dia_habil := pag_cal.fu_obt_fec_pri_dia_mes_habil(4);
      IF v_fec_actual >= v_fec_pri_dia_habil then
         --- Procesa Altas
         SELECT nvl(COUNT(to_number(to_char(fec_alta, 'yyyymm'))),0)
           INTO v_cantidad
           FROM ge_seg_fraude t
          WHERE to_number(to_char(fec_alta, 'yyyymm')) = to_number(to_char(v_fec_actual, 'yyyymm'));   
         IF nvl(v_cantidad,0) = 0 THEN
            pr_ins_seg_fra;
         END IF;
         --- Procesa Cobros
         SELECT nvl(COUNT(d.nro_cuenta), 0)
           INTO v_can_av
           FROM ge_seg_fraude_det d, ge_seg_fraude t, ah_cta_vistas g
          WHERE d.ano = to_number(to_char(v_fec_actual, 'yyyy'))
            AND d.mes = to_number(to_char(v_fec_actual, 'mm'))
            AND d.nro_cuenta = t.nro_cuenta
            AND t.estado = 'A'
            AND d.nro_cuenta = g.nro_cuenta
            AND g.cod_ente IS NULL;
         SELECT nvl(COUNT(d.nro_cuenta), 0)
           INTO v_can_cc
           FROM ge_seg_fraude_det d, ge_seg_fraude t, cc_cta_corrientes g
          WHERE d.ano = to_number(to_char(v_fec_actual, 'yyyy'))
            AND d.mes = to_number(to_char(v_fec_actual, 'mm'))
            AND d.nro_cuenta = t.nro_cuenta
            AND t.estado = 'A'
            AND d.nro_cuenta = g.nro_cuenta
            AND g.cod_ente IS NULL;
         IF nvl(v_can_av,0) = 0 AND nvl(v_can_cc,0) = 0 THEN
            --- DYDMR-2117
            v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
            v_nro_secuencia := 0;
            pr_deb_seg_fra(null, null, v_hora, v_nro_secuencia, 'C');
         END IF;
         --- Procesa Debitos por pago de Salarios
         --- DYDMR-2117
         pr_deb_pag_sue;
         --- Procesa Bajas
         SELECT nvl(COUNT(t.nro_cuenta),0) cantidad
           INTO v_can_baja
           FROM ah_tar_debitos t, ge_seg_fraude g
          WHERE t.nro_cuenta = g.nro_cuenta
            AND t.nro_tarjeta = g.nro_tarjeta
            AND t.nro_emision = g.nro_emision
            AND t.cod_persona = g.cod_persona
            AND t.tar_activa = 'N'
            AND g.estado = 'A'
            AND t.adherente = '00'
            AND to_char(nvl(trunc(fec_cancelacion), trunc(add_months(v_fec_actual, -1))), 'yyyymm') =
                to_char(v_fec_actual, 'yyyymm') - 1
            AND t.nro_tarjeta IS NOT NULL;
         IF nvl(v_can_baja,0) > 0 THEN
            pr_del_seg_fra;
         END IF;
      END IF;
      ---
      v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
      v_nro_secuencia := 0;
      pr_gen_ganancia(null, v_hora, v_nro_secuencia, 'N');
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'PR_PRO_SEG_FRA:' || SQLERRM);
   END pr_pro_seg_fra;

END pag_deb;
/

