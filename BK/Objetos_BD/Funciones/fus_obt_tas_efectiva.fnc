CREATE OR REPLACE FUNCTION IT.FUS_OBT_TAS_EFECTIVA (p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE)
   RETURN NUMBER IS
   v_fec_actual         DATE;
   v_monto              sb_tas_ape_semanales.monto%TYPE;
   v_tas_nominal        sb_tas_ape_semanales.val_tas_nominal%TYPE;
   v_nro_solicitud      pr_cta_prestamos.nro_solicitud%TYPE;
   v_aux1               NUMBER(7);
   v_aux2               NUMBER(7);
   v_dias               NUMBER(6);
   v_capital            ah_cta_certificados.capital%TYPE;
   v_tas_efectiva       sb_tas_ape_semanales.val_tas_efectiva%TYPE;
   v_mon_orig           sb_tas_ape_semanales.mto_ape_original%TYPE;
   v_cod_mon_orig       sb_tas_ape_semanales.cod_mon_original%TYPE;
   v_tip_capitalizacion ah_cta_certificados.tip_capitalizacion%TYPE;
   v_plazo              ge_plz_contables.cod_plazo%TYPE;
   v_cod_mon_local      ba_monedas.cod_moneda%TYPE;
   v_periodo            NUMBER(10);
   v_sal_acumulado      cc_sal_mensuales.sal_acu_deudor%TYPE;
   v_sal_promedio       cc_sal_mensuales.sal_acu_deudor%TYPE;
   v_can_dia_acumulado  cc_sal_mensuales.can_dia_acumulado%TYPE;
   v_val_tasa           ge_tas_fechas.val_tasa%TYPE;
   rv_mcdoc             md_cta_documentos%ROWTYPE;
   --- Recuperar datos de cuentas - diario
   CURSOR c_cuentas IS
      SELECT a.cod_modulo,
             a.cod_modalidad,
             cod_oficina,
             cod_moneda,
             nro_cuenta,
             sal_contable,
             fec_apertura,
             fec_vencimiento,
             val_tasa,
             tas_personalizada,
             cod_tasa
        FROM ge_cuentas a, ge_est_cuentas b
       WHERE a.cod_modulo = b.cod_modulo
         AND a.cod_modalidad = b.cod_modalidad
         AND a.estado = b.estado
         AND activo = 'S'
         AND (a.cod_modulo = 6 OR (a.cod_modulo = 3 AND a.estado <> 'A') or a.cod_modalidad=37 OR
             (a.cod_modulo = 10 AND
             (fug_obt_pardinamico('MDD_MAD_EMI_CALLMONEY', a.cod_modulo, a.cod_modalidad, NULL,
                                    NULL, NULL) = 'S' OR
             fug_obt_pardinamico('MDD_MAD_REC_CALLMONEY', a.cod_modulo, a.cod_modalidad, NULL,
                                    NULL, NULL) = 'S')))
         AND nvl(sal_contable, 0) > 0
         AND ((nvl(a.val_tasa, 0) > 0 AND a.cod_modulo = 6)     OR
              (nvl(a.val_tasa, 0) = 0 AND a.cod_modalidad = 33) OR
              (nvl(a.val_tasa, 0) > 0 and a.cod_modalidad = 37) OR
              (nvl(a.val_tasa, 0) > 0 and a.cod_modalidad = 38) OR
             (a.cod_modulo = 10 AND
             (fug_obt_pardinamico('MDD_MAD_EMI_CALLMONEY', a.cod_modulo, a.cod_modalidad, NULL,
                                    NULL, NULL) = 'S' OR
             fug_obt_pardinamico('MDD_MAD_REC_CALLMONEY', a.cod_modulo, a.cod_modalidad, NULL,
                                    NULL, NULL) = 'S')))
         AND a.nro_cuenta = p_nro_cuenta;

   CURSOR c_vistas IS
      SELECT nvl(SUM(d.sal_actual), 0) monto
        FROM cb_sal_inventarios_det_his d, cb_sal_inventarios_his c, ba_monedas m
       WHERE c.fecha = v_fec_actual
         AND d.nro_referencia = c.nro_referencia
         AND d.fecha = c.fecha
         AND c.cod_moneda = m.cod_moneda
         AND c.cod_modulo = 3
         AND c.cod_modalidad = 31
         AND nvl(c.sal_total, 0) != 0
         AND substr(c.cod_rubro, 6, 3) IN ('102', '196', '138', '236', '238', '292')
         AND c.cod_rubro IS NOT NULL
         AND d.nro_cuenta = p_nro_cuenta;

   CURSOR c_cta_vistas IS
      SELECT tip_capitalizacion FROM ah_cta_vistas WHERE nro_cuenta = p_nro_cuenta;

   CURSOR c_certificados IS
      SELECT nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0)
        FROM ah_cta_certificados
       WHERE nro_cuenta = p_nro_cuenta;

   CURSOR c_cert IS
      SELECT tip_capitalizacion, capital FROM ah_cta_certificados WHERE nro_cuenta = p_nro_cuenta;
   
   CURSOR c_pla_fijo IS
      SELECT nvl(sal_tot_batch,0)-nvl(sal_ret_batch,0)
        FROM ah_cta_plazos
       WHERE nro_cuenta = p_nro_cuenta; 

   CURSOR c_plazo_fijo IS
      SELECT tip_capitalizacion,capital
        FROM ah_cta_plazos
       WHERE nro_cuenta = p_nro_cuenta; 

   --Saldos de Tarjetas Mensuales.
   CURSOR c_tarjetas IS
      SELECT nvl(acu_sal_financiado, 0) + nvl(acu_sal_facturado, 0) + nvl(acu_sal_facturar, 0) +
             nvl(acu_sal_cuo_pendiente, 0) / nvl(can_dia_acumulado, 1) promedio
        FROM ta_sal_mensuales
       WHERE ano = to_number(to_char(v_fec_actual, 'YYYY'))
         AND mes = to_number(to_char(v_fec_actual, 'MM'))
         AND nro_cuenta = p_nro_cuenta;

   CURSOR c_prestamos IS
      SELECT nro_solicitud, mto_capital FROM pr_cta_prestamos WHERE nro_cuenta = p_nro_cuenta;

   CURSOR c_sobregiros IS
      SELECT nvl(SUM(d.sal_actual), 0) monto
        FROM cb_sal_inventarios_det_his d, cb_sal_inventarios_his c, ba_monedas m
       WHERE c.fecha = v_fec_actual
         AND d.nro_referencia = c.nro_referencia
         AND d.fecha = c.fecha
         AND c.cod_moneda = m.cod_moneda
         AND c.cod_modulo = 4
         AND c.cod_modalidad = 41
         AND nvl(c.sal_total, 0) != 0
         AND (substr(c.cod_rubro, 6, 3) IN ('187', '189') OR
             substr(c.cod_rubro, 6, 5) IN ('21508', '39702'))
         AND c.cod_rubro IS NOT NULL
         AND d.nro_cuenta = p_nro_cuenta;

   CURSOR c_cuentas_men IS
      SELECT a.cod_modulo,
             a.cod_modalidad,
             cod_oficina,
             cod_moneda,
             nro_cuenta,
             sal_contable,
             fec_apertura,
             fec_vencimiento,
             val_tasa,
             tas_personalizada,
             cod_tasa
        FROM ge_cuentas a, ge_est_cuentas b
       WHERE a.cod_modulo = b.cod_modulo
         AND a.cod_modalidad = b.cod_modalidad
         AND a.estado = b.estado
         AND a.nro_cuenta = p_nro_cuenta
         AND activo = 'S' --sólo las activas
         AND (a.cod_modalidad = 31 AND a.cod_modulo = 3 AND a.estado <> 'A')
      UNION
      SELECT a.cod_modulo,
             a.cod_modalidad,
             cod_oficina,
             cod_moneda,
             nro_cuenta,
             sal_contable,
             fec_apertura,
             fec_vencimiento,
             val_tasa,
             tas_personalizada,
             cod_tasa
        FROM ge_cuentas a, ge_est_cuentas b
       WHERE a.cod_modulo = b.cod_modulo
         AND a.cod_modalidad = b.cod_modalidad
         AND a.estado = b.estado
         AND activo = 'N' --sólo las activas
         AND a.cod_modalidad = 31
         AND a.cod_modulo = 3
         AND a.estado <> 'A'
         AND a.nro_cuenta = p_nro_cuenta
         AND nvl(a.sal_contable, 0) != 0
      UNION
      SELECT a.cod_modulo,
             a.cod_modalidad,
             cod_oficina,
             cod_moneda,
             nro_cuenta,
             abs(sal_contable),
             fec_apertura,
             fec_vencimiento,
             val_tasa,
             tas_personalizada,
             cod_tasa
        FROM ge_cuentas a, ge_est_cuentas b
       WHERE a.cod_modulo = b.cod_modulo
         AND a.cod_modalidad = b.cod_modalidad
         AND a.estado = b.estado
         AND activo = 'S' --sólo las activas
         AND a.cod_modalidad != 55
         AND a.nro_cuenta = p_nro_cuenta
         AND (a.cod_modulo = 5 AND nvl(a.val_tasa, 0) > 0 AND a.estado <> 'A')
      UNION
      SELECT a.cod_modulo,
             a.cod_modalidad,
             cod_oficina,
             cod_moneda,
             nro_cuenta,
             abs(sal_contable),
             fec_apertura,
             fec_vencimiento,
             val_tasa,
             tas_personalizada,
             cod_tasa
        FROM ge_cuentas a, ge_est_cuentas b
       WHERE a.cod_modulo = b.cod_modulo
         AND a.cod_modalidad = b.cod_modalidad
         AND a.estado = b.estado
         AND a.nro_cuenta = p_nro_cuenta
         AND activo = 'S' --sólo las activas
         AND a.cod_modalidad = 41
       ORDER BY 1, 4;

   v_saldo    NUMBER(18, 2);
   v_sal_orig NUMBER(18, 2);
BEGIN

   pag_cal.pr_obt_dat_calendar(3);
   v_fec_actual    := pag_cal.fu_obt_fec_actual(3);
   v_cod_mon_local := pag_gen.fu_obt_mon_local;

   FOR cuo IN c_cuentas_men LOOP
      IF cuo.cod_modulo = 3 THEN
         OPEN c_vistas;
         FETCH c_vistas
            INTO v_monto;
         CLOSE c_vistas;
         OPEN c_cta_vistas;
         FETCH c_cta_vistas
            INTO v_tip_capitalizacion;
         CLOSE c_cta_vistas;
      ELSIF cuo.cod_modulo = 4 THEN
         OPEN c_sobregiros;
         FETCH c_sobregiros
            INTO v_monto;
         CLOSE c_sobregiros;
      ELSIF cuo.cod_modulo = 5 THEN
         OPEN c_tarjetas;
         FETCH c_tarjetas
            INTO v_monto;
         CLOSE c_tarjetas;
      END IF;
      v_cod_mon_orig := cuo.cod_moneda;
      v_mon_orig     := v_monto;
      v_sal_orig     := v_saldo;
      IF cuo.cod_moneda <> v_cod_mon_local THEN
         pag_gen.pr_con_mon_a_moneda(cuo.cod_moneda, v_cod_mon_local, v_mon_orig, v_monto, v_aux1,
                                     v_aux2);
         pag_gen.pr_con_mon_a_moneda(cuo.cod_moneda, v_cod_mon_local, v_sal_orig, v_saldo, v_aux1,
                                     v_aux2);
      END IF;

      v_dias := nvl(cuo.fec_vencimiento, cuo.fec_apertura + 1) - cuo.fec_apertura;

      IF ((cuo.cod_modulo = 3 AND cuo.cod_modalidad = 31) OR cuo.cod_modulo IN (4, 5)) THEN
         v_plazo := 1;
      ELSE
         v_plazo := fug_obt_plz_contable(v_dias);
      END IF;
      v_tas_nominal := NULL;
      IF cuo.val_tasa IS NULL AND cuo.cod_tasa IS NOT NULL THEN
         v_tas_nominal := fug_obt_val_tasa(cuo.cod_modulo, cuo.cod_modalidad, cuo.cod_oficina,
                                           cuo.nro_cuenta, cuo.cod_moneda, v_mon_orig,
                                           cuo.tas_personalizada, cuo.cod_tasa, NULL, v_fec_actual);
      ELSE
         IF cuo.cod_modulo = 4 THEN
            v_tas_nominal := 0;
         ELSE
            v_tas_nominal := cuo.val_tasa;
         END IF;
      END IF;
      IF cuo.cod_modulo = 3 THEN
         SELECT decode(v_tip_capitalizacion, 1, 30, 2, 60, 3, 90, 4, 120, 6, 180, 12, 365, 99,
                       v_plazo, NULL)
           INTO v_periodo
           FROM dual;
         v_tas_efectiva := round(pas_bcp.fu_obt_tae(v_tas_nominal, v_periodo), 2);
      ELSIF cuo.cod_modulo = 4 THEN
         pag_cta.pr_obt_sal_promedio(cuo.cod_modulo, cuo.cod_modalidad, cuo.cod_oficina,
                                     cuo.nro_cuenta, v_fec_actual, v_fec_actual, v_sal_acumulado,
                                     v_sal_promedio, v_can_dia_acumulado);
         v_val_tasa     := fug_obt_val_tasa(cuo.cod_modulo, cuo.cod_modalidad, cuo.cod_oficina,
                                            cuo.nro_cuenta, cuo.cod_moneda, v_sal_promedio,
                                            cuo.tas_personalizada, NULL, 550, v_fec_actual);
         v_tas_efectiva := pas_bcp.fu_obt_tae(v_val_tasa, 30);
      ELSIF cuo.cod_modulo = 5 THEN
         v_tas_efectiva := round(pas_bcp.fu_obt_tae(v_tas_nominal, 30), 2);
      END IF;

   END LOOP;
   FOR cuo IN c_cuentas LOOP
      IF cuo.cod_modulo = 10 THEN
         pam_doc.pr_obt_datos(cuo.nro_cuenta, rv_mcdoc);
         v_cod_mon_orig := cuo.cod_moneda;
         v_monto        := cuo.sal_contable;
         v_mon_orig     := rv_mcdoc.monto;
         v_tas_nominal  := rv_mcdoc.val_tasa;
         IF (rv_mcdoc.fec_vencimiento - rv_mcdoc.fec_inicio) = 0 THEN
            v_dias := 1;
         ELSE
            v_dias := rv_mcdoc.fec_vencimiento - rv_mcdoc.fec_inicio;
         END IF;
         v_plazo        := fug_obt_plz_contable(v_dias);
         v_tas_efectiva := pas_bcp.fu_obt_tae(v_tas_nominal, v_dias);
      ELSE
         IF cuo.cod_modulo = 3 AND cuo.cod_modalidad = 33 THEN
            OPEN c_certificados;
            FETCH c_certificados
               INTO v_monto;
            CLOSE c_certificados;
         ELSIF cuo.cod_modulo = 3 AND cuo.cod_modalidad IN (37, 38) THEN
            OPEN c_pla_fijo;
            FETCH c_pla_fijo
               INTO v_monto;
            CLOSE c_pla_fijo;
         ELSE
            v_monto := cuo.sal_contable;
         END IF;
         v_cod_mon_orig := cuo.cod_moneda;
         v_mon_orig     := v_monto;
         v_dias         := nvl(cuo.fec_vencimiento, cuo.fec_apertura + 1) - cuo.fec_apertura;
         v_plazo        := fug_obt_plz_contable(v_dias);
         IF cuo.val_tasa IS NULL THEN
            v_tas_nominal := fug_obt_val_tasa(cuo.cod_modulo, cuo.cod_modalidad, cuo.cod_oficina,
                                              cuo.nro_cuenta, cuo.cod_moneda, v_mon_orig,
                                              cuo.tas_personalizada, cuo.cod_tasa, NULL, v_fec_actual);
         ELSE
            v_tas_nominal := cuo.val_tasa;
         END IF;
         IF cuo.cod_modulo = 3 and cuo.cod_modalidad IN (37, 38) THEN
            OPEN c_plazo_fijo;
            FETCH c_plazo_fijo 
               INTO v_tip_capitalizacion,v_capital;
            CLOSE c_plazo_fijo;
            v_tas_efectiva := pas_bcp.fu_obt_tae_cda(v_tip_capitalizacion,v_tas_nominal, v_dias,
                                                     v_capital);
         ELSIF cuo.cod_modulo = 3 THEN
            OPEN c_cert;
            FETCH c_cert
               INTO v_tip_capitalizacion, v_capital;
            CLOSE c_cert;
            v_tas_efectiva := pas_bcp.fu_obt_tae_cda(v_tip_capitalizacion, v_tas_nominal, v_dias,
                                                     v_capital);
         ELSIF cuo.cod_modulo = 6 THEN
            OPEN c_prestamos;
            FETCH c_prestamos
               INTO v_nro_solicitud, v_monto;
            CLOSE c_prestamos;
            v_mon_orig := v_monto;

            BEGIN
               pas_bcp.pr_obt_tas_prestamo(NULL, cuo.nro_cuenta, v_tas_efectiva, v_tas_nominal);
            EXCEPTION
               WHEN OTHERS THEN
                  v_tas_efectiva := NULL;
            END;
            IF v_tas_efectiva IS NULL OR v_tas_efectiva > 100 THEN
               v_tas_efectiva := pas_bcp.fu_obt_tae(cuo.val_tasa, 30);
            END IF;

         END IF;
      END IF;
   END LOOP;
   IF v_tas_efectiva >= 60 THEN
      v_tas_efectiva := round(pas_bcp.fu_obt_tae(v_tas_nominal, 30), 2);
   END IF;
   RETURN v_tas_efectiva;
EXCEPTION
   WHEN OTHERS THEN
      RETURN 0;
END;
/

