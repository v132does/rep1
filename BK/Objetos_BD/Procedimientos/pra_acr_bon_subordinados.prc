CREATE OR REPLACE PROCEDURE IT.PRA_ACR_BON_SUBORDINADOS IS
   /*
   || Fondeo de Cuentas para la modalidad 36/Bonos Subordinados,
   || RABF - 12/ene/2012
   */
   -- Definicion de cursor donde se encuentran los datos remitidos por la Casa de Bolsa
   v_fec_actual DATE := pag_cal.fu_obt_fec_actual(3);
   v_cod_empresa ge_entes.cod_ente%TYPE;
   ---
   CURSOR c_bonos IS
      SELECT a.cod_modulo,
             a.cod_modalidad,
             a.cod_oficina,
             a.nro_cuenta,
             a.cod_moneda,
             a.fec_apertura,
             a.capital,
             a.fec_vencimiento,
             a.cod_tasa,
             a.tas_personalizada,
             a.fec_ult_capitalizacion,
             d.monto,
             d.mto_int_acumulado,
             d.cod_tra_alta,
             d.cod_tra_ganancia,
             d.concepto
        FROM ah_cta_certificados a, ah_titulos t, ah_dev_bon_subordinados d
       WHERE a.estado = 'A'
         AND trunc(a.fec_apertura) +
             fug_obt_parentes(v_cod_empresa, 'DIAS_FONDEO_' || a.cod_moneda) <= v_fec_actual -- RABP-CNF-06/10/2014: se modifica para que tome las fechas menor o igual a la actual
         AND a.ser_titulo = t.serie
         AND a.nro_titulo = t.nro_titulo
         AND t.ser_origen = 'SEN'
         AND a.nro_cuenta = d.nro_cuenta(+);
   ---
   v_nro_cta_deb         ge_cuentas.nro_cuenta%TYPE;
   v_procesa             VARCHAR2(1) := 'N';
   v_hora                ge_movimientos.hora%TYPE := to_char(SYSDATE, 'hh24:mi:ss');
   v_cod_mon_local       ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
   v_cod_mon_fuerte      ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_fuerte;
   v_est_modulo          ba_modulos.estado%TYPE;
   v_nro_secuencia ge_movimientos.nro_secuencia%TYPE := 0;
   v_sal_disponible      NUMBER;
   v_nvo_estado          ah_cta_vistas.estado%TYPE;
   r_gmovi               ge_movimientos%ROWTYPE;
BEGIN
   SELECT estado INTO v_est_modulo FROM ba_modulos WHERE cod_modulo = 3;
   IF v_est_modulo != 2 THEN
      raise_application_error(-20000,
                              'Sistema esta cerrado, no se permiten hacer aperturas ni modificaciones');
   END IF;
   BEGIN
      SELECT cod_ente INTO v_cod_empresa FROM ge_entes WHERE tipo = 'BO';
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000, 'Sin datos para el ente de Bonos');
      WHEN too_many_rows THEN
         raise_application_error(-20000, 'Mas de un ente para Bonos');
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Error Obt.Ente p/Bonos:' || SQLERRM);
   END;
   ---
   FOR i IN c_bonos LOOP
      v_procesa := 'N';
      ---
      --- Verifica si puede debitarse de la cuenta del Ente
      ---
      IF i.cod_moneda = v_cod_mon_local THEN
         v_nro_cta_deb := fug_obt_parentes(v_cod_empresa, 'CTA_CRE_BONOS_GS');
      ELSIF i.cod_moneda = v_cod_mon_fuerte THEN
         v_nro_cta_deb := fug_obt_parentes(v_cod_empresa, 'CTA_CRE_BONOS_USD');
      ELSE
         raise_application_error(-20000, 'Moneda no definida');
      END IF;
      --IF v_nro_secuencia > 990 THEN
         v_hora                := pag_gen.fu_obt_sig_segundo(v_hora);
         /*v_nro_secuencia := -999;
      END IF;*/
      pag_cta.pr_obt_cuenta(v_nro_cta_deb);
      pag_cta.pr_ver_operacion(v_nro_cta_deb, 3631, 3 /*modulo de la cuenta de debito*/, 36
                               /*modulo de la cuenta de debito*/, 'D', i.cod_moneda
                               /*moneda de la cuenta de debito*/, i.capital,
                               fug_obt_ofi_usuario(USER),
                               /*Variables out*/ pag_cta.g_ctas.cod_modulo,
                               pag_cta.g_ctas.cod_modalidad, v_nvo_estado, v_sal_disponible,
                               v_procesa);
      IF pag_cta.g_cod_error <> 0 OR v_procesa = 'N' THEN
         raise_application_error(-20000,
                                 'Error Ver.Cta.Debito ' || v_nro_cta_deb || '-' ||
                                  pag_cta.g_msj_error);
      END IF;
      IF v_procesa = 'S' THEN
         --- DEBITAR de la cuenta
         v_nro_secuencia := v_nro_secuencia + 1;

         IF v_nro_secuencia > 990 THEN
            v_hora                := pag_gen.fu_obt_sig_segundo(v_hora);
            v_nro_secuencia := -999;
         END IF;
         pag_cta.pr_act_operacion(v_nro_cta_deb, v_hora, 'D', i.cod_moneda, i.capital, 3631, 503,
                                  i.nro_cuenta, NULL /*cotización*/, i.cod_oficina, 3, 36, NULL,
                                  NULL, 'Debito Cuenta Nro.Operacion:' || i.nro_cuenta, 'S',
                                  v_nro_secuencia, v_fec_actual, NULL, NULL, i.capital);
         IF pag_cta.g_cod_error <> 0 THEN
            raise_application_error(-20000,
                                    'Error Act.Operación.Cta.Debito ' || v_nro_cta_deb || '-' ||
                                     pag_cta.g_msj_error);
         END IF;
      END IF;
      /*********************************
      || Acredita en la cuenta del Bono
      *********************************/
      /*
      || Actualizar la fecha de Apertura
      || El pag_cta controla la fecha de fin de retención del depósito
      || Por lo que inicialmente se actualiza a la fecha actual
      */
      UPDATE ah_cta_certificados SET fec_apertura = v_fec_actual WHERE nro_cuenta = i.nro_cuenta;
      ---
      pag_cta.pr_set_nro_documento3(v_cod_empresa);
      pag_cta.pr_act_operacion(i.nro_cuenta, v_hora, 'C', i.cod_moneda /*moneda del corte*/,
                               i.capital, 3631, 602, i.nro_cuenta, NULL, i.cod_oficina
                               /*oficina del usuario*/, 3, 36, NULL, NULL,
                               'Crédito automatico de Cuenta ', 'S', v_nro_secuencia,
                               v_fec_actual);
      IF pag_cta.g_cod_error <> 0 THEN
         raise_application_error(-20000,
                                 'Error Act.Operación.Cta.Crédito ' || i.nro_cuenta || '-' ||
                                  pag_cta.g_msj_error);
      END IF;
      -- Actualizar nuevamente a la fecha de inicio de la serie
      UPDATE ah_cta_certificados SET fec_apertura = i.fec_apertura WHERE nro_cuenta = i.nro_cuenta;
      -------------------------------------------------------
      -- Movimiento correspondiente a la Plusvalía/Minusvalía
      -------------------------------------------------------
      IF nvl(i.monto, 0) > 0 THEN
         --- Verifica si la transacción es de Plusvalía para debitar del Ente
         IF i.cod_tra_alta = fug_obt_parentes(v_cod_empresa, 'COD_TRA_PLUSVALIA_BONOS') THEN
            --- Verifica si puede debitarse de la cuenta del Ente
            pag_cta.pr_ver_operacion(v_nro_cta_deb, 3631, 3 /*modulo de la cuenta de debito*/, 36
                                     /*modulo de la cuenta de debito*/, 'D', i.cod_moneda
                                     /*moneda de la cuenta de debito*/, nvl(i.monto, 0),
                                     fug_obt_ofi_usuario(USER),
                                     /*Variables out*/ pag_cta.g_ctas.cod_modulo,
                                     pag_cta.g_ctas.cod_modalidad, v_nvo_estado, v_sal_disponible,
                                     v_procesa);
            IF pag_cta.g_cod_error <> 0 OR v_procesa = 'N' THEN
               raise_application_error(-20000,
                                       'Error Ver.Cta.Debito ' || v_nro_cta_deb || '-' ||
                                        pag_cta.g_msj_error);
            END IF;
            IF v_procesa = 'S' THEN
               --- DEBITAR de la cuenta
               v_nro_secuencia := v_nro_secuencia + 1;
               IF v_nro_secuencia > 990 THEN
                  v_hora                := pag_gen.fu_obt_sig_segundo(v_hora);
                  v_nro_secuencia := -999;
               END IF;
               pag_cta.pr_act_operacion(v_nro_cta_deb, v_hora, 'D', i.cod_moneda, nvl(i.monto, 0), 3631,
                                        503, i.nro_cuenta, NULL /*cotización*/, i.cod_oficina, 3, 36,
                                        NULL, NULL, 'Debito Cuenta Nro.Operacion:' || i.nro_cuenta,
                                        'S', v_nro_secuencia, v_fec_actual, NULL, NULL,
                                        nvl(i.monto, 0));
               IF pag_cta.g_cod_error <> 0 THEN
                  raise_application_error(-20000,
                                          'Error Act.Operación.Cta.Debito ' || v_nro_cta_deb || '-' ||
                                           pag_cta.g_msj_error);
               END IF;
            END IF;
         ELSIF i.cod_tra_alta = fug_obt_parentes(v_cod_empresa, 'COD_TRA_MINUSVALIA_BONOS') THEN
            --- Es una Minusvalía y se tiene que acreditar al Ente
            IF v_nro_secuencia > 990 THEN
               v_hora                := pag_gen.fu_obt_sig_segundo(v_hora);
               v_nro_secuencia := -999;
            END IF;
            pag_cta.pr_set_nro_documento3(v_cod_empresa);
            pag_cta.pr_act_operacion(v_nro_cta_deb, v_hora, 'C', i.cod_moneda /*moneda del corte*/,
                                     nvl(i.monto, 0), 3631, 602, i.nro_cuenta, NULL,
                                     fug_obt_ofi_usuario(USER)
                                     /*oficina del usuario*/, 3, 36, NULL, NULL,
                                     'Crédito automatico de Cuenta ', 'S', v_nro_secuencia,
                                     v_fec_actual);
            IF pag_cta.g_cod_error <> 0 THEN
               raise_application_error(-20000,
                                       'Error Act.Operación.Cta.Crédito ' || v_nro_cta_deb || '-' ||
                                        pag_cta.g_msj_error);
            END IF;
         END IF;
            ---
         v_nro_secuencia := v_nro_secuencia + 1;
         ---
         r_gmovi.cod_usuario       := USER;
         r_gmovi.hora              := v_hora;
         r_gmovi.nro_secuencia     := v_nro_secuencia;
         r_gmovi.cod_modulo        := 3;
         r_gmovi.cod_modalidad     := 36;
         r_gmovi.cod_oficina       := i.cod_oficina;
         r_gmovi.nro_cuenta        := NULL;
         r_gmovi.cod_moneda        := i.cod_moneda;
         r_gmovi.fecha             := v_fec_actual;
         r_gmovi.fec_valor         := v_fec_actual;
         r_gmovi.cod_tra_padre     := 3631;
         r_gmovi.cod_transaccion   := i.cod_tra_alta;
         r_gmovi.nro_documento     := i.nro_cuenta;
         r_gmovi.nro_documento3    := NULL;
         r_gmovi.monto             := nvl(i.monto, 0);
         r_gmovi.estado            := 'N';
         r_gmovi.cod_ofi_origen    := i.cod_oficina;
         r_gmovi.concepto          := i.concepto;
         r_gmovi.reversado         := 'N';
         r_gmovi.emi_aviso         := 'N';
         r_gmovi.protegido         := 'N';
         r_gmovi.cod_mod_padre     := 3;
         r_gmovi.cod_mad_padre     := 36;
         r_gmovi.tip_mov_rubro     := NULL;
         r_gmovi.cod_rubro         := NULL;
         r_gmovi.fec_fin_retencion := NULL;
         r_gmovi.referencia        := i.nro_cuenta;
         pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
      END IF;
      ---------------------------------------------
      --- Movimiento por el Monto de Ganancia por Plusvalia
      -----------------------------------------------
      IF nvl(i.mto_int_acumulado, 0) > 0 THEN
         --- Verifica si puede debitarse de la cuenta del Ente
         pag_cta.pr_ver_operacion(v_nro_cta_deb, 3631, 3 /*modulo de la cuenta de debito*/, 36
                                  /*modulo de la cuenta de debito*/, 'D', i.cod_moneda
                                  /*moneda de la cuenta de debito*/, nvl(i.mto_int_acumulado, 0),
                                  fug_obt_ofi_usuario(USER),
                                  /*Variables out*/ pag_cta.g_ctas.cod_modulo,
                                  pag_cta.g_ctas.cod_modalidad, v_nvo_estado, v_sal_disponible,
                                  v_procesa);
         IF pag_cta.g_cod_error <> 0 OR v_procesa = 'N' THEN
            raise_application_error(-20000,
                                    'Error Ver.Cta.Debito ' || v_nro_cta_deb || '-' ||
                                     pag_cta.g_msj_error);
         END IF;
         IF v_procesa = 'S' THEN
            --- DEBITAR de la cuenta
            v_nro_secuencia := v_nro_secuencia + 1;

            IF v_nro_secuencia > 990 THEN
               v_hora                := pag_gen.fu_obt_sig_segundo(v_hora);
               v_nro_secuencia := -999;
            END IF;
            pag_cta.pr_act_operacion(v_nro_cta_deb, v_hora, 'D', i.cod_moneda,
                                     nvl(i.mto_int_acumulado, 0), 3631, 503, i.nro_cuenta, NULL
                                     /*cotización*/, i.cod_oficina, 3, 36, NULL, NULL,
                                     'Debito Cuenta Nro.Operacion:' || i.nro_cuenta, 'S',
                                     v_nro_secuencia, v_fec_actual, NULL, NULL, i.capital);
            IF pag_cta.g_cod_error <> 0 THEN
               raise_application_error(-20000,
                                       'Error Act.Operación.Cta.Debito ' || v_nro_cta_deb || '-' ||
                                        pag_cta.g_msj_error);
            END IF;
         END IF;
         ---
         v_nro_secuencia := v_nro_secuencia + 1;
         ---
         r_gmovi.cod_usuario       := USER;
         r_gmovi.hora              := v_hora;
         r_gmovi.nro_secuencia     := v_nro_secuencia;
         r_gmovi.cod_modulo        := 3;
         r_gmovi.cod_modalidad     := 36;
         r_gmovi.cod_oficina       := i.cod_oficina;
         r_gmovi.nro_cuenta        := NULL;
         r_gmovi.cod_moneda        := i.cod_moneda;
         r_gmovi.fecha             := v_fec_actual;
         r_gmovi.fec_valor         := v_fec_actual;
         r_gmovi.cod_tra_padre     := 3631;
         r_gmovi.cod_transaccion   := i.cod_tra_ganancia;
         r_gmovi.nro_documento     := i.nro_cuenta;
         r_gmovi.nro_documento3    := NULL;
         r_gmovi.monto             := nvl(i.mto_int_acumulado, 0);
         r_gmovi.estado            := 'N';
         r_gmovi.cod_ofi_origen    := fug_obt_ofi_usuario(USER);
         r_gmovi.concepto          := 'INTERES DEV.ACUMULADO ' || i.nro_cuenta;
         r_gmovi.reversado         := 'N';
         r_gmovi.emi_aviso         := 'N';
         r_gmovi.protegido         := 'N';
         r_gmovi.cod_mod_padre     := 3;
         r_gmovi.cod_mad_padre     := 36;
         r_gmovi.tip_mov_rubro     := NULL;
         r_gmovi.cod_rubro         := NULL;
         r_gmovi.fec_fin_retencion := NULL;
         r_gmovi.referencia        := i.nro_cuenta;
         pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
      END IF;

   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error General: PRA_GEN_BON_SUBORDINADOS: ' || SQLERRM);
END;
/

