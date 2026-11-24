CREATE OR REPLACE PROCEDURE IT."PRB_GEN_ASI_FUTUROS" (p_cod_cargo cb_gas_diferidos.cod_cargo%TYPE DEFAULT NULL) IS
   v_mto_asiento     cb_asi_futuros_det.mto_mon_local%TYPE := 0;
   v_diferencia      cb_asi_futuros_det.mto_mon_local%TYPE := 0;
   v_cant_cuotas     NUMBER(10);
   v_mto_cuota       cb_asi_futuros_det.mto_mon_local%TYPE := 0;
   v_cont            NUMBER(10) := 0;
   v_mto_mon_local   cb_asi_futuros_det.mto_mon_local%TYPE;
   v_mto_mon_rubro   cb_asi_futuros_det.mto_mon_rubro%TYPE;
   v_nro_asiento     cb_asi_futuros.nro_asiento%TYPE;
   v_fecha           cb_asi_futuros.fecha%TYPE;
   v_nro_linea       cb_asi_futuros_det.nro_linea%TYPE := 0;
   v_cot_debito      cb_asi_futuros_det.val_cotizacion%TYPE := 0;
   v_cot_credito     cb_asi_futuros_det.val_cotizacion%TYPE := 0;
   v_fec_futuro      cb_asi_futuros.fecha%TYPE;
   v_ctrl_fec_habil  DATE;
   v_fec_actual      DATE;
   v_fec_desde       DATE;
   v_fec_hasta       DATE;
   v_ult_dia_mes_ant DATE;
   v_mto_diferido    cb_asi_futuros_det.mto_mon_local%TYPE := 0;
   v_val_total       pv_compras_det.val_total%TYPE := 0;
   v_mto_total       pv_compras_det.val_total%TYPE := 0;
   v_cod_moneda      ba_monedas.cod_moneda%TYPE;
   v_cod_rub_credito cb_gas_diferidos.cod_rub_credito%TYPE;
   v_periodicidad    ge_par_dinamicos.val_parametro%TYPE;
   v_mon_rub_credito cb_rubros.cod_moneda%TYPE;
   v_mon_rub_debito  cb_rubros.cod_moneda%TYPE;
   v_mto_rub_credito cb_asi_futuros_det.mto_mon_rubro%TYPE := 0;
   v_mto_rub_debito  cb_asi_futuros_det.mto_mon_rubro%TYPE := 0;
   v_mto_asi_credito cb_asi_futuros_det.mto_mon_rubro%TYPE := 0;
   v_mto_asi_debito  cb_asi_futuros_det.mto_mon_rubro%TYPE := 0;
   v_mto_acu_credito cb_asi_futuros_det.mto_mon_rubro%TYPE := 0;
   v_mto_acu_debito  cb_asi_futuros_det.mto_mon_rubro%TYPE := 0;
   v_fec_min_devengado cb_asi_futuros.fecha%TYPE;
   v_tot_dev_dia     cb_asi_futuros_det.mto_mon_local%type;

   CURSOR c_gas_diferidos IS
      SELECT a.cod_cargo,
             a.fec_desde,
             a.fec_hasta,
             a.nro_orden,
             a.nro_linea,
             a.cod_oficina,
             a.descripcion,
             a.cod_rub_debito,
             a.cod_transaccion,
             a.periodicidad
        FROM cb_gas_diferidos a
       WHERE ((p_cod_cargo IS NULL AND EXISTS
              (SELECT 1
                  FROM pv_compras b
                 WHERE a.procesado = 'N'
                   AND b.cod_compra = a.nro_orden
                   AND b.estado NOT IN ('I', 'N'))) OR
             (p_cod_cargo IS NOT NULL AND p_cod_cargo = a.cod_cargo));

   PROCEDURE lp_obt_dat_compras
   (
      v_cod_cargo       cb_gas_diferidos.cod_cargo%TYPE,
      v_nro_orden       cb_gas_diferidos.nro_orden%TYPE,
      v_nro_linea       cb_gas_diferidos.nro_linea%TYPE,
      v_cod_transaccion cb_gas_diferidos.cod_transaccion%TYPE,
      v_tot_dev_dia     cb_asi_futuros_det.mto_mon_local%TYPE DEFAULT 0
   ) IS
   BEGIN
      --agregado para actualizaciones de cuotas

      BEGIN
         SELECT SUM(nvl(mto_mon_local, 0)) - nvl(v_tot_dev_dia,0), SUM(nvl(mto_mon_rubro, 0)), MAX(fut.fecha)
           INTO v_mto_mon_local, v_mto_mon_rubro, v_fec_futuro
           FROM cb_asi_futuros_det det, cb_asi_futuros fut
          WHERE det.fecha = fut.fecha
            AND det.cod_oficina = fut.cod_oficina
            AND det.nro_asiento = fut.nro_asiento
            AND fut.nro_asi_real IS NOT NULL
               --   and fut.confirmado = 'S'
            AND det.tip_movimiento = 'D'
            AND fut.cod_cargo = v_cod_cargo;
      EXCEPTION
         WHEN OTHERS THEN
            v_mto_mon_local := 0;
            v_mto_mon_rubro := 0;
            v_fec_futuro    := NULL;
      END;

      IF p_cod_cargo IS NULL THEN
         --Consulta datos de la compra
         BEGIN
            SELECT a.mto_neto, b.cod_moneda
              INTO v_val_total, v_cod_moneda
              FROM pv_compras_det a, pv_compras b
             WHERE a.cod_compra = b.cod_compra
               AND a.cod_compra = v_nro_orden
               AND a.nro_linea = v_nro_linea
               AND b.estado NOT IN ('I', 'N');
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000, 'No existen datos de la Compra');
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error Obt.datos Compra:' || SQLERRM);
         END;
         -- Obtiene el rubro para el crédito
         BEGIN
            SELECT cod_rubro
              INTO v_cod_rub_credito
              FROM ge_tip_asientos a, ge_transacciones t
             WHERE a.cod_tip_asiento IN (t.cod_tip_asiento, t.cod_tip_asiento2)
               AND t.cod_transaccion = v_cod_transaccion
               AND a.cod_moneda = v_cod_moneda
               AND a.tip_movimiento = 'D';
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000, 'No se encontró el rubro para el Crédito');
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error Obt.datos Rub.Credito:' || SQLERRM);
         END;
      ELSE
         -- Recalcula Gastos Diferidos ingresados por pantalla
         -- Obtiene el rubro para el crédito
         BEGIN
            SELECT monto, cod_rub_credito
              INTO v_val_total, v_cod_rub_credito
              FROM cb_gas_diferidos a
             WHERE cod_cargo = p_cod_cargo;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000, 'No se encontró el rubro para el Crédito');
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error Obt.datos Rub.Credito:' || SQLERRM);
         END;
         IF v_cod_rub_credito IS NULL THEN
            raise_application_error(-20000, 'No se encontró el rubro para el Crédito');
         END IF;
         /*
         || Si se ingresa por la pantalla implica
         || que el Gasto Diferido es siempre guaraníes.
         */
         v_cod_moneda := pag_gen.fu_obt_mon_local;
      END IF;
   END;

   PROCEDURE lp_obt_cotizacion
   (
      p_cod_rub_debito  cb_rubros.cod_rubro%TYPE,
      p_cod_rub_credito cb_rubros.cod_rubro%TYPE
   ) IS
   BEGIN
      /*
      || Si el sector del rubro es 6 (Ganacias) o 7 (Pérdidas)
      || implica que el rubro es siempre guaraníes.
      */
      IF substr(p_cod_rub_credito, 1, 1) IN (6, 7) THEN
         v_mon_rub_credito := pag_gen.fu_obt_mon_local;
      ELSE
         BEGIN
            SELECT cod_moneda
              INTO v_mon_rub_credito
              FROM cb_rubros
             WHERE cod_rubro = p_cod_rub_credito;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000, 'No se encontró la moneda el rubro para el Crédito');
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error Obt.datos Rubro:' || SQLERRM);
         END;
      END IF;
      /*
      || Si el sector del rubro es 6 (Ganacias) o 7 (Pérdidas)
      || implica que el rubro es siempre guaraníes.
      */
      IF substr(p_cod_rub_debito, 1, 1) IN (6, 7) THEN
         v_mon_rub_debito := pag_gen.fu_obt_mon_local;
      ELSE
         BEGIN
            SELECT cod_moneda
              INTO v_mon_rub_debito
              FROM cb_rubros
             WHERE cod_rubro = p_cod_rub_debito;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000, 'No se encontró la moneda el rubro para el Débito');
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error Obt.datos Rubro:' || SQLERRM);
         END;
      END IF;
      -- Obtinene la cotización
      v_cot_debito  := NULL;
      v_cot_credito := NULL;
      SELECT fug_obt_cotizacion(v_mon_rub_debito), fug_obt_cotizacion(v_mon_rub_credito)
        INTO v_cot_debito, v_cot_credito
        FROM dual;
      IF v_cot_debito IS NULL OR v_cot_credito IS NULL THEN
         IF v_mon_rub_debito = pag_gen.fu_obt_mon_local THEN
            v_cot_debito := 1;
         END IF;
         IF v_mon_rub_credito = pag_gen.fu_obt_mon_local THEN
            v_cot_credito := 1;
         END IF;
         IF v_cot_debito IS NULL OR v_cot_credito IS NULL THEN
            raise_application_error(-20000,
                                    'Error al obtener cotización. Cargue primero la cotización del día.');
         END IF;
      END IF;

      -- Convertir siempre a GS
      IF v_cod_moneda = pag_gen.fu_obt_mon_local THEN
         v_mto_total := v_val_total;
      ELSE
         v_mto_total := pal_cam.fu_con_mon_a_moneda(v_cod_moneda, pag_gen.fu_obt_mon_local,
                                                    v_val_total);
      END IF;
      --agregado para actualizaciones de cuotas
      v_mto_cuota := (v_mto_total - nvl(v_mto_mon_local, 0)) / v_cant_cuotas;

      IF v_mto_cuota <> round(v_mto_cuota) THEN
         v_diferencia := (v_mto_total - nvl(v_mto_mon_local, 0)) -
                         (round(v_mto_cuota) * v_cant_cuotas);
      ELSE
         v_diferencia := 0;
      END IF;
      --- Agregado para calcular redondeo en moneda extranjera
      IF v_mon_rub_credito = pag_gen.fu_obt_mon_local THEN
         v_mto_rub_credito := NULL;
      ELSE
         v_mto_rub_credito := pal_cam.fu_con_mon_a_moneda(v_cod_moneda, v_mon_rub_credito,
                                                          v_val_total);
      END IF;
      IF v_mon_rub_debito = pag_gen.fu_obt_mon_local THEN
         v_mto_rub_debito := NULL;
      ELSE
         v_mto_rub_debito := pal_cam.fu_con_mon_a_moneda(v_cod_moneda, v_mon_rub_debito, v_val_total);
      END IF;

   END;

   PROCEDURE lp_ins_asi_futuros
   (
      v_cod_oficina    ba_oficinas.cod_oficina%TYPE,
      v_cod_cargo      cb_gas_diferidos.cod_cargo%TYPE,
      v_cod_rub_debito cb_gas_diferidos.cod_rub_debito%TYPE,
      v_descripcion    cb_gas_diferidos.descripcion%TYPE
   ) IS
   BEGIN

      IF v_cont = v_cant_cuotas THEN
         v_mto_asiento := round(v_mto_cuota + v_diferencia);
      ELSIF v_mto_diferido > 0 THEN
         -- rabf - 14/dic/2010
         v_mto_asiento  := round(v_mto_diferido);
         v_mto_diferido := 0;
      ELSE
         v_mto_asiento := round(v_mto_cuota);
      END IF;

      v_mto_asi_debito  := nvl(v_mto_asiento, 0) / nvl(v_cot_debito, 1);
      v_mto_asi_credito := nvl(v_mto_asiento, 0) / nvl(v_cot_credito, 1);
      --Igualar ultima cuota con el vencimiento
      IF v_cont >= v_cant_cuotas THEN
         IF v_fec_hasta <> v_fecha THEN
            v_fecha := v_fec_hasta;
         END IF;
         v_mto_asi_debito  := nvl(v_mto_rub_debito, 0) - nvl(v_mto_acu_debito, 0);
         v_mto_asi_credito := nvl(v_mto_rub_credito, 0) - nvl(v_mto_acu_credito, 0);
      ELSE
         v_mto_acu_debito  := nvl(v_mto_asi_debito, 0) + nvl(v_mto_acu_debito, 0);
         v_mto_acu_credito := nvl(v_mto_asi_credito, 0) + nvl(v_mto_acu_credito, 0);
      END IF;
      v_nro_asiento := fub_obt_sig_nro_asi_futuro(v_cod_oficina, v_fecha);

      INSERT INTO cb_asi_futuros
         (fecha, cod_oficina, nro_asiento, cod_usuario, cod_modulo, cod_modalidad, cod_cargo,
          tot_control)
      VALUES
         (v_fecha, v_cod_oficina, v_nro_asiento, USER, 2, 21, v_cod_cargo, (v_mto_asiento * 2));
      INSERT INTO cb_asi_futuros_det
         (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_local,
          descripcion, mto_mon_rubro, val_cotizacion)
      VALUES
         (v_fecha, v_cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rub_debito, 'D', v_mto_asiento,
          substr(v_descripcion, 1, 60),
          decode(v_mon_rub_debito, pag_gen.fu_obt_mon_local, NULL, v_mto_asi_debito),
          decode(v_mon_rub_debito, pag_gen.fu_obt_mon_local, NULL, v_cot_debito));
      INSERT INTO cb_asi_futuros_det
         (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_local,
          descripcion, mto_mon_rubro, val_cotizacion)
      VALUES
         (v_fecha, v_cod_oficina, v_nro_asiento, v_nro_linea + 1, v_cod_rub_credito, 'C',
          v_mto_asiento, substr(v_descripcion, 1, 60),
          decode(v_mon_rub_credito, pag_gen.fu_obt_mon_local, NULL, v_mto_asi_credito),
          decode(v_mon_rub_credito, pag_gen.fu_obt_mon_local, NULL, v_cot_credito));
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, SQLERRM);

   END;

   PROCEDURE lp_act_gas_diferidos(v_cod_cargo cb_gas_diferidos.cod_cargo%TYPE) IS
   BEGIN
      -- Actualizar gastos diferidos
      IF p_cod_cargo IS NULL THEN
         UPDATE cb_gas_diferidos
            SET cod_rub_credito = v_cod_rub_credito,
                monto           = v_mto_total,
                procesado       = 'S'
          WHERE cod_cargo = v_cod_cargo;
      ELSE
         UPDATE cb_gas_diferidos SET procesado = 'S' WHERE cod_cargo = v_cod_cargo;
      END IF;
   END;


BEGIN
   -----------------------
   -- PROCESO PRINCIPAL --
   -----------------------
   IF p_cod_cargo IS NULL THEN
      v_fec_actual := pag_cal.fu_obt_fec_actual(1);
   ELSE
      v_fec_actual := pag_cal.fu_obt_fec_actual(2);
   END IF;

   FOR i IN c_gas_diferidos LOOP
      v_val_total       := 0;
      v_cod_moneda      := NULL;
      v_mto_total       := 0;
      v_cod_rub_credito := NULL;
      v_mto_cuota       := 0;
      v_diferencia      := 0;
      v_mto_diferido    := 0;
      v_mto_asiento     := 0;

      v_periodicidad := nvl(i.periodicidad, fug_obt_pardinamico('PER_GAS_DIFERIDO'));
      IF nvl(v_periodicidad, 'M') = 'M' THEN
         IF i.fec_desde IS NOT NULL AND i.fec_hasta IS NOT NULL THEN
            v_fec_actual  := pag_cal.fu_obt_fec_ant_hab(last_day(v_fec_actual), NULL, 0);
            v_fec_desde   := pag_cal.fu_obt_fec_ant_hab(last_day(i.fec_desde), NULL, 0);
            v_fec_hasta   := pag_cal.fu_obt_fec_ant_hab(last_day(i.fec_hasta), NULL, 0);
            v_ult_dia_mes_ant := pag_cal.fu_obt_fec_ant_hab(last_day(add_months(v_fec_actual, -1)), null,0);


            BEGIN
              SELECT SUM(nvl(mto_mon_local, 0))
                INTO v_tot_dev_dia
                FROM cb_asi_futuros_det det, cb_asi_futuros fut
               WHERE det.fecha = fut.fecha
                 AND det.cod_oficina = fut.cod_oficina
                 AND det.nro_asiento = fut.nro_asiento
                 AND fut.nro_asi_real IS NOT NULL
                 AND det.tip_movimiento = 'D'
                 AND to_char(det.fecha,'mmyyyy') = to_char(v_fec_actual,'mmyyyy')
                 AND fut.cod_cargo = p_cod_cargo;
             EXCEPTION
                WHEN OTHERS THEN
                  v_tot_dev_dia := 0;
             END;


            lp_obt_dat_compras(i.cod_cargo, i.nro_orden, i.nro_linea, i.cod_transaccion, nvl(v_tot_dev_dia,0));

            if v_fec_futuro is not null and v_fec_futuro <> v_ult_dia_mes_ant then
            /* En caso de Re Calculo de Diario que pasa a Mensual, debe incluir el mes de devengado
               si no ese fin de mes para que calcule a fin de mes */
               v_cant_cuotas := fug_obt_dif_meses(v_fec_hasta, v_fec_futuro)/*+ 1*/;
            else
               v_cant_cuotas := fug_obt_dif_meses(v_fec_hasta, nvl(add_months(v_fec_futuro,1), v_fec_desde)) /*+ 1*/;
            end if;

            lp_obt_cotizacion(i.cod_rub_debito, v_cod_rub_credito);

            if nvl(v_tot_dev_dia, 0) > round(v_mto_cuota) then
               v_fec_actual  := pag_cal.fu_obt_fec_ant_hab(last_day(v_fec_actual+1), NULL, 0);
               lp_obt_dat_compras(i.cod_cargo, i.nro_orden, i.nro_linea, i.cod_transaccion, 0);
               v_cant_cuotas := fug_obt_dif_meses(v_fec_hasta, v_fec_actual);
               lp_obt_cotizacion(i.cod_rub_debito, v_cod_rub_credito);
            end if;

            v_cont            := 0;
            v_mto_acu_debito  := 0;
            v_mto_acu_credito := 0;
            LOOP
               v_cont      := v_cont + 1;
               v_nro_linea := 1;
               IF nvl(v_fec_futuro, i.fec_desde) > i.fec_desde THEN
                  IF v_fec_futuro is not null and v_cont = 1 then
                     v_fecha        := v_fec_actual;
                     v_mto_diferido := round(v_mto_cuota) - nvl(v_tot_dev_dia,0);
                     IF v_cont = v_cant_cuotas THEN
                        v_mto_cuota := round(v_mto_diferido);
                     END IF;

                  ELSE
                    /*SELECT add_months(nvl(v_fec_futuro, v_fec_desde),
                                      v_cont - 1 + decode(v_fec_futuro, NULL, 0, 1))
                      INTO v_fecha
                      FROM dual;*/
                      v_fecha := pag_cal.fu_obt_fec_ant_hab(last_day(add_months(v_fecha, 1)), NULL, 0);
                  END IF;

               ELSIF v_fec_actual > v_fec_desde THEN
                  /*
                  || Generar en la pantalla la primera cuota por un monto mayor,
                  || para el caso de devengamientos que inician con anterioridad a la fecha del comprobante.
                  */
                  IF v_cont = 1 THEN
                     v_fecha        := v_fec_actual;
                     v_cont         := fug_obt_dif_meses(v_fec_actual,  nvl(add_months(v_fec_futuro,1), v_fec_desde)) /*+ 1*/;
                     v_mto_diferido := round(v_mto_cuota) * abs(v_cont);
                     IF v_cont = v_cant_cuotas THEN
                        v_mto_cuota := round(v_mto_diferido);
                     END IF;
                  ELSE
                     v_fecha := pag_cal.fu_obt_fec_ant_hab(last_day(add_months(v_fecha, 1)), NULL, 0);
                  END IF;
               ELSE
                  v_fecha := pag_cal.fu_obt_fec_ant_hab(last_day(add_months(v_fec_desde, v_cont - 1)),
                                                        NULL, 0);
               END IF;

               SELECT pag_cal.fu_obt_fec_habil(v_fecha, -1, NULL) INTO v_ctrl_fec_habil FROM dual;
               IF v_fecha <> v_ctrl_fec_habil THEN
                  IF to_char(v_fecha, 'mm/yyyy') <> to_char(v_ctrl_fec_habil, 'mm/yyyy') THEN
                     SELECT pag_cal.fu_obt_fec_habil(v_fecha, +1, NULL)
                       INTO v_ctrl_fec_habil
                       FROM dual;
                  END IF;
                  v_fecha := v_ctrl_fec_habil;
               END IF;
               lp_ins_asi_futuros(i.cod_oficina, i.cod_cargo, i.cod_rub_debito, i.descripcion);
               EXIT WHEN v_cont >= v_cant_cuotas;
            END LOOP;
            lp_act_gas_diferidos(i.cod_cargo);
         END IF;
      ELSE
         /*CALCULO DE LOS DEVENGADOS DE GASTOS DIFERIDOS EN FORMA DIARIA*/
         IF i.fec_desde IS NOT NULL AND i.fec_hasta IS NOT NULL THEN
            BEGIN
               IF i.fec_hasta < v_fec_actual THEN
                  v_cant_cuotas := 1;
               ELSE
                  BEGIN
                     SELECT max(fecha) + 1
                       INTO v_fec_min_devengado
                       FROM cb_asi_futuros f
                      WHERE cod_cargo = p_cod_cargo
                        AND f.nro_asi_real is not null;
                  EXCEPTION
                     WHEN OTHERS THEN
                        v_fec_min_devengado := null;
                  END;

                  /*IF v_fec_min_devengado > i.fec_desde and v_fec_min_devengado < v_fec_actual THEN -- Para el caso de devengados
                     v_cant_cuotas := fuh_obt_dif_dias(v_fec_actual, i.fec_hasta);
                  ELSE*/

                  if pag_cal.fu_obt_fec_habil(i.fec_hasta, -1, NULL) <> i.fec_hasta then
                      v_cant_cuotas := fuh_obt_dif_dias(nvl(v_fec_min_devengado,i.fec_desde), i.fec_hasta);
                  else 
                      v_cant_cuotas := fuh_obt_dif_dias(nvl(v_fec_min_devengado,i.fec_desde), i.fec_hasta) + 1;
                  end if;
                  
               END IF;
            END;
            lp_obt_dat_compras(i.cod_cargo, i.nro_orden, i.nro_linea, i.cod_transaccion);
            lp_obt_cotizacion(i.cod_rub_debito, v_cod_rub_credito);
            v_cont            := 0;
            v_mto_acu_debito  := 0;
            v_mto_acu_credito := 0;
            LOOP
               v_cont      := v_cont + 1;
               v_nro_linea := 1;
               -- AAP - CONTROL DE FECHA HABIL PARA RECALCULOS
               IF nvl(v_fec_futuro, i.fec_desde) > i.fec_desde THEN
                    IF v_cont = 1 THEN
                       v_fecha := i.fec_desde;
                       if v_fec_actual > i.fec_desde then
                          v_cont := fuh_obt_dif_dias(v_fec_futuro, v_fec_actual);
                          v_mto_diferido := round(v_mto_cuota) * abs(v_cont);
                       end if;
                    ELSE
                       v_fecha := pag_cal.fu_obt_fec_sig_hab(v_fecha, NULL, 1);
                    END IF;
               ELSIF v_fec_actual > i.fec_desde THEN
                  /*
                  || Generar en la pantalla la primera cuota por un monto mayor,
                  || para el caso de devengamientos que inician con anterioridad a la fecha del comprobante.
                  || rabf - 14/dic/2010
                  */
                  IF v_cont = 1 THEN
                     v_fecha := v_fec_actual;
                     IF i.fec_hasta < v_fec_actual THEN
                        v_cont := 1;
                     ELSE
                        v_cont := fuh_obt_dif_dias(i.fec_desde, v_fec_actual) + 1;
                     END IF;
                     v_mto_diferido := round(v_mto_cuota) * abs(v_cont);
                  ELSE
                     v_fecha := pag_cal.fu_obt_fec_sig_hab(v_fecha, NULL, 1); --v_fecha + 1;
                  END IF;
               ELSE
                  IF v_cont = 1 THEN
                     v_fecha := i.fec_desde;
                  ELSE
                     v_fecha := pag_cal.fu_obt_fec_sig_hab(v_fecha, NULL, 1);
                  END IF;
               END IF;

               SELECT pag_cal.fu_obt_fec_habil(v_fecha, -1, NULL) INTO v_ctrl_fec_habil FROM dual;
               IF v_fecha <> v_ctrl_fec_habil THEN
                  SELECT pag_cal.fu_obt_fec_habil(v_fecha, +1, NULL)
                    INTO v_ctrl_fec_habil
                    FROM dual; -- rabf - 14/dic/2010
                  v_fecha := v_ctrl_fec_habil;
               END IF;

               IF v_fecha < pae_cnf.fu_obt_fec_actual(2) THEN
                  v_fecha := pae_cnf.fu_obt_fec_actual(2);
               END IF;

               --Igualar ultima cuota con el vencimiento
               IF v_cont > v_cant_cuotas THEN
                  IF i.fec_hasta < v_fecha THEN
                     v_fecha := i.fec_hasta;
                  END IF;
               END IF;
               lp_ins_asi_futuros(i.cod_oficina, i.cod_cargo, i.cod_rub_debito, i.descripcion);
               EXIT WHEN v_cont >= v_cant_cuotas;
            END LOOP;
            lp_act_gas_diferidos(i.cod_cargo);
         END IF;
      END IF;

   END LOOP;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Gen.Asi.Futuros:' || SQLERRM);
END;
/

