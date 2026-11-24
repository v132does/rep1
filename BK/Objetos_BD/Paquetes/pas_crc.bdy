CREATE OR REPLACE PACKAGE BODY IT.PAS_CRC IS

   v_fec_actual     DATE;
   v_cod_mon_local  ba_monedas.cod_moneda%TYPE;
   v_cod_mon_fuerte ba_monedas.cod_moneda%TYPE;
   v_cot_fuerte     ge_cotizaciones.val_venta%TYPE;
   v_cat            ge_clientes.cat_automatica%TYPE;
   -- Variables utilizadas en el proceso de operaciones vencidas.
   v_error         NUMBER;
   v_cobrado       NUMBER(18, 2);
   v_tot_capital   NUMBER(18, 2);
   v_tot_mora      NUMBER(18, 2);
   v_tot_punitorio NUMBER(18, 2);
   v_tot_impuesto  NUMBER(18, 2);
   v_tot_cargo     NUMBER(18, 2);
   v_tot_car_iva   NUMBER(18, 2);
   v_dia_mora      NUMBER(18, 2);
   v_mensaje       VARCHAR2(500);
   v_cod_tra_padre ge_transacciones.cod_transaccion%TYPE;
   v_can_ano_incobrable NUMBER(2) := fug_obt_pardinamico('CAN_ANO_CRC_INCOBRABLES'); -- AP 2875

   /* Genera las tablas para los archivos de la Central de Riesgos. */
   PROCEDURE pr_gen_tab_crc IS

      /* Generar tabla temporal para el procesamiento CRC. */
      PROCEDURE lp_gen_tmp_crc;
      --OJO VER LAS PARTES DE TARJETA XQ ESTABA FUERA DEL CURSOR Y CONTABA PARA VER SI HABIA
      --Y DESPUES GENERABA UNO EN EL LOOP Y LUEGO AFUERA X PERSONA
      --OJO REVISAR XQ CAPAZ SEA X EL TEMA DE SOBREGIROS Y GARANTIAS
      ------------------------------------------------------------
      v_persona    VARCHAR2(10);
      v_nro_cuenta VARCHAR2(20);
      v_modulo     NUMBER(03);
      v_modalidad  NUMBER(03);
      v_oficina    NUMBER(03);
      v_tarjeta    NUMBER(03);
      v_contar     NUMBER(10);
      v_error      VARCHAR2(1000);
      --WW_COMERCI NUMBER(03);
      ----------------------------
      -- CURSOR DEL MAESTRO DE CLIENTES --trae las cuentas de los clientes
      --ojo:solamente las activas
      CURSOR clien IS
         SELECT a.cod_persona, a.nro_cuenta, a.cod_modulo, a.cod_modalidad, a.cod_oficina
           FROM sb_tmp_crc p, ge_cta_clientes a, ge_cuentas c, ge_est_cuentas d, sb_per_crc sb
          WHERE c.nro_cuenta = a.nro_cuenta
            AND a.relacion = 'P'
            AND a.cod_modulo = p.cod_modulo
            AND a.cod_persona = p.cod_persona
            AND c.cod_modulo IN (4, 5, 6, 8, 15, 10)
            AND ((c.cod_modulo = 4 AND c.cod_modalidad <> 43) OR c.cod_modulo <> 4)
            AND d.cod_modulo = c.cod_modulo
            AND d.cod_modalidad = c.cod_modalidad
            AND d.estado = c.estado
            AND nvl(fup_obt_tip_letra(c.cod_modalidad), 'N') = 'N' --- No incluir letras
            AND d.activo = 'S' --solo las de estado activo
            AND a.cod_persona = sb.cod_persona
            AND a.cod_persona NOT IN ('89603', '441935') --No se informa el cliente BCP.
            /*AND EXISTS
          (SELECT 1 FROM personas_ref pr WHERE pr.rf_numero = sb.nro_documento)*/
         UNION
         -- Saldos de bancos
         SELECT ba.cod_persona, a.nro_cuenta, a.cod_modulo, a.cod_modalidad, a.cod_oficina
           FROM cc_cta_bancarias a, ge_bancos ba, ge_est_cuentas d
          WHERE ba.cod_banco = a.cod_banco
            AND d.cod_modulo = a.cod_modulo
            AND d.cod_modalidad = a.cod_modalidad
            AND d.estado = a.estado
            AND nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) > 0
            AND ba.cod_persona <> 0
            AND d.activo = 'S'; -- Solo las de estado activo

      /* Generar tabla temporal para el procesamiento CRC. */
      PROCEDURE lp_gen_tmp_crc IS
      BEGIN
         --POBLAR LA TEMPORAL CON LAS PERSONAS Q TIENEN PRESTAMOS/SOBREGIROS/TARJETAS
         -------------------------------------
         -- INSERTA MOVIMIENTOS DE PRESTAMOS --
         --------------------------------------
         INSERT INTO sb_tmp_crc --cliente,modulo,saldo
            SELECT cod_persona, 6, SUM(nvl(sal_cap_batch, 0) + nvl(sal_int_ade_batch, 0))
              FROM ge_cta_clientes b, pr_cta_prestamos a
             WHERE a.nro_cuenta = b.nro_cuenta
               AND relacion     = 'P'
               AND nvl(sal_cap_batch, 0) + nvl(sal_int_ade_batch, 0) > 0
               --> AP 2875
               AND est_batch NOT IN ('N', 'X')-- Se borró el estado 'I' para que sean incluidos los incobrables
               AND((a.estado = 'I' AND (SELECT(months_between(v_fec_actual, n.fecha)/12)
                                          FROM ge_cuentas_nov n
                                         WHERE a.nro_cuenta = n.nro_cuenta
                                           AND n.est_actual = 'I'
                                           AND n.fecha = (SELECT min(c.fecha)
                                                            FROM ge_cuentas_nov c
                                                           WHERE c.nro_cuenta = a.nro_cuenta
                                                             AND c.est_actual = 'I')
                                        ) <= v_can_ano_incobrable) OR
                   a.estado <> 'I')
             --<
            GROUP BY cod_persona; --EL SALDO TOTAL X LA PERSONA
         -------------------------------------------------------------
         -- INSERTA MOVIMIENTOS DE SOBREGIROS EN CUENTAS CORRIENTES --
         -------------------------------------------------------------
         INSERT INTO sb_tmp_crc --cliente,modulo,saldo
            SELECT cod_persona, 4, SUM(nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)) * -1
              FROM ge_cta_clientes b, cc_cta_corrientes a
             WHERE (nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0) < 0
                   OR --- OR agregado por ICL para traer Ctas.Ctes. positivos de Nómina
                   exists(select 1 from ge_cla_operaciones p  -- Solo informa los que tienen deuda contingente
                           where p.nro_cuenta=a.nro_cuenta
                             and nvl(p.tot_deu_contingente,0) <> 0))
               AND a.nro_cuenta = b.nro_cuenta
               AND relacion = 'P'
               AND est_batch NOT IN ('A','C', 'X')
             GROUP BY cod_persona; --EL SALDO TOTAL X LA PERSONA
         -------------------------------------------------------------
         -- INSERTA MOVIMIENTOS DE CUENTAS BANCARIAS
         -------------------------------------------------------------
         INSERT INTO sb_tmp_crc --cliente,modulo,saldo
            SELECT cod_persona, 4, SUM(nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0)) * -1
              FROM ge_cta_clientes b, cc_cta_bancarias a
             WHERE nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) > 0
               AND a.nro_cuenta = b.nro_cuenta
               AND relacion = 'P'
               AND est_batch NOT IN ('C', 'X')
               AND a.cod_modalidad = 45
             GROUP BY cod_persona; --EL SALDO TOTAL X LA PERSONA
         --
         --INSERTA MOVIMIENTOS DE TARJETAS DE CREDITO--
         ----------------------------------------------
         -- Modificado según documentación de control de cambios del AP 1939 a pedido de Clara Garcia.
         INSERT INTO sb_tmp_crc --cliente,modulo,saldo
            SELECT cod_persona, 5, SUM(nvl(a.sal_procesadora, 0))
              FROM ge_cta_clientes b, ta_cta_tarjetas a, ta_cta_tarjetas_tmp tam
             WHERE a.nro_cuenta = b.nro_cuenta
               AND to_number(a.nro_cuenta) = tam.nro_cuenta
               AND relacion = 'P'
               AND a.cod_modalidad != 55
               AND ((tam.sit_cuenta = 3 AND nvl(a.sal_procesadora, 0) != 0) OR tam.sit_cuenta != 3)
               and ((a.estado not in ('C', 'B')) or (a.estado='B' and nvl(a.sal_procesadora, 0) > 0)) -- ICL 09/04/12 Mail HB: Unificar Tarjetas Bloqueadas con R1
             GROUP BY cod_persona; --EL SALDO TOTAL X LA PERSONA
         --------------------------------------------------------------
         -- INSERTA MOVIMIENTOS DE CUENTAS VENCIDAS -------------------
         --------------------------------------------------------------
         INSERT INTO sb_tmp_crc
            SELECT cod_persona, 15, SUM(nvl(sal_tot_batch, 0))
              FROM ge_cta_clientes b, ov_cta_vencidas a
             WHERE b.nro_cuenta = a.nro_cuenta
               AND b.relacion = 'P'
               --> AP 2875
               AND a.estado NOT IN ('C') --Se borró el estado 'I' para que sean incluidos los Incobrables
               AND((a.estado = 'I' AND (SELECT(months_between(v_fec_actual, n.fecha)/12)
                                          FROM ge_cuentas_nov n
                                         WHERE a.nro_cuenta = n.nro_cuenta
                                           AND n.est_actual = 'I'
                                           AND n.fecha = (SELECT min(c.fecha)
                                                            FROM ge_cuentas_nov c
                                                           WHERE c.nro_cuenta = a.nro_cuenta
                                                             AND c.est_actual = 'I')
                                        ) <= v_can_ano_incobrable) OR
                   a.estado <> 'I')
               --<
               AND nvl(sal_tot_batch, 0) > 0
             GROUP BY cod_persona; --EL SALDO TOTAL X LA PERSONA

         --------------------------------------------------------------
         -- INSERTA MOVIMIENTOS DE CARTAS DE IMPORTACION --------------
         --------------------------------------------------------------
         INSERT INTO sb_tmp_crc
            SELECT cod_persona, 8, SUM(nvl(a.saldo, 0))
              FROM ge_cta_clientes b, cx_cta_importaciones a
             WHERE a.estado NOT IN ('C', 'S') --Cancelada y Solicitada
               AND b.nro_cuenta = a.nro_cuenta
               AND b.relacion = 'P'
               AND nvl(a.saldo, 0) > 0
             GROUP BY cod_persona; --EL SALDO TOTAL X LA PERSONA

         --------------------------------------------------------------
         -- INSERTA MOVIMIENTOS DE FIANZAS/AVALES ---------------------
         --------------------------------------------------------------
         INSERT INTO sb_tmp_crc
            SELECT cod_persona, 8, SUM(nvl(a.monto, 0))
              FROM ge_cta_clientes b, cx_fianzas a
             WHERE a.estado NOT IN ('C', 'S') --Cancelado y Solicitados.
               AND b.nro_cuenta = a.nro_cuenta
               AND b.relacion = 'P'
               AND nvl(a.monto, 0) > 0
             GROUP BY cod_persona; --EL SALDO TOTAL X LA PERSONA

         --------------------------------------------------------------
         -- INSERTA MOVIMIENTOS DE MESA DE DINERO ---------------------
         --------------------------------------------------------------
         INSERT INTO sb_tmp_crc
            SELECT a.cod_persona, 10, SUM(nvl(a.sal_capital, 0))
              FROM ge_cta_clientes b, md_cta_documentos a
             WHERE a.estado = 'C' --C Vigente--
               AND b.nro_cuenta = a.nro_cuenta
               AND b.relacion = 'P'
               AND a.cod_modalidad IN (104, 124, 142, 125,110,116,146) -- ICL 22/03/12 Mail HB: Incluir Call Money, Sacar prestamos recibidos porque es un pasivo
             GROUP BY a.cod_persona; --EL SALDO TOTAL X LA PERSONA
      END;
   BEGIN
      pag_cal.pr_obt_dat_calendar(6);
      v_fec_actual         := pag_cal.g_ult_dia_mes;
      v_tip_implementacion := fug_obt_tip_implementacion;
      v_error              := NULL;
      sql_util.ejecute_dml('TRUNCATE TABLE SB_TMP_CRC', v_error);
      IF v_error IS NOT NULL THEN
         raise_application_error(-20000, v_error);
      END IF;
      DELETE sb_personas_crc WHERE fecha = v_fec_actual;
      DELETE sb_personas_crc_det WHERE fecha = v_fec_actual;
      DELETE sb_vinculos WHERE fecha = v_fec_actual;
      DELETE sb_vinculos_det WHERE fecha = v_fec_actual;
      DELETE sb_items WHERE fecha = v_fec_actual;
      DELETE sb_items_det WHERE fecha = v_fec_actual;
      DELETE sb_consumos WHERE fecha = v_fec_actual;
      DELETE sb_consumos_det WHERE fecha = v_fec_actual;
      COMMIT;
      --- Recuperar moneda local y fuerte
      v_cod_mon_local  := pag_gen.fu_obt_mon_local;
      v_cod_mon_fuerte := pag_gen.fu_obt_mon_fuerte;
      v_cot_fuerte     := pag_gen.fu_obt_cotizacion(v_cod_mon_fuerte, v_fec_actual);
      --inserta tmp para poder procesar
      lp_gen_tmp_crc;
      COMMIT;
      pr_obt_pr_param;
      IF clien%ISOPEN THEN
         CLOSE clien;
      END IF;

      OPEN clien;
      LOOP
         FETCH clien
            INTO v_persona, v_nro_cuenta, v_modulo, v_modalidad, v_oficina;
         EXIT WHEN clien%NOTFOUND;
         IF clien%FOUND THEN
            --SI HAY CLIENTES
            v_contar := nvl(v_contar, 0) + 1;
            IF v_modulo = 4 THEN
               IF v_modalidad = 41 THEN
                  -- CUENTAS CORRIENTES
                  pr_gen_ctacte_crc(v_modulo, v_modalidad, v_oficina, v_nro_cuenta, v_persona);
               ELSE
                  --CUENTAS BANCARIAS
                  pr_gen_ctaban_crc(v_modulo, v_modalidad, v_oficina, v_nro_cuenta, v_persona);
               END IF;
            END IF;
            IF v_modulo = 6 THEN
               -- PRESTAMOS
               pr_gen_prest_crc(v_modulo, v_modalidad, v_oficina, v_nro_cuenta, v_persona);
            END IF;

            IF v_modulo = 5 THEN
               --TARJETAS DE CREDITO--
               pr_gen_tarj_crc(v_nro_cuenta, v_persona);
               v_tarjeta := 0; ---para no procesar fuera del ciclo
            END IF;

            IF v_modulo = 15 THEN
               --CUENTAS VENCIDAS--
               pr_gen_ope_ven_crc(v_modulo, v_modalidad, v_oficina, v_nro_cuenta, v_persona);
            END IF;

            IF v_modulo = 8 AND v_modalidad = 81 THEN
               --IMPORTACION COM. EXTERIOR--
               pr_gen_importac_crc(v_modulo, v_modalidad, v_oficina, v_nro_cuenta, v_persona);
            END IF;

            IF v_modulo = 8 AND v_modalidad = 88 THEN
               --FIANZAS/AVALES COM.EXTERIOR--
               pr_gen_fianzas_crc(v_modulo, v_modalidad, v_oficina, v_nro_cuenta, v_persona);
            END IF;

            IF v_modulo = 10 AND v_modalidad IN (104, 118, 124, 142, 125) THEN
               --MESA DE DINERO--
               pr_gen_mes_dinero_crc(v_modulo, v_modalidad, v_oficina, v_nro_cuenta, v_persona);
            END IF;

            --- Grabar cada tanto para verificar que procese
            IF MOD(v_contar, 500) = 0 THEN
               COMMIT;
            END IF;
         END IF;
      END LOOP;
      v_contar := 0;
      CLOSE clien;
      --VERIFICAR SI SE INSERTARON DETALLES E INSERTAR LAS CABECERAS CORRESPONDIENTES
      pr_ins_cabecera_crc;
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Error en ' || SQLERRM);
   END;
   PROCEDURE pr_obt_pr_param IS
   BEGIN
      SELECT * INTO rv_param FROM pr_parametros;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Recup. Parametros ' || SQLERRM);
   END;
   PROCEDURE pr_gen_ctacte_crc
   (
      p_modulo      IN cc_cta_corrientes.cod_modulo%TYPE,
      p_modalidad   IN cc_cta_corrientes.cod_modalidad%TYPE,
      p_oficina     IN cc_cta_corrientes.cod_oficina%TYPE,
      p_nro_cuenta  IN cc_cta_corrientes.nro_cuenta%TYPE,
      p_cod_persona IN ge_cta_clientes.cod_persona%TYPE
   ) IS
      v_cod_moneda     VARCHAR2(03);
      v_departamento   NUMBER(03);
      v_plazo          NUMBER(04);
      v_sal_cap        NUMBER(15) := 0;
      v_sal_cap2        NUMBER(15) := 0; -- saldo capital sin ABS GAC 09/05/2012
      v_garan          NUMBER(15) := 0;
      v_fec_aper       DATE;
      v_tip_identif    VARCHAR2(03);
      v_nro_identif    VARCHAR2(15);
      v_mto_gar_cober  NUMBER(15);
      v_total_tc       NUMBER(15);
      v_total_dc       NUMBER(15);
      v_total_tr       NUMBER(15);
      v_total_dr       NUMBER(15);
      v_total_er       NUMBER(15);
      v_total_sr       NUMBER(15);
      v_tot_ctr_cred   NUMBER(15);
      v_tot_ctr_ries   NUMBER(15);
      v_actividad      NUMBER(3);
      v_item           VARCHAR2(3);
      v_dias_sobregiro NUMBER(5);
      v_mto_prevision  ge_cla_operaciones.tot_prevision%TYPE := 0;
      v_lineas           NUMBER(15) := 0; --- ICL 22/03/2012 Mail HB Contingente de Sobregiro
      v_mto_contingencia NUMBER(15) := 0;

   BEGIN
      SELECT a.cod_moneda,
             decode(nvl(cod_departamento, 0), 0, 11, cod_departamento),
             FUG_OBT_PLZ_CONTABLE(NVL(DIAS_SOBREGIRO,0))||0,
             nvl(dias_sobregiro,0),
             abs(nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)) *
             decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                    pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)),
             nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0) *
             decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                    pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)),
             fec_apertura,
             cod_actividad
        INTO v_cod_moneda,
             v_departamento,
             v_plazo,
             v_dias_sobregiro,
             v_sal_cap,
             v_sal_cap2,
             v_fec_aper,
             v_actividad
        FROM ge_clientes d,
             ba_personas e,
             ge_cta_clientes b,
             (SELECT can_dias dias_sobregiro, nro_cuenta FROM cc_sobregiros_res) f,
             cc_cta_corrientes a
       WHERE a.nro_cuenta = b.nro_cuenta
         AND a.nro_cuenta = p_nro_cuenta
         AND b.cod_persona = d.cod_persona
         AND d.cod_persona = p_cod_persona
         AND d.cod_persona = e.cod_persona
         AND a.est_batch NOT IN ('A','C', 'X')
         AND a.nro_cuenta = f.nro_cuenta(+)
         AND relacion = 'P'
         AND (nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0) < 0
           OR --- OR agregado por ICL para traer Ctas.Ctes. positivos de Nómina
           exists(select 1 from ge_cla_operaciones p  -- Solo informa los que tienen deuda contingente
                   where p.nro_cuenta=a.nro_cuenta
                     and nvl(p.tot_deu_contingente,0) <> 0));

      ------------------------------------------------------------------
      -- CALCULA EN MILES DE GUARANIES EL SALDO DE CUENTAS CORRIENTES --
      ------------------------------------------------------------------
      v_sal_cap := round(v_sal_cap, 0);
      v_garan   := 0;
      --- cargo las variables para act. o generar reg. en a_personas ---
      v_mto_gar_cober := v_garan;
      v_total_tc      := v_sal_cap;
      v_total_dc      := 0;
      v_total_tr      := v_sal_cap;
      v_total_dr      := 0;
      v_total_er      := 0;
      v_total_sr      := 0;
      v_cat           := NULL;
      -- totales de control --------------------------------------------
      v_tot_ctr_cred := nvl(v_total_tc, 0) + nvl(v_total_dc, 0);
      v_tot_ctr_ries := nvl(v_total_tr, 0) + nvl(v_total_dr, 0) + nvl(v_total_er, 0) +
                        nvl(v_total_sr, 0);
      --genero o actualizo registro en a_personas -------------------
      --mensaje_log('ctacte -> ins persona');

      if nvl(v_dias_sobregiro, 0) = 0 AND nvl(v_sal_cap2,0) >= 0 then -- ICL 09/04/2012 error en crc
        v_total_tc      := 0;
        v_total_dc      := 0;
        v_total_tr      := 0;
        v_total_dr      := 0;
        v_total_er      := 0;
        v_total_sr      := 0;
        v_tot_ctr_cred  := 0;
        v_tot_ctr_ries  := 0;
      end if;

      pr_ins_personas(p_cod_persona, v_mto_gar_cober, v_total_tc, v_total_dc, v_total_tr,
                      v_total_dr, v_total_er, v_total_sr, v_tot_ctr_cred, v_tot_ctr_ries,
                      v_tip_identif, v_nro_identif, v_cat);

      --genero el registro en c_item --------------------------------
      IF nvl(v_dias_sobregiro, 0) <= 60 THEN
         v_item := '110';
      ELSE
         v_item := '230';
      END IF;
      IF nvl(v_dias_sobregiro,0) <> 0 OR (nvl(v_dias_sobregiro,0) = 0 and nvl(v_sal_cap2,0) < 0) THEN -- ICL 22/03/2012 Mail HB: Para que no inserte deuda real para los que tienen saldo positivo
          --mensaje_log('ctacte -> ins item'); --GAC OR agregado para incluir los clientes con 0 dias de sobregiro y saldo negativo

          pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, p_oficina,
                      v_departamento, v_cod_moneda, v_actividad, v_sal_cap, v_sal_cap);
      END IF;
      --genera el 4to archivo: CONSUMOS
      IF (v_actividad = '701' AND v_item NOT IN ('440', '770', '780', '270', '280', '450')) THEN -- ICL 10/04/2012 Para que inserte el CD solo cuando es por deuda
         pr_ins_consumos(p_nro_cuenta, p_cod_persona, v_tip_identif, v_nro_identif);
      END IF;

      --- DESDE AQUI Agregado ICL 22/03/2012 Mail HB debe informar contingente de Cta.Cte.
      -- Agrego los datos de previsiones y contingencia
      BEGIN
         SELECT NVL(g.tot_prevision, 0), nvl(g.tot_deu_contingente,0)
           INTO v_mto_prevision, v_mto_contingencia
           FROM ge_cla_operaciones g
          WHERE g.nro_cuenta = p_nro_cuenta;
      EXCEPTION
         WHEN no_data_found THEN
            v_mto_prevision    := 0;
            v_mto_contingencia := 0;
      END;
      IF v_mto_contingencia <> 0 THEN
          v_total_tc := 0;
          v_total_dc := 0;
          v_total_dr := 0;
          v_total_sr := 0;
          v_total_er := v_mto_contingencia;
          v_total_tr := 0;
          --V_TOTAL_TR := V_MTO_CONTINGENCIA; RES-205/2006
          --V_TOTAL_ER := 0;
          --
          v_tot_ctr_cred := nvl(v_total_tc, 0) + nvl(v_total_dc, 0);
          v_tot_ctr_ries := nvl(v_total_tr, 0) + nvl(v_total_dr, 0) + nvl(v_total_er, 0) +
                            nvl(v_total_sr, 0);
          --genero o actualizo registro en a_personas -------------------
          -- La contingencia no actualiza personas -- Desde 205/2006
          pr_ins_personas(p_cod_persona, v_mto_gar_cober, v_total_tc, v_total_dc, v_total_tr,
                          v_total_dr, v_total_er, v_total_sr, v_tot_ctr_cred, v_tot_ctr_ries,
                          v_tip_identif, v_nro_identif);
          --genero el registro en c_item --------------------------------
          v_item := '780'; -- Contingencia
          IF v_mto_contingencia > 0 THEN
             pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, p_oficina,
                         v_departamento, v_cod_moneda, v_actividad, 0, v_mto_contingencia);
          END IF;
           IF (v_actividad = '701' AND v_item NOT IN ('440', '770', '780', '270', '280', '450'))
            AND nvl(v_dias_sobregiro,0) = 0 THEN -- ICL 10/04/2012 Para que inserte el CD solo cuando es por deuda
               pr_ins_consumos(p_nro_cuenta, p_cod_persona, v_tip_identif, v_nro_identif);
            END IF;
      END IF;
      --- HASTA AQUI ICL 22/03/2012


      -- Modificado según documentación de control de cambios del AP 1939 a pedido de Clara Garcia.
      --genera los codeudores de la cuenta --------------------------
      --mensaje_log('ctacte -> ins codeudor');
      IF fug_obt_pardinamico('CRC_FIR_SOBREGIROS') = 'S' THEN
         IF v_sal_cap <> 0 THEN
            --- Solo se genera si tiene deuda el deudor
            pr_gen_gar_codeu(p_nro_cuenta, p_cod_persona, v_garan, v_sal_cap, v_tip_identif,
                             v_nro_identif, v_plazo, p_oficina, v_departamento, v_cod_moneda);
         END IF;
      END IF;

      IF v_mto_prevision != 0 THEN
         v_item := '770';
         pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, p_oficina,
                     v_departamento, v_cod_moneda, v_actividad, v_mto_prevision, v_mto_prevision);
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         NULL; --PARA Q PROCESE LA SGTE
      --RAISE_APPLICATION_ERROR(-20000,'No existe CTA.CTE '||P_NRO_CUENTA);
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Gen. CTA.CTE ' || p_nro_cuenta || '-' || SQLERRM);
   END;
   PROCEDURE pr_gen_prest_crc
   (
      p_modulo         IN cc_cta_corrientes.cod_modulo%TYPE,
      p_modalidad      IN cc_cta_corrientes.cod_modalidad%TYPE,
      p_oficina        IN cc_cta_corrientes.cod_oficina%TYPE,
      p_nro_cuenta     IN cc_cta_corrientes.nro_cuenta%TYPE,
      p_cod_persona    IN ge_cta_clientes.cod_persona%TYPE
   ) IS
      v_cod_moneda     VARCHAR2(03);
      v_departamento   VARCHAR2(03);
      v_plazo          NUMBER(04);
      v_est_batch      VARCHAR2(01);
      v_tip_identif    VARCHAR2(03);
      v_nro_identif    VARCHAR2(15);
      v_tipo_vinculo   VARCHAR2(01);
      v_item           VARCHAR2(3);
      v_tip_descuento  VARCHAR2(1);
      v_actividad      NUMBER(3);
      v_sal_cap        NUMBER(15) := 0;
      v_garan          NUMBER(15) := 0;
      v_mto_gar_cober  NUMBER(15) := 0;
      v_tot_tc         NUMBER(15) := 0;
      v_tot_dc         NUMBER(15) := 0;
      v_tot_tr         NUMBER(15) := 0;
      v_tot_dr         NUMBER(15) := 0;
      v_tot_er         NUMBER(15) := 0;
      v_tot_sr         NUMBER(15) := 0;
      v_tot_ctr_cred   NUMBER(15) := 0;
      v_tot_ctr_ries   NUMBER(15) := 0;
      v_control        NUMBER(5) := 0;
      v_cod_modalidad  ge_modalidades.cod_modalidad%TYPE;
      v_tip_destino    pr_cta_prestamos.tip_destino%TYPE;
      v_mto_capital    pr_cta_prestamos.mto_capital%TYPE := 0;
      v_tip_prestamo   pr_cta_prestamos.tipo%TYPE;
      v_mto_prevision  ge_cla_operaciones.tot_prevision%TYPE;
      --- Datos de firmantes del documento del grupo economico de la entidad
      v_tip_identif2   VARCHAR2(03);
      v_nro_identif2   VARCHAR2(15);

      --- cursor para firmatentes del grupo economico --
      CURSOR firmantes IS
         SELECT DISTINCT per.cod_persona, doc.nro_referencia cuenta
           FROM pr_documentos doc, ba_personas per
          WHERE per.cod_persona <> p_cod_persona
            AND per.cod_tip_documento = doc.cod_tip_documento
            AND per.nro_documento = doc.nro_documento
            AND doc.nro_referencia = p_nro_cuenta
            AND doc.fec_vencimiento > v_fec_actual
            AND EXISTS (SELECT 0
                   FROM ge_gru_economicos g, ge_clientes c, ge_par_dinamicos d
                  WHERE c.cod_persona = per.cod_persona
                    AND c.cod_gru_economico = g.cod_gru_economico
                    AND d.parametro = 'COD_GRU_ECO_ENTIDAD'
                    AND d.val_parametro = c.cod_gru_economico)
         UNION
         SELECT DISTINCT per.cod_persona, nro_referencia cuenta
           FROM ge_che_custodias che, pr_rel_chq_lib rel, ba_personas per
          WHERE nro_referencia = p_nro_cuenta
            AND rel.cod_banco = che.cod_banco
            AND rel.nro_cheque = che.nro_cheque
            AND rel.cta_libradora = che.cta_libradora
            AND per.cod_persona <> p_cod_persona
            AND per.cod_tip_documento = rel.cod_tip_documento
            AND per.nro_documento = rel.nro_documento
            AND che.fec_vencimiento > v_fec_actual
            AND EXISTS (SELECT 0
                   FROM ge_gru_economicos g, ge_clientes c, ge_par_dinamicos d
                  WHERE c.cod_persona = per.cod_persona
                    AND c.cod_gru_economico = g.cod_gru_economico
                    AND d.parametro = 'COD_GRU_ECO_ENTIDAD'
                    AND d.val_parametro = c.cod_gru_economico);

   BEGIN
      SELECT a.cod_moneda,
             est_batch,
             decode(nvl(cod_departamento, 0), 0, 11, cod_departamento),
             FUG_OBT_PLZ_CONTABLE(NVL(a.dia_atraso,0))||0,
             decode(a.est_batch, 'I',
                    (nvl(a.sal_cap_batch, 0) + nvl(a.sal_int_batch, 0) + nvl(a.sal_int_ade_batch, 0)),
                    (nvl(sal_cap_batch, 0) + nvl(dev_no_cobrado, 0))) *
             decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                    pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)),
             ps.cod_bco_central,
             a.cod_modalidad,
             a.tip_destino,
             a.mto_capital,
             a.tipo
        INTO v_cod_moneda,
             v_est_batch,
             v_departamento,
             v_plazo,
             v_sal_cap,
             v_actividad,
             v_cod_modalidad,
             v_tip_destino,
             v_mto_capital,
             v_tip_prestamo
        FROM ge_clientes d, ge_cta_clientes b, pr_sec_creditos ps, pr_cta_prestamos a
       WHERE a.nro_cuenta = b.nro_cuenta
         AND a.nro_cuenta = p_nro_cuenta
         AND b.cod_persona = d.cod_persona
         AND b.cod_persona = p_cod_persona
         AND b.nro_cuenta = p_nro_cuenta
         AND d.cod_persona = p_cod_persona
         AND a.cod_sec_credito = ps.cod_sec_credito
         AND nvl(a.est_batch, 'N') NOT IN ('N', 'X')  -- AP 2875
         AND decode(a.est_batch, 'I',
                    (nvl(a.sal_cap_batch, 0) + nvl(a.sal_int_batch, 0) + nvl(a.sal_int_ade_batch, 0)),
                    (nvl(a.sal_cap_batch, 0) + nvl(a.dev_no_cobrado, 0))) *
             decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                    pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)) >= 0;

      ---------------------------------------------------------
      -- CALCULA EN MILES DE GUARANIES EL SALDO DEL PRESTAMO --
      ---------------------------------------------------------
      v_sal_cap       := round(v_sal_cap, 0);
      v_tip_descuento := fup_obt_tip_descuento(v_cod_modalidad);
      ---------------------------------------------------------
      -- OBTIENE EL VALOR DE LA GARANTIA DEL PRESTAMO        --
      ---------------------------------------------------------
      SELECT SUM(nvl(a.mto_aplicado, 0) *
                 decode(c.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                        pag_gen.fu_obt_cotizacion(c.cod_moneda, v_fec_actual)))
        INTO v_garan
        FROM pr_garantias b, pr_cta_garantias a, pr_cta_prestamos c
       WHERE a.nro_garantia = b.nro_garantia
         AND a.nro_cuenta = p_nro_cuenta
         AND a.nro_cuenta = c.nro_cuenta
         AND c.nro_cuenta = p_nro_cuenta;
      -----------------------------------------------------------
      -- CALCULA EL VALOR DE LA GARANTIA EN MILES DE GUARANIES --
      -----------------------------------------------------------
      IF nvl(v_garan, 0) > 0 THEN
         v_garan := round(v_garan, 0);
      ELSE
         v_garan := 0;
      END IF;
      -- Cargo los datos para la generacion de a-personas -------------
      v_mto_gar_cober := v_garan;
      --
      IF v_tip_descuento IS NULL THEN
         v_tot_tc := v_sal_cap;
         v_tot_tr := v_sal_cap;
      ELSE
         --Es un descuento de documentos
         v_tot_dc := v_sal_cap;
         v_tot_dr := v_sal_cap;

         IF v_tip_implementacion <> 2 THEN
            --Verificar si la persona es el emisor del documento
            IF v_tip_descuento = 'D' THEN
               BEGIN
                  SELECT COUNT(*)
                    INTO v_control
                    FROM pr_documentos doc, ba_personas per
                   WHERE per.cod_persona != p_cod_persona
                     AND per.cod_tip_documento = doc.cod_tip_documento
                     AND per.nro_documento = doc.nro_documento
                     AND doc.nro_referencia = p_nro_cuenta
                     AND doc.fec_vencimiento > v_fec_actual
                     AND EXISTS (SELECT 0
                            FROM ge_gru_economicos g, ge_clientes c, ge_par_dinamicos d
                           WHERE c.cod_persona = per.cod_persona
                             AND c.cod_gru_economico = g.cod_gru_economico
                             AND d.parametro = 'COD_GRU_ECO_ENTIDAD'
                             AND d.val_parametro = c.cod_gru_economico);

               EXCEPTION
                  WHEN no_data_found THEN
                     v_control := 0;
               END;
            ELSIF v_tip_descuento = 'C' THEN
               BEGIN
                  SELECT COUNT(*)
                    INTO v_control
                    FROM ge_che_custodias che, pr_rel_chq_lib rel, ba_personas per
                   WHERE nro_referencia = p_nro_cuenta
                     AND rel.cod_banco = che.cod_banco
                     AND rel.nro_cheque = che.nro_cheque
                     AND rel.cta_libradora = che.cta_libradora
                     AND per.cod_persona != p_cod_persona
                     AND per.cod_tip_documento = rel.cod_tip_documento
                     AND per.nro_documento = rel.nro_documento
                     AND che.fec_vencimiento > v_fec_actual
                     AND EXISTS (SELECT 0
                            FROM ge_gru_economicos g, ge_clientes c, ge_par_dinamicos d
                           WHERE c.cod_persona = per.cod_persona
                             AND c.cod_gru_economico = g.cod_gru_economico
                             AND d.parametro = 'COD_GRU_ECO_ENTIDAD'
                             AND d.val_parametro = c.cod_gru_economico);
               EXCEPTION
                  WHEN no_data_found THEN
                     v_control := 0;
               END;
            END IF;
            IF v_control <> 0 THEN
               v_tot_sr := v_sal_cap; --- Se cambio en base a RES. 205/2006
            ELSE
               v_tot_sr := 0;
            END IF;
         END IF;
      END IF;
      v_tot_er := 0; --- No se manejan Lineas por GF RES 205/2006
      v_cat    := NULL;
      --
      v_tot_ctr_cred := nvl(v_tot_tc, 0) + nvl(v_tot_dc, 0);
      v_tot_ctr_ries := nvl(v_tot_tr, 0) + nvl(v_tot_dr, 0) + nvl(v_tot_er, 0) + nvl(v_tot_sr, 0);
      --genero o actualizo registro en a_personas -------------------
      --mensaje_log('prest -> ins persona');
      IF v_tot_ctr_cred > 0 OR v_tot_ctr_ries > 0 THEN
         --Determina la actividad economica del cliente.
         v_actividad := nvl(v_actividad, 504);
         IF v_tip_destino IS NULL THEN
            v_tip_destino := fup_obt_tip_destino(p_cod_persona, v_cod_modalidad, v_cod_moneda,
                                                 v_mto_capital, NULL, v_mto_capital, NULL,
                                                 v_tip_prestamo, 'S');
         END IF;
         IF v_tip_destino = 4 THEN
            v_actividad := 701;
         END IF;

         pr_ins_personas(p_cod_persona, v_mto_gar_cober, v_tot_tc, v_tot_dc, v_tot_tr, v_tot_dr,
                         v_tot_er, v_tot_sr, v_tot_ctr_cred, v_tot_ctr_ries, v_tip_identif,
                         v_nro_identif, v_cat);
         --genero el registro en c_item --------------------------------
         IF v_est_batch IN ('C', 'A') THEN
            v_item := '110';
         ELSIF v_est_batch = 'V' THEN
            v_item := '230';
         ELSIF v_est_batch = 'G' THEN
            v_item := '240';
         ELSIF v_est_batch = 'M' THEN
            v_item := '260';
         ELSIF v_est_batch = 'I' THEN
            v_item := '270';
         ELSE
            v_item := '110';
         END IF;
         IF v_cod_modalidad IN (670, 671) THEN
            v_item := '610';
         END IF;
         IF fup_obt_tip_bono(v_cod_modalidad) = 'S' THEN
            v_item := '904';
         END IF;

         --mensaje_log('prest -> ins item');
         pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, p_oficina,
                     v_departamento, v_cod_moneda, v_actividad, v_sal_cap, v_sal_cap);

         --- inserta otro detalle por monto de garante o codeudor --- DM 02/12/2009
         IF v_control != 0 THEN
            v_item := '450'; -- RES 205/2006
            pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, p_oficina,
                        v_departamento, v_cod_moneda, v_actividad, 0, v_tot_sr);
         END IF;

         IF v_sal_cap != 0 THEN
            --- Solo se genera si tiene deuda el deudor
            IF v_tot_sr > 0 THEN
               ---  modificado para descuento de documento
               FOR reg IN firmantes LOOP
                  --- Busca tipo de vinculo
                  BEGIN
                     SELECT '2'
                       INTO v_tipo_vinculo
                       FROM ba_personas b, ba_vinculos v
                      WHERE v.cod_persona = reg.cod_persona
                        AND v.tipo = 'E'
                        AND v.cod_per_vinculo = b.cod_persona
                        AND v.cod_per_vinculo NOT IN
                            (SELECT cod_persona
                               FROM ge_cta_clientes
                              WHERE relacion NOT IN ('P', 'A')
                                AND nro_cuenta = reg.cuenta);
                  EXCEPTION
                     WHEN no_data_found THEN
                        v_tipo_vinculo := '4';
                     WHEN OTHERS THEN
                        v_tipo_vinculo := '2';
                  END;
                  --- Busca los datos del grupo economico para insertar como vinculo --
                  BEGIN
                     SELECT e.abreviatura, p.nro_documento
                       INTO v_tip_identif2, v_nro_identif2
                       FROM ba_personas p, ba_tip_documentos e
                      WHERE p.cod_persona = reg.cod_persona
                        AND p.cod_tip_documento = e.cod_tip_documento;
                  EXCEPTION
                     WHEN OTHERS THEN
                        raise_application_error(-20001,
                                                'Error. persona emisor documento ' || p_nro_cuenta || '-' ||
                                                 SQLERRM);
                  END;
                  ----- la primera parte es de la persona del grupo economico, la segunda parte del firmante
                  pr_ins_vinculos(v_tip_identif2, v_nro_identif2, reg.cod_persona, v_tip_identif,
                                  v_nro_identif, p_cod_persona, v_tipo_vinculo);
               END LOOP;
            END IF;
         END IF;

         --genera los codeudores de la cuenta --------------------------
         IF v_sal_cap <> 0 THEN
            --- Solo se genera si tiene deuda el deudor
            pr_gen_gar_codeu(p_nro_cuenta, p_cod_persona, v_garan, v_sal_cap, v_tip_identif,
                             v_nro_identif, v_plazo, p_oficina, v_departamento, v_cod_moneda);
         END IF;
         --genera el 4to archivo: CONSUMOS
         IF (v_tip_destino = 4 OR v_actividad = 701) AND v_item NOT IN ('440', '770', '780', '270', '280', '450') THEN --JF AP 2875
            pr_ins_consumos(p_nro_cuenta, p_cod_persona, v_tip_identif, v_nro_identif);
         END IF;

         BEGIN
            v_mto_prevision := 0;
            SELECT nvl(g.tot_prevision, 0)
              INTO v_mto_prevision
              FROM ge_cla_operaciones g
             WHERE g.nro_cuenta = p_nro_cuenta;
         EXCEPTION
            WHEN no_data_found THEN
               v_mto_prevision := 0;
         END;

         IF v_mto_prevision <> 0 THEN
            v_item := '770';
            pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, p_oficina,
                        v_departamento, v_cod_moneda, v_actividad, v_mto_prevision, v_mto_prevision);
         END IF;
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         NULL; --PARA Q PROCESE EL SGTE
      --RAISE_APPLICATION_ERROR(-20000,'No existe Prestamo '||P_NRO_CUENTA);
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Gen. Prestamo ' || p_nro_cuenta || '-' || SQLERRM);
   END;
   PROCEDURE pr_gen_tarj_crc
   (
      p_nro_cuenta  IN ge_cta_clientes.nro_cuenta%TYPE,
      p_cod_persona IN ge_cta_clientes.cod_persona%TYPE
   ) IS
      v_cod_moneda       VARCHAR2(03);
      v_departamento     NUMBER(03);
      v_plazo            NUMBER(04);
      v_oficina          NUMBER(03) := 0;
      v_cat_mora         NUMBER(01);
      v_tip_identif      VARCHAR2(03);
      v_nro_identif      VARCHAR2(15);
      v_sal_cap          NUMBER(15) := 0;
      v_lineas           NUMBER(15) := 0;
      v_fec_apertura     DATE;
      v_mto_contingencia NUMBER(15) := 0;
      v_garan            NUMBER(15) := 0;
      v_mto_gar_cober    NUMBER(15) := 0;
      v_total_tc         NUMBER(15) := 0;
      v_total_dc         NUMBER(15) := 0;
      v_total_tr         NUMBER(15) := 0;
      v_total_dr         NUMBER(15) := 0;
      v_total_er         NUMBER(15) := 0;
      v_total_sr         NUMBER(15) := 0;
      v_tot_ctr_cred     NUMBER(15) := 0;
      v_tot_ctr_ries     NUMBER(15) := 0;
      v_actividad        NUMBER(3);
      v_item             VARCHAR2(3);
      v_mto_prevision    ge_cla_operaciones.tot_prevision%TYPE;
      v_estado           ta_cta_tarjetas.estado%type; -- ICL 22/03/2012 Mail HB
   BEGIN
      SELECT a.cod_moneda,
             decode(nvl(cod_departamento, 0), 0, 11, cod_departamento),
             FUG_OBT_PLZ_CONTABLE(NVL(a.dia_mora,0))||0,
             (nvl(a.lin_credito, 0) + decode(v_tip_implementacion, 2, nvl(a.lin_cuotas, 0), 0)) *
             decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                    pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)) mto_linea,
             nvl(a.sal_procesadora, 0) *
             decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                    pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)) mto_deuda,
             a.cod_oficina,
             a.cat_automatica,
             cod_actividad,
             a.fec_apertura,
             a.estado
        INTO v_cod_moneda,
             v_departamento,
             v_plazo,
             v_lineas,
             v_sal_cap,
             v_oficina,
             v_cat_mora,
             v_actividad,
             v_fec_apertura,
             v_estado
        FROM ge_clientes         d,
             ba_personas         e,
             ge_cta_clientes     b,
             ta_cta_tarjetas     a,
             ta_cta_tarjetas_tmp tam
       WHERE a.nro_cuenta = b.nro_cuenta
         AND relacion = 'P'
         AND b.cod_persona = d.cod_persona
         AND d.cod_persona = p_cod_persona
         AND d.cod_persona = e.cod_persona
         AND e.cod_persona = p_cod_persona
         AND b.nro_cuenta = p_nro_cuenta
         AND b.cod_persona = p_cod_persona
         AND a.nro_cuenta = p_nro_cuenta
         AND a.cod_modalidad != 55
         AND tam.nro_cuenta = to_number(a.nro_cuenta)
         AND ((tam.sit_cuenta = 3 AND nvl(a.sal_procesadora, 0) != 0) OR tam.sit_cuenta != 3);

      ------------------------------------------------------------------
      -- CALCULA EN MILES DE GUARANIES EL SALDO DE CUENTAS CORRIENTES --
      ------------------------------------------------------------------
      v_sal_cap := round(nvl(v_sal_cap, 0), 0);

      ---------------------------------------------------------
      -- OBTIENE EL VALOR DE LA GARANTIA DEL PRESTAMO        --
      ---------------------------------------------------------
      SELECT SUM(nvl(a.mto_aplicado, 0) *
                 decode(c.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                        pag_gen.fu_obt_cotizacion(c.cod_moneda, v_fec_actual)))
        INTO v_garan
        FROM pr_garantias b, ta_cta_garantias a, ta_cta_tarjetas c
       WHERE a.nro_garantia = b.nro_garantia
         AND a.nro_cuenta = p_nro_cuenta
         AND a.nro_cuenta = c.nro_cuenta
         AND c.nro_cuenta = p_nro_cuenta;
      -----------------------------------------------------------
      -- CALCULA EL VALOR DE LA GARANTIA EN MILES DE GUARANIES --
      -----------------------------------------------------------
      IF nvl(v_garan, 0) > 0 THEN
         v_garan := round(v_garan, 0);
      ELSE
         v_garan := 0;
      END IF;

      v_mto_gar_cober := v_garan;
      --
      --- Para tarjetas se debe realizar dos inserciones
      --- Por la mora y por la contingencia
      --- Tarjetas se informa siempre aunque sea cero, negativo debe
      --- informarse como cero
      IF v_sal_cap < 0 THEN
         --- Por la Mora
         v_sal_cap := 0;
      END IF;
      v_total_tc := v_sal_cap;
      v_total_dc := 0;
      v_total_tr := v_sal_cap;
      v_total_dr := 0;
      v_total_er := 0;
      v_total_sr := 0;
      v_cat      := NULL;
      --
      v_tot_ctr_cred := nvl(v_total_tc, 0) + nvl(v_total_dc, 0);
      v_tot_ctr_ries := nvl(v_total_tr, 0) + nvl(v_total_dr, 0) + nvl(v_total_er, 0) +
                        nvl(v_total_sr, 0);
      --genero o actualizo registro en a_personas -------------------
      --mensaje_log('tarj -> ins persona');
      IF v_sal_cap > 0 OR (v_sal_cap = 0 AND nvl(v_lineas, 0) > 0) THEN
         pr_ins_personas(p_cod_persona, v_mto_gar_cober, v_total_tc, v_total_dc, v_total_tr,
                         v_total_dr, v_total_er, v_total_sr, v_tot_ctr_cred, v_tot_ctr_ries,
                         v_tip_identif, v_nro_identif, v_cat);
         --genero el registro en c_item --------------------------------
         IF v_cat_mora = 1 THEN
            --CAT_AUTOMATICA
            v_item := '110';
         ELSIF v_cat_mora = 2 THEN
            v_item := '230';
         ELSIF v_cat_mora = 3 THEN
            v_item := '240';
         ELSIF v_cat_mora IN (4, 5, 6) THEN
            v_item := '260';
         ELSE
            v_item := '110';
         END IF;
         IF nvl(v_actividad, 0) <> 701 THEN
            v_actividad := 701;
         END IF;

         --mensaje_log('tarj -> ins item');
         IF v_sal_cap > 0 THEN
            pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, v_oficina,
                        v_departamento, v_cod_moneda, v_actividad, v_sal_cap, v_sal_cap);
         END IF;
         --genera el 4to archivo: CONSUMOS
         IF (v_actividad = '701' AND v_item NOT IN ('440', '770', '780', '280', '450')) THEN
            pr_ins_consumos(p_nro_cuenta, p_cod_persona, v_tip_identif, v_nro_identif, v_sal_cap);
         END IF;
         --mensaje_log('tarj -> fin');
      END IF;
      --- Hallar el monto de contingencia
      IF v_sal_cap > 0 AND v_sal_cap > nvl(v_lineas, 0) THEN
         v_lineas := v_sal_cap;
      END IF;
      v_mto_contingencia := v_lineas - v_sal_cap;
      IF v_mto_contingencia < 0 THEN
         v_mto_contingencia := 0;
      END IF;
      IF v_estado = 'B' THEN -- ICL 22/03/2012 Mail HB: Unificar con PAP_CAT y Contabilidad
         -- Para tarjetas Bloqueadas, el cliente no tiene disponibilidad de la linea
         -- por tal motivo no es contingente
         v_mto_contingencia := 0;
      END IF;
      v_total_tc := 0;
      v_total_dc := 0;
      v_total_dr := 0;
      v_total_sr := 0;
      v_total_er := v_mto_contingencia;
      v_total_tr := 0;
      --V_TOTAL_TR := V_MTO_CONTINGENCIA; RES-205/2006
      --V_TOTAL_ER := 0;
      --
      v_tot_ctr_cred := nvl(v_total_tc, 0) + nvl(v_total_dc, 0);
      v_tot_ctr_ries := nvl(v_total_tr, 0) + nvl(v_total_dr, 0) + nvl(v_total_er, 0) +
                        nvl(v_total_sr, 0);
      --genero o actualizo registro en a_personas -------------------
      -- La contingencia no actualiza personas -- Desde 205/2006
      pr_ins_personas(p_cod_persona, v_mto_gar_cober, v_total_tc, v_total_dc, v_total_tr,
                      v_total_dr, v_total_er, v_total_sr, v_tot_ctr_cred, v_tot_ctr_ries,
                      v_tip_identif, v_nro_identif);
      --genero el registro en c_item --------------------------------
      v_item := '780'; -- Contingencia
      IF v_actividad <> 701 THEN
         v_actividad := 701;
      END IF;
      IF v_mto_contingencia > 0 THEN
         pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, v_oficina,
                     v_departamento, v_cod_moneda, v_actividad, 0, v_mto_contingencia);
      END IF;
      IF v_sal_cap > 0 /*or v_mto_contingencia > 0*/
       THEN
         --- Solo se genera si tiene deuda el deudor
         pr_gen_gar_codeu(p_nro_cuenta, p_cod_persona, v_garan, v_sal_cap, v_tip_identif,
                          v_nro_identif, v_plazo, v_oficina, v_departamento, v_cod_moneda);
      END IF;

      BEGIN
         v_mto_prevision := 0;
         SELECT nvl(g.tot_prevision, 0)
           INTO v_mto_prevision
           FROM ge_cla_operaciones g
          WHERE g.nro_cuenta = p_nro_cuenta;
      EXCEPTION
         WHEN no_data_found THEN
            v_mto_prevision := 0;
      END;

      IF v_mto_prevision <> 0 THEN
         v_item := '770';
         pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, v_oficina,
                     v_departamento, v_cod_moneda, v_actividad, v_mto_prevision, v_mto_prevision);
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         NULL; --PARA Q SIGA CON EL SGTE
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Gen. Tarj. ' || p_nro_cuenta || '-' || SQLERRM);
   END;
   -----------------------------PR_GEN_OPE_VEN_CRC------------------------------------
   PROCEDURE pr_gen_ope_ven_crc
   (
      p_modulo        IN ov_cta_vencidas.cod_modulo%TYPE,
      p_modalidad     IN ov_cta_vencidas.cod_modalidad%TYPE,
      p_oficina       IN ov_cta_vencidas.cod_oficina%TYPE,
      p_nro_cuenta    IN ov_cta_vencidas.nro_cuenta%TYPE,
      p_cod_persona   IN ge_cta_clientes.cod_persona%TYPE
   ) IS
      v_cod_moneda    VARCHAR2(03);
      v_departamento  VARCHAR2(03);
      v_est_batch     VARCHAR2(01);
      v_tip_identif   VARCHAR2(03);
      v_nro_identif   VARCHAR2(15);
      v_item          VARCHAR2(3);
      v_sal_cap       NUMBER(15) := 0;
      v_garan         NUMBER(15) := 0;
      v_mto_gar_cober NUMBER(15) := 0;
      v_tot_tc        NUMBER(15) := 0;
      v_tot_dc        NUMBER(15) := 0;
      v_tot_tr        NUMBER(15) := 0;
      v_tot_dr        NUMBER(15) := 0;
      v_tot_er        NUMBER(15) := 0;
      v_tot_sr        NUMBER(15) := 0;
      v_tot_ctr_cred  NUMBER(15) := 0;
      v_tot_ctr_ries  NUMBER(15) := 0;
      v_control       NUMBER(5) := 0;
      v_plazo         NUMBER(04);
      v_actividad     NUMBER(3);
      v_cod_modalidad ge_modalidades.cod_modalidad%TYPE;
      v_tip_destino   pr_cta_prestamos.tip_destino%TYPE;
      v_mto_capital   pr_cta_prestamos.mto_capital%TYPE := 0;
      v_mto_prevision ge_cla_operaciones.tot_prevision%TYPE;
      v_tip_persona   ba_personas.tipo%TYPE;
      -----------------------------------------------------------

   BEGIN
      SELECT a.cod_moneda,
             a.estado,
             decode(nvl(cod_departamento, 0), 0, 11, cod_departamento),
             FUG_OBT_PLZ_CONTABLE(NVL(a.dia_atraso,0))||0,
             nvl(sal_tot_batch, 0) *
             decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                    pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)),
             ba.cod_actividad,
             a.cod_modalidad,
             4,
             a.mto_origen,
             c.tipo
        INTO v_cod_moneda,
             v_est_batch,
             v_departamento,
             v_plazo,
             v_sal_cap,
             v_actividad,
             v_cod_modalidad,
             v_tip_destino,
             v_mto_capital,
             v_tip_persona
        FROM ba_personas ba, ge_clientes d, ge_cta_clientes b, ov_cta_vencidas a, ba_personas c
       WHERE a.nro_cuenta = b.nro_cuenta
         AND a.nro_cuenta = p_nro_cuenta
         AND b.cod_persona = d.cod_persona
         AND b.cod_persona = p_cod_persona
         AND b.nro_cuenta = p_nro_cuenta
         AND d.cod_persona = p_cod_persona
         AND c.cod_persona = p_cod_persona
         AND ba.cod_persona = d.cod_persona
         AND b.relacion = 'P'
         AND a.estado NOT IN ('C'); -- V=Vencido, G=Gestion, M=Moroso, I=Incobrables ---- AP 2875

      ----------------------------------------------------------
      --- Busca el saldo segun Inventario

      pav_ove.pr_ini_modulo;
      pav_ove.pr_ini_autorizacion;
      pav_ove.pr_obt_deu_ope_vencida(p_nro_cuenta, v_fec_actual, v_cobrado, v_error, v_mensaje,
                                     v_tot_capital, v_tot_mora, v_tot_punitorio, v_tot_impuesto,
                                     v_tot_cargo, v_tot_car_iva, v_dia_mora, v_cod_tra_padre);
      COMMIT;

      ---------------------------------------------------------
      -- CALCULA EN MILES DE GUARANIES EL SALDO DEL préstamo --
      ---------------------------------------------------------
      -- a guaranies--

      IF v_cod_moneda = 'GS' THEN
         v_sal_cap := v_tot_capital;
      ELSIF v_cod_moneda = 'USD' THEN
         v_sal_cap := v_tot_capital * v_cot_fuerte;
      ELSE
         v_sal_cap := v_tot_capital * pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
      END IF;
      v_sal_cap := round(v_sal_cap, 0);
      ---------------------------------------------------------
      -- OBTIENE EL VALOR DE LA GARANTIA DEL préstamo        --
      ---------------------------------------------------------
      SELECT SUM(nvl(a.mto_aplicado, 0) *
                 decode(c.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                        pag_gen.fu_obt_cotizacion(c.cod_moneda, v_fec_actual)))
        INTO v_garan
        FROM pr_garantias b, ov_cta_garantias a, ov_cta_vencidas c
       WHERE a.nro_garantia = b.nro_garantia
         AND a.nro_cuenta = p_nro_cuenta
         AND a.nro_cuenta = c.nro_cuenta
         AND c.nro_cuenta = p_nro_cuenta;
      -----------------------------------------------------------
      -- CALCULA EL VALOR DE LA GARANTIA EN MILES DE GUARANIES --
      -----------------------------------------------------------
      IF nvl(v_garan, 0) > 0 THEN
         v_garan := round(v_garan, 0);
      ELSE
         v_garan := 0;
      END IF;
      -- Cargo los datos para la generacion de a-personas -------------
      v_mto_gar_cober := v_garan;
      v_tot_tc        := v_sal_cap;
      v_tot_tr        := v_sal_cap;
      v_tot_er        := 0; --- No se manejan Lineas por GF RES 205/2006
      v_cat           := NULL;
      v_tot_ctr_cred  := nvl(v_tot_tc, 0) + nvl(v_tot_dc, 0);
      v_tot_ctr_ries  := nvl(v_tot_tr, 0) + nvl(v_tot_dr, 0) + nvl(v_tot_er, 0) + nvl(v_tot_sr, 0);

      IF v_tot_ctr_cred > 0 OR v_tot_ctr_ries > 0 THEN

         -- genero el registro en c_item --------------------------------
         IF nvl(v_est_batch, 'C') = 'C' THEN
            -- Canceada
            v_item := '110';
         ELSIF v_est_batch = 'V' THEN
            -- Vencida
            v_item := '230';
         ELSIF v_est_batch = 'G' THEN
            -- Gestión
            v_item := '240';
         ELSIF v_est_batch = 'M' THEN
            -- Morosa
            v_item := '260';
         ELSIF v_est_batch = 'I' THEN
            -- Incobrable
            v_item := '270';
            v_cat  := '6';
         ELSE
            v_item := '110';
         END IF;

         -- Genero o Actualizo registro en a_personas -------------------
         pr_ins_personas(p_cod_persona, v_mto_gar_cober, v_tot_tc, v_tot_dc, v_tot_tr, v_tot_dr,
                         v_tot_er, v_tot_sr, v_tot_ctr_cred, v_tot_ctr_ries, v_tip_identif,
                         v_nro_identif, v_cat);

         IF v_control <> 0 THEN
            -------nunca varia su valor, se declara con cero y permanece asi..
            v_item := '450'; -- RES 205/2006
         END IF;

         pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, p_oficina,
                     v_departamento, v_cod_moneda, v_actividad, v_sal_cap, v_sal_cap);

         -- Genera los codeudores de la cuenta --------------------------
         IF v_sal_cap <> 0 THEN
            --- Solo se genera si tiene deuda el deudor
            pr_gen_gar_codeu(p_nro_cuenta, p_cod_persona, v_garan, v_sal_cap, v_tip_identif,
                             v_nro_identif, v_plazo, p_oficina, v_departamento, v_cod_moneda);
         END IF;

         -- Genera el 4to archivo: CONSUMOS
         -- Agregar solo operaciones de consumo --
         -- A partir de la Res. 000038/2006 SE INFORMA las incobrables
         IF (v_actividad = '701' AND v_item NOT IN ('440', '770', '780', '270', '280', '450')) THEN --JF AP 2875
            pr_ins_consumos(p_nro_cuenta, p_cod_persona, v_tip_identif, v_nro_identif);
         END IF;

         BEGIN
            v_mto_prevision := 0;
            SELECT nvl(g.tot_prevision, 0)
              INTO v_mto_prevision
              FROM ge_cla_operaciones g
             WHERE g.nro_cuenta = p_nro_cuenta;
         EXCEPTION
            WHEN no_data_found THEN
               v_mto_prevision := 0;
         END;

         IF v_mto_prevision <> 0 THEN
            v_item := '770';
            pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, p_oficina,
                        v_departamento, v_cod_moneda, v_actividad, v_mto_prevision, v_mto_prevision);
         END IF;

      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         NULL; --PARA Q PROCESE EL SGTE
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Gen. oper. venc. ' || p_nro_cuenta || '-' || SQLERRM);
   END;

   -----------------------------PR_GEN_IMPORTAC_CRC---------------------------------------
   PROCEDURE pr_gen_importac_crc
   (
      p_modulo      IN cx_cta_importaciones.cod_modulo%TYPE,
      p_modalidad   IN cx_cta_importaciones.cod_modalidad%TYPE,
      p_oficina     IN cx_cta_importaciones.cod_oficina%TYPE,
      p_nro_cuenta  IN cx_cta_importaciones.nro_cuenta%TYPE,
      p_cod_persona IN ge_cta_clientes.cod_persona%TYPE
   ) IS
      v_cod_moneda       VARCHAR2(03);
      v_tip_identif      VARCHAR2(03);
      v_nro_identif      VARCHAR2(15);
      v_item             VARCHAR2(3);
      v_sal_cap          NUMBER(15) := 0;
      v_garan            NUMBER(15) := 0;
      v_mto_contingencia NUMBER(15) := 0;
      v_departamento     NUMBER(03);
      v_plazo            NUMBER(04);
      v_mto_gar_cober    NUMBER(15);
      v_total_tc         NUMBER(15);
      v_total_dc         NUMBER(15);
      v_total_tr         NUMBER(15);
      v_total_dr         NUMBER(15);
      v_total_er         NUMBER(15);
      v_total_sr         NUMBER(15);
      v_tot_ctr_cred     NUMBER(15);
      v_tot_ctr_ries     NUMBER(15);
      v_actividad        NUMBER(3);
      v_dias_sobregiro   NUMBER(5);
      v_fec_aper         DATE;
      v_tip_persona      ba_personas.tipo%TYPE;
      v_mto_prevision    ge_cla_operaciones.tot_prevision%TYPE:= 0;  --AP 2875
   BEGIN
      SELECT im.cod_moneda,
             decode(nvl(cl.cod_departamento, 0), 0, 11, cl.cod_departamento),
             FUG_OBT_PLZ_CONTABLE(0)||0,
             CASE
                WHEN v_fec_actual - im.fec_vencimiento > 0 THEN
                 v_fec_actual - im.fec_vencimiento
                ELSE
                 0
             END,
             0 * decode(im.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                        pag_gen.fu_obt_cotizacion(im.cod_moneda, v_fec_actual)),
             im.fec_aprobacion,
             ba.cod_actividad,
             ba.tipo,
             im.saldo * decode(im.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                               pag_gen.fu_obt_cotizacion(im.cod_moneda, v_fec_actual))
        INTO v_cod_moneda,
             v_departamento,
             v_plazo,
             v_dias_sobregiro,
             v_sal_cap,
             v_fec_aper,
             v_actividad,
             v_tip_persona,
             v_mto_contingencia
        FROM ba_personas ba, ge_cta_clientes ct, cx_cta_importaciones im, ge_clientes cl
       WHERE ct.nro_cuenta  = im.nro_cuenta
         AND ct.relacion    = 'P'
         AND ba.cod_persona = ct.cod_persona
         AND cl.cod_persona = ct.cod_persona
         AND im.estado      NOT IN ('C', 'S') --Cancelada y Solicitada.
         AND im.saldo       > 0   --AP 2875
         AND im.nro_cuenta  = p_nro_cuenta
         AND ct.cod_persona = p_cod_persona;

      ------------------------------------------------------------------
      -- CALCULA EN MILES DE GUARANIES EL SALDO DE CUENTAS CORRIENTES --
      ------------------------------------------------------------------
      v_sal_cap := round(v_sal_cap, 0);
      --Obtiene el monto de la garantia--
      SELECT SUM(nvl(a.mto_aplicado, 0) *
                 decode(c.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                        pag_gen.fu_obt_cotizacion(c.cod_moneda, v_fec_actual)))
        INTO v_garan
        FROM pr_garantias b, cx_cta_garantias a, cx_cta_importaciones c
       WHERE a.nro_garantia = b.nro_garantia
         AND a.nro_cuenta   = p_nro_cuenta
         AND a.nro_cuenta   = c.nro_cuenta
         AND c.nro_cuenta   = p_nro_cuenta
         AND c.saldo        > 0   --AP 2875
         AND c.estado       IN ('A', 'U'); --A-Normal, U-Utilizada--

      IF v_garan > v_sal_cap THEN
         v_garan := v_sal_cap;
      END IF;

      v_garan := nvl(v_garan, 0);

      --- cargo las variables para act. o generar reg. en a_personas ---
      v_mto_gar_cober := v_garan;
      v_total_tc      := v_sal_cap;
      v_total_dc      := 0;
      v_total_tr      := v_sal_cap;
      v_total_dr      := 0;
      v_total_er      := 0;
      v_total_sr      := 0;
      v_cat           := NULL;
      v_tot_ctr_cred  := nvl(v_total_tc, 0) + nvl(v_total_dc, 0);
      v_tot_ctr_ries  := nvl(v_total_tr, 0) + nvl(v_total_dr, 0) + nvl(v_total_er, 0) +
                         nvl(v_total_sr, 0);

      -- Genero o actualizo registro en a_personas -------------------
      IF v_sal_cap > 0 OR (v_sal_cap = 0 AND nvl(v_mto_contingencia, 0) > 0) THEN
         pr_ins_personas(p_cod_persona, v_mto_gar_cober, v_total_tc, v_total_dc, v_total_tr,
                         v_total_dr, v_total_er, v_total_sr, v_tot_ctr_cred, v_tot_ctr_ries,
                         v_tip_identif, v_nro_identif, v_cat);

         -- Genero el registro en c_item --------------------------------
         IF nvl(v_dias_sobregiro, 0) <= 60 THEN
            v_item := '110';
         ELSIF nvl(v_dias_sobregiro, 0) >= 61 AND nvl(v_dias_sobregiro, 0) <= 90 THEN
            v_item := '230';
         ELSIF nvl(v_dias_sobregiro, 0) >= 91 AND nvl(v_dias_sobregiro, 0) <= 180 THEN
            v_item := '240';
         ELSIF nvl(v_dias_sobregiro, 0) >= 181 THEN
            v_item := '260';
         END IF;

         pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, p_oficina,
                     v_departamento, v_cod_moneda, v_actividad, v_sal_cap, v_sal_cap);

         -- Genera los codeudores de la cuenta --------------------------
         IF v_sal_cap <> 0 THEN
            --- Solo se genera si tiene deuda el deudor
            pr_gen_gar_codeu(p_nro_cuenta, p_cod_persona, v_garan, v_sal_cap, v_tip_identif,
                             v_nro_identif, v_plazo, p_oficina, v_departamento, v_cod_moneda);
         END IF;

         -- Genera el 4to archivo: CONSUMOS
         -- Agregar solo operaciones de consumos--

         IF (v_actividad = '701' AND v_item NOT IN ('440', '770', '780', '270', '280', '450')) THEN
            pr_ins_consumos(p_nro_cuenta, p_cod_persona, v_tip_identif, v_nro_identif);
         END IF;
      END IF;

      IF v_mto_contingencia < 0 THEN
         v_mto_contingencia := 0;
      END IF;

      v_total_tc     := 0;
      v_total_dc     := 0;
      v_total_dr     := 0;
      v_total_sr     := 0;
      v_total_er     := v_mto_contingencia;
      v_total_tr     := 0;
      v_tot_ctr_cred := nvl(v_total_tc, 0) + nvl(v_total_dc, 0);
      v_tot_ctr_ries := nvl(v_total_tr, 0) + nvl(v_total_dr, 0) + nvl(v_total_er, 0) +
                        nvl(v_total_sr, 0);

      -- Genero o actualizo registro en a_personas -------------
      -- La contingencia no actualiza personas -- Desde 205/2006
      pr_ins_personas(p_cod_persona, v_mto_gar_cober, v_total_tc, v_total_dc, v_total_tr,
                      v_total_dr, v_total_er, v_total_sr, v_tot_ctr_cred, v_tot_ctr_ries,
                      v_tip_identif, v_nro_identif);

      -- Genero el registro en c_item --------------------------------
      v_item := '780'; -- Contingencia
      IF v_mto_contingencia > 0 THEN
         pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, p_oficina,
                     v_departamento, v_cod_moneda, v_actividad, 0, v_mto_contingencia);
      END IF;

      --> Corresponde a Previsiones  -- AP 2875
      BEGIN
         v_mto_prevision := 0;
         SELECT nvl(g.tot_prevision, 0)
           INTO v_mto_prevision
           FROM ge_cla_operaciones g
          WHERE g.nro_cuenta = p_nro_cuenta;
      EXCEPTION
         WHEN no_data_found THEN
            v_mto_prevision := 0;
      END;

      IF v_mto_prevision <> 0 THEN
         v_item := '770';
         pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, p_oficina,
                     v_departamento, v_cod_moneda, v_actividad, v_mto_prevision, v_mto_prevision);
      END IF;
      --<
   EXCEPTION
      WHEN no_data_found THEN
         NULL; --PARA Q PROCESE LA SGTE
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Gen. Importaciones ' || p_nro_cuenta || '-' || SQLERRM);
   END;

   -----------------------------PR_GEN_FIANZAS_CRC---------------------------------------
   PROCEDURE pr_gen_fianzas_crc
   (
      p_modulo      IN cx_cta_importaciones.cod_modulo%TYPE,
      p_modalidad   IN cx_cta_importaciones.cod_modalidad%TYPE,
      p_oficina     IN cx_cta_importaciones.cod_oficina%TYPE,
      p_nro_cuenta  IN cx_cta_importaciones.nro_cuenta%TYPE,
      p_cod_persona IN ge_cta_clientes.cod_persona%TYPE
   ) IS
      v_cod_moneda       VARCHAR2(03);
      v_tip_identif      VARCHAR2(03);
      v_nro_identif      VARCHAR2(15);
      v_item             VARCHAR2(3);
      v_mto_contingencia NUMBER(15) := 0;
      v_sal_cap          NUMBER(15) := 0;
      v_garan            NUMBER(15) := 0;
      v_departamento     NUMBER(03);
      v_plazo            NUMBER(04);
      v_mto_gar_cober    NUMBER(15);
      v_total_tc         NUMBER(15);
      v_total_dc         NUMBER(15);
      v_total_tr         NUMBER(15);
      v_total_dr         NUMBER(15);
      v_total_er         NUMBER(15);
      v_total_sr         NUMBER(15);
      v_tot_ctr_cred     NUMBER(15);
      v_tot_ctr_ries     NUMBER(15);
      v_actividad        NUMBER(3);
      v_dias_sobregiro   NUMBER(5);
      v_fec_aper         DATE;
      v_tip_persona      ba_personas.tipo%TYPE;
   BEGIN
      SELECT im.cod_moneda,
             decode(nvl(cl.cod_departamento, 0), 0, 11, cl.cod_departamento),
             FUG_OBT_PLZ_CONTABLE(0)||0,
             CASE
                WHEN v_fec_actual - im.fec_vencimiento > 0 THEN
                 v_fec_actual - im.fec_vencimiento
                ELSE
                 0
             END,
             0 * decode(im.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                        pag_gen.fu_obt_cotizacion(im.cod_moneda, v_fec_actual)),
             NULL fec_aprobacion,
             ba.cod_actividad,
             ba.tipo,
             im.monto * decode(im.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                               pag_gen.fu_obt_cotizacion(im.cod_moneda, v_fec_actual))
        INTO v_cod_moneda,
             v_departamento,
             v_plazo,
             v_dias_sobregiro,
             v_sal_cap,
             v_fec_aper,
             v_actividad,
             v_tip_persona,
             v_mto_contingencia
        FROM ba_personas ba, ge_cta_clientes ct, cx_fianzas im, ge_clientes cl
       WHERE ct.nro_cuenta     = im.nro_cuenta
         AND ct.relacion       = 'P'
         AND ba.cod_persona    = ct.cod_persona
         AND cl.cod_persona    = ct.cod_persona
         AND im.estado         NOT IN ('C', 'S') --A-Aprobado--
        -- AND im.contragarantia = 'N' DYDMR-1514 22/01/2014 FM -- ICL 22/03/12: Mail HB
         AND im.monto          > 0   --AP 2875
         AND im.nro_cuenta     = p_nro_cuenta
         AND ct.cod_persona    = p_cod_persona;

      ------------------------------------------------------------------
      -- CALCULA EN MILES DE GUARANIES EL SALDO DE CUENTAS CORRIENTES --
      ------------------------------------------------------------------
      v_sal_cap := round(v_sal_cap, 0);
      --Obtiene el monto de la garantia--
      SELECT SUM(nvl(a.mto_aplicado, 0) *
                 decode(c.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                        pag_gen.fu_obt_cotizacion(c.cod_moneda, v_fec_actual)))
        INTO v_garan
        FROM pr_garantias b, cx_cta_garantias a, cx_fianzas c
       WHERE a.nro_garantia = b.nro_garantia
         AND a.nro_cuenta   = p_nro_cuenta
         AND a.nro_cuenta   = c.nro_cuenta
         AND c.nro_cuenta   = p_nro_cuenta
         AND c.monto        > 0    --AP 2875
         AND c.estado       = 'A'; --A-Aprobado--

      IF v_garan > v_sal_cap THEN
         v_garan := v_sal_cap;
      END IF;

      v_garan := nvl(v_garan, 0);
      --- cargo las variables para act. o generar reg. en a_personas ---
      v_mto_gar_cober := v_garan;
      v_total_tc      := v_sal_cap;
      v_total_dc      := 0;
      v_total_tr      := v_sal_cap;
      v_total_dr      := 0;
      v_total_er      := 0;
      v_total_sr      := 0;
      v_cat           := NULL;
      -- totales de control --------------------------------------------
      v_tot_ctr_cred := nvl(v_total_tc, 0) + nvl(v_total_dc, 0);
      v_tot_ctr_ries := nvl(v_total_tr, 0) + nvl(v_total_dr, 0) + nvl(v_total_er, 0) +
                        nvl(v_total_sr, 0);
      --genero o actualizo registro en a_personas -------------------
      --mensaje_log('ctacte -> ins persona');
      -----
      IF v_sal_cap > 0 OR (v_sal_cap = 0 AND nvl(v_mto_contingencia, 0) > 0) THEN
         -----
         pr_ins_personas(p_cod_persona, v_mto_gar_cober, v_total_tc, v_total_dc, v_total_tr,
                         v_total_dr, v_total_er, v_total_sr, v_tot_ctr_cred, v_tot_ctr_ries,
                         v_tip_identif, v_nro_identif, v_cat);

         --genero el registro en c_item --------------------------------
         IF nvl(v_dias_sobregiro, 0) <= 60 THEN
            v_item := '110';
         ELSIF nvl(v_dias_sobregiro, 0) >= 61 AND nvl(v_dias_sobregiro, 0) <= 90 THEN
            v_item := '230';
         ELSIF nvl(v_dias_sobregiro, 0) >= 91 AND nvl(v_dias_sobregiro, 0) <= 180 THEN
            v_item := '240';
         ELSIF nvl(v_dias_sobregiro, 0) >= 181 THEN
            v_item := '260';
         END IF;

         IF v_tip_persona <> 'F' THEN
            v_actividad := 504; --OTROS (COMERCIO AL POR MENOR)--
         END IF;

         pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, p_oficina,
                     v_departamento, v_cod_moneda, v_actividad, v_sal_cap, v_sal_cap);
         --genera los codeudores de la cuenta --------------------------
         IF v_sal_cap <> 0 THEN
            --- Solo se genera si tiene deuda el deudor
            pr_gen_gar_codeu(p_nro_cuenta, p_cod_persona, v_garan, v_sal_cap, v_tip_identif,
                             v_nro_identif, v_plazo, p_oficina, v_departamento, v_cod_moneda);
         END IF;
         --genera el 4to archivo: CONSUMOS
         --Agregar solo operaciones de consumos--
         IF (v_actividad = '701' AND v_item NOT IN ('440', '770', '780', '270', '280', '450')) THEN
            pr_ins_consumos(p_nro_cuenta, p_cod_persona, v_tip_identif, v_nro_identif);
         END IF;
      END IF;
      ------
      IF v_mto_contingencia < 0 THEN
         v_mto_contingencia := 0;
      END IF;

      v_total_tc     := 0;
      v_total_dc     := 0;
      v_total_dr     := 0;
      v_total_sr     := 0;
      v_total_er     := v_mto_contingencia;
      v_total_tr     := 0;
      v_tot_ctr_cred := nvl(v_total_tc, 0) + nvl(v_total_dc, 0);
      v_tot_ctr_ries := nvl(v_total_tr, 0) + nvl(v_total_dr, 0) + nvl(v_total_er, 0) +
                        nvl(v_total_sr, 0);
      --genero o actualizo registro en a_personas -------------------
      -- La contingencia no actualiza personas -- Desde 205/2006
      pr_ins_personas(p_cod_persona, v_mto_gar_cober, v_total_tc, v_total_dc, v_total_tr,
                      v_total_dr, v_total_er, v_total_sr, v_tot_ctr_cred, v_tot_ctr_ries,
                      v_tip_identif, v_nro_identif);
      --genero el registro en c_item --------------------------------
      v_item := '780'; -- Contingencia
      IF v_mto_contingencia > 0 THEN
         pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, p_oficina,
                     v_departamento, v_cod_moneda, v_actividad, 0, v_mto_contingencia);
      END IF;
      --mensaje_log('ctacte -> fin');
   EXCEPTION
      WHEN no_data_found THEN
         NULL; --PARA Q PROCESE LA SGTE
      --RAISE_APPLICATION_ERROR(-20000,'No existe CTA.CTE '||P_NRO_CUENTA);
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Gen. Fianzas ' || p_nro_cuenta || '-' || SQLERRM);
   END;
   --------------------------------------------------------------------------------------------
   -----------------------------PR_GEN_MES_DINERO_CRC---------------------------------------
   PROCEDURE pr_gen_mes_dinero_crc
   (
      p_modulo      IN cx_cta_importaciones.cod_modulo%TYPE,
      p_modalidad   IN cx_cta_importaciones.cod_modalidad%TYPE,
      p_oficina     IN cx_cta_importaciones.cod_oficina%TYPE,
      p_nro_cuenta  IN cx_cta_importaciones.nro_cuenta%TYPE,
      p_cod_persona IN ge_cta_clientes.cod_persona%TYPE
   ) IS
      v_cod_moneda       VARCHAR2(03);
      v_departamento     NUMBER(03);
      v_plazo            NUMBER(04);
      v_sal_cap          NUMBER(15) := 0;
      v_garan            NUMBER(15) := 0;
      v_fec_aper         DATE;
      v_tip_identif      VARCHAR2(03);
      v_nro_identif      VARCHAR2(15);
      v_mto_gar_cober    NUMBER(15);
      v_total_tc         NUMBER(15);
      v_total_dc         NUMBER(15);
      v_total_tr         NUMBER(15);
      v_total_dr         NUMBER(15);
      v_total_er         NUMBER(15);
      v_total_sr         NUMBER(15);
      v_tot_ctr_cred     NUMBER(15);
      v_tot_ctr_ries     NUMBER(15);
      v_actividad        NUMBER(3);
      v_item             VARCHAR2(3);
      v_dias_sobregiro   NUMBER(5);
      v_tip_persona      ba_personas.tipo%TYPE;
      v_mto_contingencia NUMBER(15) := 0;
   BEGIN
      SELECT md.cod_moneda,
             decode(nvl(cl.cod_departamento, 0), 0, 11, cl.cod_departamento),
             FUG_OBT_PLZ_CONTABLE(0)||0,
             CASE
                WHEN v_fec_actual - md.fec_vencimiento > 0 THEN
                 v_fec_actual - md.fec_vencimiento
                ELSE
                 0
             END,
             md.sal_capital *
             decode(md.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                    pag_gen.fu_obt_cotizacion(md.cod_moneda, v_fec_actual)),
             NULL fec_aprobacion,
             904,
             ba.tipo,
             md.sal_capital *
             decode(md.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                    pag_gen.fu_obt_cotizacion(md.cod_moneda, v_fec_actual))
        INTO v_cod_moneda,
             v_departamento,
             v_plazo,
             v_dias_sobregiro,
             v_sal_cap,
             v_fec_aper,
             v_actividad,
             v_tip_persona,
             v_mto_contingencia
        FROM ba_personas ba, ge_cta_clientes ct, md_cta_documentos md, ge_clientes cl
       WHERE ct.nro_cuenta = md.nro_cuenta
         AND ct.relacion = 'P'
         AND ba.cod_persona = ct.cod_persona
         AND cl.cod_persona = ct.cod_persona
         AND md.estado = 'C' --C Vigente--
         AND md.cod_modalidad IN (104, 124, 142, 125,110,116,146) -- ICL 22/03/12 Mail HB: Incluir Call Money, Sacar prestamos recibidos porque es un pasivo
         AND md.nro_cuenta = p_nro_cuenta
         AND ct.cod_persona = p_cod_persona;

      --------------------------------------------------------------
      -- CALCULA EN MILES DE GUARANIES EL SALDO DE MESA DE DINERO --
      --------------------------------------------------------------
      v_sal_cap := round(v_sal_cap, 0);
      --Obtiene el monto de la garantia--
      SELECT SUM(nvl(a.mto_aplicado, 0) *
                 decode(c.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                        pag_gen.fu_obt_cotizacion(c.cod_moneda, v_fec_actual)))
        INTO v_garan
        FROM pr_garantias b, cx_cta_garantias a, md_cta_documentos c
       WHERE a.nro_garantia = b.nro_garantia
         AND a.nro_cuenta = p_nro_cuenta
         AND a.nro_cuenta = c.nro_cuenta
         AND c.nro_cuenta = p_nro_cuenta
         AND c.estado = 'C'; --C Vigente--

      IF v_garan > v_sal_cap THEN
         v_garan := v_sal_cap;
      END IF;

      v_garan := nvl(v_garan, 0);
      --- Cargo las variables para act. o generar reg. en a_personas ---
      v_mto_gar_cober := v_garan;
      v_total_tc      := v_sal_cap;
      v_total_dc      := 0;
      v_total_tr      := v_sal_cap;
      v_total_dr      := 0;
      v_total_er      := 0;
      v_total_sr      := 0;
      v_cat           := NULL;
      -- totales de control --------------------------------------------
      v_tot_ctr_cred := nvl(v_total_tc, 0) + nvl(v_total_dc, 0);
      v_tot_ctr_ries := nvl(v_total_tr, 0) + nvl(v_total_dr, 0) + nvl(v_total_er, 0) +
                        nvl(v_total_sr, 0);

      -- Genero o Actualizo registro en a_personas -------------------
      IF v_sal_cap > 0 OR (v_sal_cap = 0 AND nvl(v_mto_contingencia, 0) > 0) THEN
         pr_ins_personas(p_cod_persona, v_mto_gar_cober, v_total_tc, v_total_dc, v_total_tr,
                         v_total_dr, v_total_er, v_total_sr, v_tot_ctr_cred, v_tot_ctr_ries,
                         v_tip_identif, v_nro_identif, v_cat);

         -- Genero el Registro en c_item --------------------------------
         IF nvl(v_dias_sobregiro, 0) <= 60 THEN
            v_item := '110';
         ELSIF nvl(v_dias_sobregiro, 0) >= 61 AND nvl(v_dias_sobregiro, 0) <= 90 THEN
            v_item := '230';
         ELSIF nvl(v_dias_sobregiro, 0) >= 91 AND nvl(v_dias_sobregiro, 0) <= 180 THEN
            v_item := '240';
         ELSIF nvl(v_dias_sobregiro, 0) >= 181 THEN
            v_item := '260';
         END IF;

         /* Se anula
         IF V_TIP_PERSONA <> 'J' then
           V_ACTIVIDAD := 504; --OTROS (COMERCIO AL POR MENOR)--
         end if;*/

         pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, p_oficina,
                     v_departamento, v_cod_moneda, v_actividad, v_sal_cap, v_sal_cap);

         -- Genera los codeudores de la cuenta --------------------------
         IF v_sal_cap <> 0 THEN

            --- Solo se genera si tiene deuda el deudor
            pr_gen_gar_codeu(p_nro_cuenta, p_cod_persona, v_garan, v_sal_cap, v_tip_identif,
                             v_nro_identif, v_plazo, p_oficina, v_departamento, v_cod_moneda);
         END IF;

         -- Genera el 4to archivo: CONSUMOS
         -- Agregar solo operaciones de consumos ----------------------
         -- Segun Julio (mail) no corresponde... para 100, 110, 114

         /*IF (V_ACTIVIDAD = '701' and
            V_ITEM not in ('440', '770', '780', '270', '280', '450')) THEN
           PR_INS_CONSUMOS(P_NRO_CUENTA,
                           P_COD_PERSONA,
                           V_TIP_IDENTIF,
                           V_NRO_IDENTIF);
         END IF;*/

         --------------------------------------------------------------
      END IF;

   EXCEPTION
      WHEN no_data_found THEN
         NULL;
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Gen. Mesa de Dinero ' || p_nro_cuenta || '-' || SQLERRM);
   END;
   ------------------------------------------------------------------------------------------
   /* Generar garantes/codeudores. */
   PROCEDURE pr_gen_gar_codeu
   (
      p_nro_cuenta    IN VARCHAR2,
      p_cod_persona   IN VARCHAR2,
      p_mto_garan     IN NUMBER,
      p_sal_cap       IN NUMBER,
      p_tip_ide_deu   IN VARCHAR2,
      p_nro_ide_deu   IN VARCHAR2,
      p_plazo         IN VARCHAR2,
      p_oficina       IN NUMBER,
      p_sector        IN VARCHAR2,
      p_cod_moneda    IN VARCHAR2,
      p_cod_actividad IN VARCHAR2 DEFAULT NULL
   ) IS
      v_cod_persona   VARCHAR2(10);
      v_relacion      VARCHAR2(01);
      v_tip_ide_codeu VARCHAR2(03);
      v_nro_ide_codeu VARCHAR2(15);
      v_item          VARCHAR2(3) := '440'; --0000000'; ERA DE 10 AHORA ES DE 3
      v_garan         NUMBER(15, 2) := 0;
      v_tot_tc        NUMBER(15, 2) := 0;
      v_tot_dc        NUMBER(15, 2) := 0;
      v_tot_tr        NUMBER(15, 2) := 0;
      v_tot_dr        NUMBER(15, 2) := 0;
      v_tot_er        NUMBER(15, 2) := 0;
      v_tot_sr        NUMBER(15, 2) := 0;
      v_tot_ctr_cred  NUMBER(15, 2) := 0;
      v_tot_ctr_ries  NUMBER(15, 2) := 0;
      v_actividad     NUMBER(3);
      v_tip_vinculo   sb_vinculos_det.tip_vinculo%TYPE;
      v_existe        VARCHAR2(1);
      v_clasif        NUMBER(3, 2);

      CURSOR relaciones IS
         SELECT a.cod_persona, relacion, nvl(nvl(p_cod_actividad, cod_actividad), 504) actividad
           FROM ba_personas b, ge_cta_clientes a
          WHERE nro_cuenta = p_nro_cuenta
            AND relacion NOT IN ('P', 'A', 'D') --- Tarjetas adicionales no se informan
            AND a.cod_persona <> p_cod_persona
            AND a.cod_persona = b.cod_persona;

      -- Modificado según documentación de control de cambios del AP 1939 a pedido de Clara Garcia.
      CURSOR esposos IS
         SELECT b.cod_persona, 'C', nvl(cod_actividad, 504)
           FROM ba_personas b, ba_vinculos v
          WHERE v.cod_persona = p_cod_persona
            AND v.tipo = 'E'
            AND fug_obt_pardinamico('CRC_DAT_CONYUGES') = 'S'
            AND v.cod_per_vinculo = b.cod_persona
            AND v.cod_per_vinculo NOT IN
                (SELECT cod_persona
                   FROM ge_cta_clientes
                  WHERE relacion NOT IN ('P', 'A', 'D')
                    AND nro_cuenta = p_nro_cuenta)
         UNION
         SELECT b.cod_persona, 'C', nvl(cod_actividad, 504)
           FROM ba_personas b, ba_vinculos v
          WHERE v.cod_per_vinculo = p_cod_persona
            AND v.tipo = 'E'
            AND fug_obt_pardinamico('CRC_DAT_CONYUGES') = 'S'
            AND v.cod_persona = b.cod_persona
            AND v.cod_persona NOT IN (SELECT cod_persona
                                        FROM ge_cta_clientes
                                       WHERE relacion NOT IN ('P', 'A', 'D')
                                         AND nro_cuenta = p_nro_cuenta);
      -- ORDER BY COD_MODULO;
      --and exists (select c.cod_persona from ge_clietnes c where a.cod_persona = c.cod_persona)--para probar en brios
   BEGIN
      IF relaciones%ISOPEN THEN
         CLOSE relaciones;
      END IF;
      OPEN relaciones;
      LOOP
         FETCH relaciones
            INTO v_cod_persona, v_relacion, v_actividad;
         EXIT WHEN relaciones%NOTFOUND;
         --- cargo las variables para la generacion del cliente ----------
         v_garan := p_mto_garan;
         --
         v_tot_tc := 0;
         v_tot_dc := 0;
         v_tot_tr := 0;
         v_tot_dr := 0;
         v_tot_er := 0;
         v_tot_sr := p_sal_cap;
         v_cat    := NULL;
         --
         v_tot_ctr_cred := nvl(v_tot_tc, 0) + nvl(v_tot_dc, 0);
         v_tot_ctr_ries := nvl(v_tot_tr, 0) + nvl(v_tot_dr, 0) + nvl(v_tot_er, 0) +
                           nvl(v_tot_sr, 0);
         --genero o actualizo registro en a_personas -------------------
         pr_ins_personas(v_cod_persona, v_garan, v_tot_tc, v_tot_dc, v_tot_tr, v_tot_dr, v_tot_er,
                         v_tot_sr, v_tot_ctr_cred, v_tot_ctr_ries, v_tip_ide_codeu, v_nro_ide_codeu,
                         v_cat);
         -- genero el registro en c_items ------------------------------
         pr_ins_item(v_cod_persona, v_tip_ide_codeu, v_nro_ide_codeu, v_item, p_plazo, p_oficina,
                     p_sector, p_cod_moneda, v_actividad, 0, p_sal_cap);
         --Genero registro en la tabla de vinculos ---------------------
         IF v_relacion = 'C' THEN
            v_tip_vinculo := 2;
         ELSE
            v_tip_vinculo := 4;
         END IF;
         pr_ins_vinculos --OJO VER ORDEN DEU CODEU
         (v_tip_ide_codeu, v_nro_ide_codeu, v_cod_persona, p_tip_ide_deu, p_nro_ide_deu,
          p_cod_persona, v_tip_vinculo);
         ---------------------------------------------------------------
         --VER SI GENERAR EL 4TO ARCHIVO TAMBIEN X LOS GARANTES
         --??????????????????????????????????????
      END LOOP;
      --Verificar si la persona es fisica y casada
      BEGIN
         SELECT 'S'
           INTO v_existe
           FROM ba_personas per, ba_per_fisicas fis
          WHERE per.cod_persona = p_cod_persona
            AND per.cod_persona = fis.cod_persona
            AND fis.est_civil = 'C'
            AND fis.cod_persona = p_cod_persona;
      EXCEPTION
         WHEN no_data_found THEN
            v_existe := 'N';
      END;
      IF v_existe = 'S' THEN
         IF esposos%ISOPEN THEN
            CLOSE esposos;
         END IF;
         OPEN esposos;
         LOOP
            FETCH esposos
               INTO v_cod_persona, v_relacion, v_actividad;
            EXIT WHEN esposos%NOTFOUND;
            --- cargo las variables para la generacion del cliente ----------
            v_garan := p_mto_garan;
            --
            v_tot_tc := 0;
            v_tot_dc := 0;
            v_tot_tr := 0;
            v_tot_dr := 0;
            v_tot_er := 0;
            v_tot_sr := p_sal_cap;
            --
            v_tot_ctr_cred := nvl(v_tot_tc, 0) + nvl(v_tot_dc, 0);
            v_tot_ctr_ries := nvl(v_tot_tr, 0) + nvl(v_tot_dr, 0) + nvl(v_tot_er, 0) +
                              nvl(v_tot_sr, 0);
            --Obtener la categoria del titular
            BEGIN
               SELECT fup_obt_categoria(nvl(cat_automatica, 1), nvl(cat_subjetiva, 1))
                 INTO v_cat
                 FROM ge_clientes cl
                WHERE cl.cod_persona = p_cod_persona;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cat := NULL;
            END;

            --genero o actualizo registro en a_personas -------------------
            pr_ins_personas(v_cod_persona, v_garan, v_tot_tc, v_tot_dc, v_tot_tr, v_tot_dr,
                            v_tot_er, v_tot_sr, v_tot_ctr_cred, v_tot_ctr_ries, v_tip_ide_codeu,
                            v_nro_ide_codeu, v_cat);
            -- genero el registro en c_items ------------------------------
            pr_ins_item(v_cod_persona, v_tip_ide_codeu, v_nro_ide_codeu, v_item, p_plazo, p_oficina,
                        p_sector, p_cod_moneda, v_actividad, 0, p_sal_cap);
            --Genero registro en la tabla de vinculos ---------------------
            IF v_relacion = 'C' THEN
               v_tip_vinculo := 2;
            ELSE
               v_tip_vinculo := 4;
            END IF;
            pr_ins_vinculos --OJO VER ORDEN DEU CODEU
            (v_tip_ide_codeu, v_nro_ide_codeu, v_cod_persona, p_tip_ide_deu, p_nro_ide_deu,
             p_cod_persona, v_tip_vinculo);
            ---------------------------------------------------------------
            --VER SI GENERAR EL 4TO ARCHIVO TAMBIEN X LOS GARANTES
            --??????????????????????????????????????
         END LOOP;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Gen. Codeu./Gar. Cliente ' || p_cod_persona || '-' || SQLERRM);
   END;
   /* Insertar items. */
   PROCEDURE pr_ins_item
   (
      p_cod_persona  IN VARCHAR2,
      p_tip_identif  IN VARCHAR2,
      p_nro_identif  IN VARCHAR2,
      p_item         IN VARCHAR2,
      p_plazo        IN NUMBER,
      p_oficina      IN NUMBER,
      p_departamento IN NUMBER,
      p_cod_moneda   IN VARCHAR2,
      p_actividad    IN NUMBER,
      p_mto_item     IN NUMBER,
      p_mto_riesgo   IN NUMBER
   ) IS

      /* Recupera el codigo correspondiente a la moneda para el BCP. */
      FUNCTION lf_obt_mone_bcp(p_cod_moneda IN VARCHAR2) RETURN NUMBER;
      v_cod_moneda_it NUMBER(04);

      /* Recupera el codigo correspondiente a la moneda para el BCP. */
      FUNCTION lf_obt_mone_bcp(p_cod_moneda IN VARCHAR2) RETURN NUMBER IS
         v_moneda NUMBER(04);
      BEGIN
         /* BUSCA DATOS EN EL ARCHIVO DE MONEDA */
         SELECT cod_mon_bco_central INTO v_moneda FROM ba_monedas WHERE cod_moneda = p_cod_moneda;
         RETURN v_moneda;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'No existe Moneda ' || p_cod_moneda);
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Recup. Moneda BCP ' || SQLERRM);
      END;
   BEGIN
      -- Busco la moneda B.C.P para la moneda de la cuenta -------
      v_cod_moneda_it := lf_obt_mone_bcp(p_cod_moneda);
      -- Trato de actualizar el registro de items ---------------
      UPDATE sb_items_det
         SET mto_item   = nvl(mto_item, 0) + nvl(p_mto_item, 0),
             mto_riesgo = nvl(mto_riesgo, 0) + nvl(p_mto_riesgo, 0)
       WHERE cod_persona = p_cod_persona
         AND cod_item = p_item
         AND cod_plazo = p_plazo
         AND cod_region = nvl(p_departamento, 10)
         AND cod_actividad = nvl(p_actividad, 606)
         AND cod_moneda = v_cod_moneda_it
         AND fecha = v_fec_actual;
      IF SQL%NOTFOUND THEN
         -- Inserto el registro en la tabla de items ---------------
         INSERT INTO sb_items_det
            (nom_archivo, fecha, nro_registro, tip_formulario, tip_identificador, nro_identificador,
             cod_item, cod_plazo, cod_region, cod_actividad, cod_moneda, mto_item, mto_riesgo,
             cod_persona)
         VALUES
            ('ITEMS', v_fec_actual, fu_obt_sgte_reg_crc(3, v_fec_actual), 8, p_tip_identif,
             p_nro_identif, p_item, p_plazo, nvl(p_departamento, 10), nvl(p_actividad, 606),
             v_cod_moneda_it, p_mto_item, p_mto_riesgo, p_cod_persona);
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Ins.Item ' || p_cod_persona || '-' || SQLERRM);
   END;
   /* Insertar vinculos. */
   PROCEDURE pr_ins_vinculos
   (
      p_tip_ide_codeu IN VARCHAR2,
      p_nro_ide_codeu IN VARCHAR2,
      p_cod_per_codeu IN VARCHAR2,
      p_tip_ide_deu   IN VARCHAR2,
      p_nro_ide_deu   IN VARCHAR2,
      p_cod_per_deu   IN VARCHAR2,
      p_tip_vinculo   IN VARCHAR2
   ) IS
      v_aux NUMBER;
   BEGIN
      SELECT 0
        INTO v_aux
        FROM sb_vinculos_det
       WHERE cod_per_deudor = p_cod_per_deu
         AND cod_per_codeudor = p_cod_per_codeu
         AND fecha = v_fec_actual;
   EXCEPTION
      WHEN no_data_found THEN
         --- inserto el registro en vinculos si no existe ------------
         INSERT INTO sb_vinculos_det
            (nom_archivo, fecha, nro_registro, tip_formulario, tip_ide_deudor, nro_ide_deudor,
             tip_ide_codeudor, nro_ide_codeudor, tip_vinculo, cod_per_deudor, cod_per_codeudor)
         VALUES
            ('VINCULOS', v_fec_actual, fu_obt_sgte_reg_crc(2, v_fec_actual), 7, p_tip_ide_deu,
             p_nro_ide_deu, p_tip_ide_codeu, p_nro_ide_codeu, p_tip_vinculo, p_cod_per_deu,
             p_cod_per_codeu);
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Generar Vinculos ' || p_cod_per_deu || '-' || SQLERRM);
   END;
   /* Insertar personas_crc. */
   PROCEDURE pr_ins_personas
   (
      p_cod_persona  IN VARCHAR2,
      p_mto_garan    IN NUMBER,
      p_tot_tc       IN NUMBER,
      p_tot_dc       IN NUMBER,
      p_tot_tr       IN NUMBER,
      p_tot_dr       IN NUMBER,
      p_tot_er       IN NUMBER,
      p_tot_sr       IN NUMBER,
      p_tot_ctr_cred IN NUMBER,
      p_tot_ctr_ries IN NUMBER,
      p_tip_identif  IN OUT VARCHAR2,
      p_nro_identif  IN OUT VARCHAR2,
      p_clasif       IN NUMBER DEFAULT 1
   ) IS

      /* Recupera el apellido del conyuge de la persona. */
      FUNCTION lf_obt_ape_conyuge(p_cod_persona IN VARCHAR2) RETURN VARCHAR2;
      v_tip_perso   ba_personas.tipo%TYPE; -- Si es Fisica, Casada o Jur.
      v_pri_ape     ba_per_juridicas.raz_social%TYPE; -- Primer apellido
      v_seg_ape     ba_per_fisicas.seg_apellido%TYPE; -- Segundo apellido o materno
      v_ape_conyu   ba_per_fisicas.pri_apellido%TYPE; -- Apellido del conyuge.
      v_pri_nom     ba_per_juridicas.raz_social%TYPE; -- Primer nombre de la persona
      v_seg_nom     ba_per_fisicas.seg_nombre%TYPE; -- Seg. nombre de la persona
      v_sigla       ba_per_fisicas.fec_nacimiento%TYPE; -- Fecha de Nac. si es P.F.
      v_gru_eco     ge_clientes.cod_gru_economico%TYPE; -- Grupo economico de la pers.
      v_clasif      NUMBER(3, 2);
      v_por_previ   NUMBER(5, 2);
      v_nro_identif ba_personas.nro_documento%TYPE;
      v_est_civil   VARCHAR2(01);
      --OJO VER ESTAS VARIABLES
      vq_pri_ape ba_per_juridicas.raz_social%TYPE;
      vq_seg_ape ba_per_fisicas.seg_apellido%TYPE;
      vq_pri_nom ba_per_juridicas.raz_social%TYPE;
      vq_seg_nom ba_per_fisicas.seg_nombre%TYPE;

      /* Recupera el apellido del conyuge de la persona. */
      FUNCTION lf_obt_ape_conyuge(p_cod_persona IN VARCHAR2) RETURN VARCHAR2 IS
         v_apellido ba_per_fisicas.pri_apellido%TYPE := NULL;
      BEGIN
         SELECT pri_apellido
           INTO v_apellido
           FROM ba_per_fisicas a, ba_vinculos b
          WHERE a.cod_persona = b.cod_per_vinculo
            AND b.cod_persona = p_cod_persona
            AND tipo = 'E'
            AND rownum = 1;
         RETURN v_apellido;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN v_apellido;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Recup.Conyuge de Cliente ' || p_cod_persona);
      END;
      /* Obtener la categoría de previsión de clientes para categoría 1(Uno). Resolución N°37*/
      FUNCTION lf_obt_cat_prevision(p_cod_persona IN ge_cla_operaciones.cod_persona%TYPE)
         RETURN NUMBER AS
         v_categoria ge_cla_operaciones.cat_automatica%TYPE;
      BEGIN
         --Verifico las operaciones que posee el cliente.
         SELECT nvl(MAX(a.cat_automatica), 1)
           INTO v_categoria
           FROM ge_cla_operaciones a
          WHERE a.cod_persona = p_cod_persona;
         RETURN v_categoria;
      EXCEPTION
         WHEN OTHERS THEN
            v_categoria := 1;
            RETURN v_categoria;
      END;
      --
   BEGIN
      -- trato de actualizar si ya existe un registro en A_PERSONAS--
      --esto se hace x cta cte, prestamos y tarjeta, y deudores/garantes -> ya puede existir la persona
      UPDATE sb_personas_crc_det
         SET mto_gar_cobertura = nvl(mto_gar_cobertura, 0) + nvl(p_mto_garan, 0), --MTO_GAR_COBERTURA
             tot_tc            = nvl(tot_tc, 0) + nvl(p_tot_tc, 0),
             tot_dc            = nvl(tot_dc, 0) + nvl(p_tot_dc, 0),
             tot_tr            = nvl(tot_tr, 0) + nvl(p_tot_tr, 0),
             tot_dr            = nvl(tot_dr, 0) + nvl(p_tot_dr, 0),
             tot_er            = nvl(tot_er, 0) + nvl(p_tot_er, 0),
             tot_sr            = nvl(tot_sr, 0) + nvl(p_tot_sr, 0),
             tot_ctr_cred      = nvl(tot_ctr_cred, 0) + nvl(p_tot_ctr_cred, 0),
             tot_ctr_ries      = nvl(tot_ctr_ries, 0) + nvl(p_tot_ctr_ries, 0)
       WHERE cod_persona = p_cod_persona
         AND fecha = v_fec_actual;
      -- Si no existe, veo si es una persona que ya se reporto ----
      --VC: esto es ver si esta la persona en cualquier fecha, para no volver a armar los datos
      IF SQL%NOTFOUND THEN
         --NO ENCONTRO X CLIENTE Y FECHA, VER SI EXISTE EL CLIENTE
         BEGIN
            SELECT tip_identificador,
                   nro_identificador,
                   tip_persona,
                   pri_apellido,
                   seg_apellido,
                   ape_conyuge,
                   pri_nombre,
                   seg_nombre,
                   sigla_fecha,
                   cod_gru_economico
              INTO p_tip_identif,
                   p_nro_identif,
                   v_tip_perso,
                   v_pri_ape,
                   v_seg_ape,
                   v_ape_conyu,
                   v_pri_nom,
                   v_seg_nom,
                   v_sigla,
                   v_gru_eco
              FROM sb_personas_crc_det --SB_PERSONAS_CRC es tipo la cabecera,pero no es igual
             WHERE cod_persona = p_cod_persona --tiene cod_cliente y datos persona
               AND fecha = v_fec_actual;
         EXCEPTION
            WHEN no_data_found THEN
               -- Modificado según documentación de control de cambios del AP 1939 a pedido de Clara Garcia.
               -- nunca reportamos esta persona, se debe armar datos --
               BEGIN
                  SELECT pf.tip_documento,
                         pf.nro_documento,
                         decode(pf.tip_persona, 'F', decode(pf.est_civil, 'C', 3, 2), 'J', 1),
                         decode(pf.tip_persona, 'F', pf.pri_apellido, 'J', pf.raz_social),
                         decode(pf.tip_persona, 'F', pf.seg_apellido),
                         decode(pf.tip_persona, 'F', pf.pri_nombre),
                         decode(pf.tip_persona, 'F', pf.seg_nombre),
                         decode(pf.tip_persona, 'F', trunc(pf.fec_nacimiento), 'J',
                                trunc(pf.fec_apertura)),
                         -- Requerimiento: CNFAIRUNO-3.         
                         -- Fecha: 22/09/2014.
                         NVL((SELECT MAX(bc.val_minimo) FROM ba_cod_referencias bc WHERE bc.dominio = 'GRU_ECO_BCP' AND bc.val_maximo = nvl(cl.cod_gru_economico,0)), nvl(cl.cod_gru_economico,0)) gru_economico,
                         decode(pf.tip_persona, 'F', pf.est_civil),
                         fup_obt_categoria(nvl(cat_automatica, 0), nvl(cat_subjetiva, 0)),
                           nvl(decode(nvl(fup_obt_categoria(nvl(cat_automatica, 1), nvl(cat_subjetiva, 1)), 1),
                           1, 0, 2, pas_crc.rv_param.por_riesgo_2, 3, pas_crc.rv_param.por_riesgo_3,
                           4, pas_crc.rv_param.por_riesgo_4, 5, pas_crc.rv_param.por_riesgo_5,
                           6, pas_crc.rv_param.por_riesgo_6), 0)
                    INTO p_tip_identif,
                         p_nro_identif,
                         v_tip_perso, --1,2,3
                         vq_pri_ape,
                         vq_seg_ape,
                         vq_pri_nom,
                         vq_seg_nom,
                         v_sigla,
                         v_gru_eco,
                         v_est_civil,
                         v_clasif,
                         v_por_previ
                    FROM sb_per_crc pf, ge_clientes cl
                   WHERE pf.cod_persona = cl.cod_persona(+)
                     AND pf.cod_persona = p_cod_persona;
                  --------------------------------------------------------
                  -- Modificado según documentación de control de cambios del AP 1939 a pedido de Clara Garcia.
                  -- COMPARO CONTRA LA TABLA PERSONAS_REF.
                 /* BEGIN
                     IF v_tip_perso = 1 THEN
                        SELECT pr.rf_nombre
                          INTO vq_pri_ape
                          FROM personas_ref pr
                         WHERE pr.rf_tipo_ident = p_tip_identif
                           AND pr.rf_numero = p_nro_identif;
                     ELSE
                        BEGIN
                           SELECT pr.rf_apellido, pr.rf_nombre
                             INTO vq_pri_ape, vq_pri_nom
                             FROM personas_ref pr
                            WHERE pr.rf_tipo_ident = p_tip_identif
                              AND pr.rf_numero = p_nro_identif
                              AND pr.rf_fecha_nac = v_sigla;
                        EXCEPTION
                           WHEN OTHERS THEN
                              SELECT pr.rf_apellido, pr.rf_nombre, pr.rf_fecha_nac
                                INTO vq_pri_ape, vq_pri_nom, v_sigla
                                FROM personas_ref pr
                               WHERE pr.rf_tipo_ident = p_tip_identif
                                 AND pr.rf_numero = p_nro_identif
                                 AND (CASE
                                        WHEN instr(pr.rf_apellido, ' ') > 0 THEN
                                         TRIM(substr(pr.rf_apellido, 1, instr(pr.rf_apellido, ' ') - 1))
                                        ELSE
                                         TRIM(pr.rf_apellido)
                                     END) = TRIM(vq_pri_ape);
                        END;
                     END IF;

                     vq_seg_ape := NULL;
                     vq_seg_nom := NULL;

                  EXCEPTION
                     WHEN OTHERS THEN
                        NULL;
                  END;*/
                  --------------------------------------------------------
                  -- REALIZA TODOS LOS CALCULOS ANTES DE INSERTAR EN ARCHIVO DE A_PERSONAS_A                            --
                  -- VARIABLES CARGADAS DESDE EL SELECT ANTERIOR O ESTE
                  IF v_est_civil = 'C' THEN
                     v_ape_conyu := lf_obt_ape_conyuge(p_cod_persona);
                  END IF;
                  v_pri_ape   := substr(vq_pri_ape || ' ' || vq_seg_ape, 1, 30);
                  v_pri_nom   := vq_pri_nom || ' ' || vq_seg_nom;
                  v_pri_ape   := nvl(TRIM(v_pri_ape), ' ');
                  v_pri_nom   := nvl(TRIM(v_pri_nom), ' ');
                  v_seg_ape   := NULL;
                  v_seg_nom   := NULL;
                  v_ape_conyu := NULL;
                  IF v_tip_perso = 1 THEN
                     --juridica
                     v_pri_ape := NULL;
                     v_pri_nom := TRIM(vq_pri_ape);
                     v_seg_ape := NULL;
                     v_seg_nom := NULL;
                     v_sigla   := NULL;
                     --ELSE
                     --  V_SEG_NOM := SUBSTR(VQ_SEG_NOM,1,15);
                  END IF;
               EXCEPTION
                  WHEN no_data_found THEN
                     raise_application_error(-20000, 'No existe Persona ' || p_cod_persona);
                  WHEN OTHERS THEN
                     raise_application_error(-20000,
                                             'Recup. Persona ' || p_cod_persona || '-' || SQLERRM);
               END;
            WHEN OTHERS THEN
               raise_application_error(-20000,
                                       'Generar Personas_Crc_Det ' || p_cod_persona || '-' ||
                                        SQLERRM);
         END;
         --------------------------------------------------------
         -- INSERTA EL REGISTRO EN EL AUXILIAR DE A_PERSONAS_A --
         --------------------------------------------------------
         --Tomar los nuevos porcentajes de Previsión para las categorías 1.1 y 1.2
         IF v_clasif = 1 THEN
            v_clasif    := lf_obt_cat_prevision(p_cod_persona);
            v_por_previ := (Case when v_clasif = 1.1 then  PAS_CRC.RV_PARAM.POR_RIESGO_1a
                                 when v_clasif > 1.1 then  PAS_CRC.RV_PARAM.POR_RIESGO_1b
                            else 0 end);
            IF v_clasif > 1.1 THEN
               v_clasif := 1.2;
            END IF;
            --Verificar si la persona no tiene categoria, toma del conyuge
         ELSIF v_clasif = 0 THEN
            v_clasif := p_clasif;
            IF v_clasif IS NULL THEN
               v_clasif := 1;
            END IF;
            --JF AP 2875
            v_por_previ := (case when nvl(v_clasif, 1) = 1 then 0
                                when nvl(v_clasif, 1) = 2 then pas_crc.rv_param.por_riesgo_2
                                when nvl(v_clasif, 1) = 3 then pas_crc.rv_param.por_riesgo_3
                                when nvl(v_clasif, 1) = 4 then pas_crc.rv_param.por_riesgo_4
                                when nvl(v_clasif, 1) = 5 then pas_crc.rv_param.por_riesgo_5
                                when nvl(v_clasif, 1) = 6 then pas_crc.rv_param.por_riesgo_6
                           else
                                0
                           end);
            --
         END IF;
         --
         INSERT INTO sb_personas_crc_det
            (nom_archivo, fecha, nro_registro, cod_persona, tip_formulario, tip_identificador,
             nro_identificador, tip_persona, pri_apellido, seg_apellido, ape_conyuge, pri_nombre,
             seg_nombre, sigla_fecha, cod_gru_economico, mto_gar_cobertura, tot_tc, tot_dc, tot_tr,
             tot_dr, tot_er, tot_sr, tot_ctr_cred, tot_ctr_ries, cla_rie_entidad, por_prevision)
         VALUES
            ('PERSONAS', v_fec_actual, fu_obt_sgte_reg_crc(1, v_fec_actual), p_cod_persona, 6,
             p_tip_identif, p_nro_identif, v_tip_perso, substr(v_pri_ape, 1, 30),
             substr(v_seg_ape, 1, 15), substr(v_ape_conyu, 1, 15), substr(v_pri_nom, 1, 60),
             substr(v_seg_nom, 1, 15), v_sigla, v_gru_eco, p_mto_garan, p_tot_tc, p_tot_dc, p_tot_tr,
             p_tot_dr, p_tot_er, p_tot_sr, p_tot_ctr_cred, p_tot_ctr_ries, nvl(v_clasif, p_clasif),
             v_por_previ);
      ELSE
         --YA ACTUALIZO CON LOS MONTOS Y DEBE RETORNAR LA IDENTIFICACION
         --- cliente ya fue generado en alguna fecha, se lee su identificacion ---
         SELECT tip_identificador, nro_identificador
           INTO p_tip_identif, p_nro_identif --para retornar
           FROM sb_personas_crc_det
          WHERE cod_persona = p_cod_persona
            AND fecha = v_fec_actual;
         ---------------------------------------------------------
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Ins. Persona ' || p_cod_persona || '-' || SQLERRM);
   END;
   /* Permite generar las tablas de Consumo. */
   PROCEDURE pr_ins_consumos
   (
      p_nro_cuenta  IN VARCHAR2,
      p_cod_persona IN VARCHAR2,
      p_tip_identif IN VARCHAR2,
      p_nro_identif IN VARCHAR2,
      p_mto_tarjeta IN NUMBER DEFAULT 0
   ) IS

      --Variables.
      v_val_tasa     ge_movimientos.val_tasa%TYPE;
      v_fec_vigencia ge_tas_fechas.fec_vigencia%TYPE;
      v_tip_valor    ge_tasas.tip_valor%TYPE;
      v_tip_tasa     ge_tasas.tipo%TYPE;
      v_cod_tasa     ge_tasas.cod_tasa%TYPE := NULL;

      /* Recupera el codigo correspondiente a la moneda para el BCP. */
      FUNCTION lf_obt_mone_bcp(p_cod_moneda IN VARCHAR2) RETURN NUMBER;
      v_tipo          NUMBER(3);
      v_cod_moneda_it NUMBER(4);
      v_pri_vto       DATE;
      v_vto_cuota     DATE;
      v_ult_vto       DATE;
      v_mto_origen    NUMBER;
      v_lineas        NUMBER;

      CURSOR datos IS
      --PRESTAMOS
         SELECT a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                a.nro_cuenta,
                a.cod_moneda,
                (CASE
                   WHEN a.val_tasa <= 0 THEN
                    1
                   ELSE
                    a.val_tasa
                END) tasa,
                (v_fec_actual - min_a_pagar) dia_atraso,
                a.fec_inicio,
                (nvl(a.sal_cap_batch, 0) +
                decode(a.est_batch, 'I', nvl(a.sal_int_batch, 0) + nvl(a.sal_int_ade_batch, 0),
                        nvl(a.dev_no_cobrado, 0))) *
                decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                       pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)) deuda,
                nvl(a.mto_capital, 0) *
                decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                       pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)) mto_origen,
                min_fec pri_vto,
                a.fec_vencimiento ult_vto,
                nvl(a.can_cuo_pagadas, 0) canceladas,
                min_a_pagar vto_cuota,
                saldo * decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                               pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)) mto_atraso,
                a.tipo,
                'N' tas_personalizada
           FROM (SELECT MIN(fec_vencimiento) min_fec, nro_cuenta --primer vto
                   FROM pr_cuotas
                  WHERE nro_cuota > 0
                    AND nro_cuenta = p_nro_cuenta
                  GROUP BY nro_cuenta) b,
                (SELECT MIN(fec_vencimiento) vieja,
                        --JF AP 2875
                        SUM(nvl(sal_capital, 0) +
                            decode(estado, 'I',
                                   nvl(pr_cuotas.sal_interes, 0) +
                                    nvl(pr_cuotas.sal_int_documentado, 0),
                                    (case when nvl(dev_no_cobrado, 0) = 0 and nvl(pr_cuotas.sal_interes, 0) > 0 then
                                          nvl(pr_cuotas.sal_interes, 0)
                                     else
                                          nvl(dev_no_cobrado, 0)
                                     end)
                                    )) saldo,
                        nro_cuenta
                   FROM pr_cuotas
                  WHERE nro_cuota > 0
                    AND estado NOT IN ('N')
                    AND nro_cuenta = p_nro_cuenta
                    AND fec_vencimiento < v_fec_actual
                  GROUP BY nro_cuenta) e,
                (SELECT MIN(fec_vencimiento) min_a_pagar, nro_cuenta
                   FROM pr_cuotas
                  WHERE nro_cuota > 0
                    AND estado NOT IN ('N')
                    AND nro_cuenta = p_nro_cuenta
                  GROUP BY nro_cuenta) f,
                ba_personas h,
                ge_cta_clientes g,
                pr_cta_prestamos a
          WHERE a.nro_cuenta = b.nro_cuenta
            AND a.nro_cuenta = g.nro_cuenta
            AND a.nro_cuenta = p_nro_cuenta
            AND g.cod_persona = h.cod_persona
            AND h.cod_persona = p_cod_persona
            AND g.nro_cuenta = p_nro_cuenta
            AND g.cod_persona = p_cod_persona
            AND h.tipo = 'F'
            AND a.nro_cuenta = e.nro_cuenta(+)
            AND a.nro_cuenta = f.nro_cuenta
            AND nvl(a.est_batch, 'N') NOT IN ('N', 'X')
         UNION
         --TARJETAS
         SELECT a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                a.nro_cuenta,
                a.cod_moneda,
                nvl(decode(tas_financiacion, 0, tas_cuotas, tas_financiacion), tas_cuotas) tasa,
                dia_mora dia_atraso,
                fec_apertura fec_inicio,
                p_mto_tarjeta deuda,
                decode(a.estado,'B',p_mto_tarjeta,(nvl(a.lin_credito, 0) + decode(v_tip_implementacion, 2, nvl(a.lin_cuotas, 0), 0))) * ---ICL 10/04/2012
                decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                       pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)) mto_origen,
                NULL pri_vto,
                NULL ult_vto,
                0 canceladas,
                NULL vto_cuota,
                mto_mora * decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)) mto_atraso,
                to_char(NULL) tipo,
                'N'
           FROM ba_personas h, ge_cta_clientes g, ta_cta_tarjetas a
          WHERE a.nro_cuenta = g.nro_cuenta
            AND a.nro_cuenta = p_nro_cuenta
            AND h.cod_persona = p_cod_persona
            AND g.nro_cuenta = p_nro_cuenta
            AND g.cod_persona = p_cod_persona
            AND g.cod_persona = h.cod_persona
            AND h.tipo = 'F'
            AND a.cod_modalidad != 55
           and ((a.estado not in ('C', 'B')) or (a.estado='B' and nvl(a.sal_procesadora, 0) > 0)) -- ICL 10/04/2012
         UNION
         --SOBREGIROS CTAS CTES
         SELECT a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                a.nro_cuenta,
                a.cod_moneda,

                 (CASE
                   WHEN fug_obt_val_tasa(a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta,
                                 a.cod_moneda, 0, 'N', NULL, 550, v_fec_actual) <= 0 THEN
                    1
                   ELSE
                     fug_obt_val_tasa(a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta,
                                 a.cod_moneda, 0, 'N', NULL, 550, v_fec_actual)
                END) tasa,

                dias_sobregiro dia_atraso,
                fec_apertura fec_inicio,

                case when (nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)) >=0 then 0
                else
                   abs(nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)) *
                   decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                   pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual))
                end deuda,

                case when nvl(a.cod_ente,-1) = -1 and (nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)) < 0 then
                    abs(nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)) *
                    decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                    pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual))
                when nvl(a.cod_ente,-1) <> -1 and abs(nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)) > nvl(g.monto,0)
                    and (nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)) < 0 then
                    abs(nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)) *
                    decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                    pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual))
                else
                    nvl(g.monto,0) *
                    decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                    pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual))
                end mto_origen,

                v_fec_actual pri_vto,
                v_fec_actual ult_vto,
                0 canceladas,
                v_fec_actual vto_cuota,

                case when (nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)) >=0 then 0
                else
                   abs(nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)) *
                   decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                   pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual))
                end  mto_atraso,

                to_char(NULL) tipo,
                a.tas_personalizada
           FROM ge_clientes d,
                ba_personas h,
                ge_cta_clientes b,
                (SELECT decode(can_dias, 0, 1, can_dias) dias_sobregiro, nro_cuenta   --AP 2875
                   FROM cc_sobregiros_res
                  WHERE nro_cuenta = p_nro_cuenta) f,
                (SELECT SUM(nvl(monto, 0)) monto, nro_cuenta
                   FROM cc_lin_sobregiros
                  WHERE nro_cuenta = p_nro_cuenta
                    and estado = 'A' -- ICL 10/04/2012 Unificado con conceptos de Contabilidad
                  GROUP BY nro_cuenta) g,
                cc_cta_corrientes a
          WHERE a.nro_cuenta = b.nro_cuenta
            AND a.nro_cuenta = p_nro_cuenta
            AND b.cod_persona = d.cod_persona
            AND d.cod_persona = p_cod_persona
            AND h.cod_persona = p_cod_persona
            AND b.nro_cuenta = p_nro_cuenta
            AND b.cod_persona = p_cod_persona
            AND d.cod_persona = h.cod_persona
            AND h.tipo = 'F'
            AND a.est_batch NOT IN ('A', 'C', 'X')
            AND a.nro_cuenta = f.nro_cuenta(+)
            AND a.nro_cuenta = g.nro_cuenta(+)
            AND relacion = 'P'
         UNION
         -- OPERACIONES VENCIDAS.  JF AP 2875
         SELECT ov.cod_modulo,
                ov.cod_modalidad,
                ov.cod_oficina,
                ov.nro_cuenta,
                ov.cod_moneda,
                nvl(ov.val_tasa,0) tasa,
                ov.dia_atraso dia_atraso,
                ov.fec_apertura fec_inicio,
                ov.sal_total deuda,
                ov.mto_origen * decode(ov.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(ov.cod_moneda, v_fec_actual)) mto_origen,
                NULL pri_vto,
                NULL ult_vto,
                0 canceladas,
                NULL vto_cuota,
                ov.sal_total * decode(ov.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(ov.cod_moneda, v_fec_actual)) mto_atraso,
                to_char(NULL) tipo,
                'N'
           FROM ba_personas h, ge_cta_clientes g, ov_cta_vencidas ov
          WHERE ov.nro_cuenta = g.nro_cuenta
            AND ov.nro_cuenta = p_nro_cuenta
            AND h.cod_persona = p_cod_persona
            AND g.nro_cuenta = p_nro_cuenta
            AND g.cod_persona = p_cod_persona
            AND g.cod_persona = p_cod_persona
            AND g.cod_persona = h.cod_persona
            AND h.tipo = 'F'
            AND g.relacion = 'P'
            AND ov.estado NOT IN ('C');

      /* Recupera el codigo correspondiente a la moneda para el BCP. */
      FUNCTION lf_obt_mone_bcp(p_cod_moneda IN VARCHAR2) RETURN NUMBER IS
         v_moneda NUMBER(04);
      BEGIN
         /* BUSCA DATOS EN EL ARCHIVO DE MONEDA */
         SELECT cod_mon_bco_central INTO v_moneda FROM ba_monedas WHERE cod_moneda = p_cod_moneda;
         RETURN v_moneda;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'No existe Moneda ' || p_cod_moneda);
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Recup. Moneda BCP ' || SQLERRM);
      END;

   BEGIN
      FOR reg IN datos LOOP
         --SE SUPONE UN SOLO REGISTRO
         v_pri_vto    := NULL;
         v_vto_cuota  := NULL;
         v_ult_vto    := NULL;
         v_mto_origen := nvl(reg.mto_origen, 0);
         IF nvl(reg.dia_atraso, 0) < 0 THEN
            reg.dia_atraso := 0;
         END IF;
         --determina tipo operacion
         IF reg.cod_modulo = 5 THEN
            v_tipo      := 205;
            v_vto_cuota := v_fec_actual - nvl(reg.dia_atraso, 0);
            --- Hallar el monto de contingencia
            IF reg.deuda > 0 AND reg.deuda > nvl(reg.mto_origen, 0) THEN
               v_mto_origen := reg.deuda;
            END IF;
         ELSIF reg.cod_modulo = 4 THEN
            -- Ctas. Ctes.
            v_tipo      := 189;
            v_vto_cuota := nvl(reg.ult_vto, v_fec_actual) - nvl(reg.dia_atraso, 0);
            IF reg.tasa IS NULL THEN
               pag_gen.pr_obt_val_tasa(reg.cod_modulo, reg.cod_modalidad, reg.cod_oficina,
                                       reg.nro_cuenta, reg.cod_moneda, reg.deuda,
                                       reg.tas_personalizada, v_cod_tasa, 550, v_fec_actual,
                                       -- OUT
                                       v_val_tasa, v_fec_vigencia, v_tip_valor, v_tip_tasa);
            END IF;
         ELSIF reg.cod_modulo = 6 THEN
            v_pri_vto   := reg.pri_vto;
            v_vto_cuota := reg.vto_cuota;
            v_ult_vto   := reg.ult_vto;
            IF reg.tipo = 'A' THEN
               v_tipo := 173;
            ELSIF reg.tipo = 'P' THEN
               v_tipo := 169;
            ELSIF reg.tipo = 'D' THEN
               v_tipo := 351;
            END IF;
         ELSIF reg.cod_modulo = 15 THEN --JF AP 2875
            reg.fec_inicio := v_fec_actual - nvl(reg.dia_atraso, 0);
            v_vto_cuota    := reg.fec_inicio;
            IF reg.cod_modalidad = 151 then
               v_tipo := 205;
            ELSIF reg.cod_modalidad = 152 then
               v_tipo := 189;
            END IF;
            IF reg.tasa = 0 THEN
               reg.tasa := 1;
            END IF;
         END IF;
         -- Busco la moneda B.C.P para la moneda de la cuenta -------
         v_cod_moneda_it := lf_obt_mone_bcp(reg.cod_moneda);
         -- Trato de actualizar el registro de items ---------------
         BEGIN
            UPDATE sb_consumos_det
               SET mto_ori_credito         = v_mto_origen,
                   fec_operacion           = reg.fec_inicio,
                   cod_moneda              = v_cod_moneda_it,
                   tas_interes             = reg.tasa,
                   fec_pri_vencimiento     = v_pri_vto,
                   fec_vto_cuo_pen_antigua = (CASE
                                                WHEN reg.deuda = 0 THEN
                                                 v_fec_actual
                                                ELSE
                                                 v_vto_cuota
                                             END),
                   fec_ult_vencimiento     = v_ult_vto,
                   dia_atraso = (CASE
                                   WHEN reg.deuda = 0 THEN
                                    0
                                   ELSE
                                    nvl(reg.dia_atraso, 0)
                                END),
                   nro_cuo_canceladas      = reg.canceladas,
                   sal_deu_cons_activo     = reg.deuda,
                   mto_cuo_atrasadas = (CASE
                                          WHEN reg.deuda = 0 THEN
                                           0
                                          ELSE
                                           nvl(reg.mto_atraso, 0)
                                       END)
             WHERE cod_persona = p_cod_persona
               AND nro_operacion = p_nro_cuenta
               AND tip_operacion = v_tipo
               AND fecha = v_fec_actual;
            IF SQL%NOTFOUND THEN
               -- Inserto el registro en la tabla de items ---------------
               BEGIN
                  /*mensaje_log('ins cons '||V_FEC_ACTUAL||'*'||FU_OBT_SGTE_REG_CRC(4,V_FEC_ACTUAL)||'*'||
                  P_COD_PERSONA||'*'||P_TIP_IDENTIF||'*'||P_NRO_IDENTIF||'*'||REG.NRO_CUENTA||'*'||V_TIPO||'*'||
                  REG.MTO_ORIGEN||'*'||REG.FEC_INICIO||'*'||V_COD_MONEDA_IT||'*'||REG.TASA||'*'||REG.PRI_VTO||'*'||REG.VTO_CUOTA||'*'||
                  REG.ULT_VTO||'*'||REG.DIA_ATRASO||'*'||REG.CANCELADAS||'*'||REG.DEUDA||'*'||REG.MTO_ATRASO);*/
                  INSERT INTO sb_consumos_det
                     (nom_archivo, fecha, nro_registro, cod_persona, tip_formulario,
                      tip_identificador, nro_identificador, nro_operacion, tip_operacion,
                      mto_ori_credito, fec_operacion, cod_moneda, tas_interes, fec_pri_vencimiento,
                      fec_vto_cuo_pen_antigua, fec_ult_vencimiento, dia_atraso, nro_cuo_canceladas,
                      sal_deu_cons_activo, mto_cuo_atrasadas)
                  VALUES
                     ('CONSUMOS', v_fec_actual, fu_obt_sgte_reg_crc(4, v_fec_actual), p_cod_persona,
                      10, p_tip_identif, p_nro_identif, reg.nro_cuenta, v_tipo, v_mto_origen,
                      reg.fec_inicio, v_cod_moneda_it, reg.tasa, v_pri_vto,
                      (CASE
                          WHEN reg.deuda = 0 THEN
                           v_fec_actual
                          ELSE
                           v_vto_cuota
                       END), v_ult_vto,
                      (CASE
                          WHEN reg.deuda = 0 THEN
                           0
                          ELSE
                           nvl(reg.dia_atraso, 0)
                       END), reg.canceladas, reg.deuda,
                      (CASE
                          WHEN reg.deuda = 0 THEN
                           0
                          ELSE
                           nvl(reg.mto_atraso, 0)
                       END));
               EXCEPTION
                  WHEN OTHERS THEN
                     raise_application_error(-20000,
                                             'Ins. Consumos ' || p_nro_cuenta || '-' || SQLERRM);
               END;
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Actu. Consumos ' || p_nro_cuenta || '-' || SQLERRM);
         END;
      END LOOP;
   END;
   /* Devuelve el sgte. nro de registro de la tabla crc. */
   FUNCTION fu_obt_sgte_reg_crc
   (
      p_archivo IN NUMBER,
      p_fecha   IN DATE
   ) RETURN NUMBER IS
      --1 SB_PERSONAS_CRC_DET
      --2 SB_VINCULOS_DET
      --3 SB_ITEMS_DET
      --4 SB_CONSUMOS_DET
      v_nro NUMBER;
   BEGIN
      IF p_archivo = 1 THEN
         SELECT MAX(nro_registro)
           INTO v_nro
           FROM sb_personas_crc_det
          WHERE fecha = trunc(p_fecha)
            AND nom_archivo = 'PERSONAS';
      ELSIF p_archivo = 2 THEN
         SELECT MAX(nro_registro)
           INTO v_nro
           FROM sb_vinculos_det
          WHERE fecha = trunc(p_fecha)
            AND nom_archivo = 'VINCULOS';
      ELSIF p_archivo = 3 THEN
         SELECT MAX(nro_registro)
           INTO v_nro
           FROM sb_items_det
          WHERE fecha = trunc(p_fecha)
            AND nom_archivo = 'ITEMS';
      ELSIF p_archivo = 4 THEN
         SELECT /*+ index (sb_consumos_det SCDET_PK) +*/
          MAX(nro_registro)
           INTO v_nro
           FROM sb_consumos_det
          WHERE fecha = trunc(p_fecha)
            AND nom_archivo = 'CONSUMOS';
      END IF;
      RETURN nvl(v_nro, 0) + 1;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20001, 'ERROR al buscar SGTE.REG.' || SQLERRM);
   END;
   /* Insertar en las tablas cabeceras de crc. */
   PROCEDURE pr_ins_cabecera_crc IS
      v_reg_persona NUMBER;
      v_reg_vinculo NUMBER;
      v_reg_item    NUMBER;
      v_reg_consumo NUMBER;
      v_cod_entidad ge_par_generales.cod_entidad%TYPE;
      v_mto_tope    pr_parametros.cap_min_exigido%TYPE;
   BEGIN
      BEGIN
         SELECT cod_entidad INTO v_cod_entidad FROM ge_par_generales WHERE rownum = 1;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000, 'No existen Param. Entidad');
      END;
      BEGIN
         /*select round(nvl(cap_min_exigido,0)*20/100,0)
         into v_mto_tope
         from pr_parametros;*/
         v_mto_tope := round(nvl(fug_obt_pardinamico('PAT_EFECTIVO', NULL, NULL, NULL, NULL), 0) * 20 / 100,
                             0);
      END;
      --RECUPERAR CANT REGISTROS DETALLES INSERTADOS
      v_reg_persona := fu_obt_sgte_reg_crc(1, v_fec_actual);
      v_reg_vinculo := fu_obt_sgte_reg_crc(2, v_fec_actual);
      v_reg_item    := fu_obt_sgte_reg_crc(3, v_fec_actual);
      v_reg_consumo := fu_obt_sgte_reg_crc(4, v_fec_actual);
      --SI HAY DETALLES INSERTAR CABECERAS
      IF v_reg_persona > 1 THEN
         --INSERTAR PERSONAS_CRC
         INSERT INTO sb_personas_crc
            (nom_archivo, fecha, cod_entidad, tip_entidad, cla_entidad, top_riesgo, nro_reg_a,
             tot_reg_detalle)
         VALUES
            ('PERSONAS', v_fec_actual, v_cod_entidad, '4', '2', v_mto_tope, 0, v_reg_persona - 1);
      END IF;
      IF v_reg_vinculo > 1 THEN
         --INSERTAR VINCULOS
         INSERT INTO sb_vinculos
            (nom_archivo, fecha, cod_entidad, tip_entidad, cla_entidad, nro_reg_a, tot_reg_detalle)
         VALUES
            ('VINCULOS', v_fec_actual, v_cod_entidad, '4', '2', 0, v_reg_vinculo - 1);
      END IF;
      IF v_reg_item > 1 THEN
         --INSERTAR ITEMS
         INSERT INTO sb_items
            (nom_archivo, fecha, cod_entidad, tip_entidad, cla_entidad, nro_reg_a, tot_reg_detalle)
         VALUES
            ('ITEMS', v_fec_actual, v_cod_entidad, '4', '2', 0, v_reg_item - 1);
      END IF;
      IF v_reg_consumo > 1 THEN
         --INSERTAR CONSUMO
         INSERT INTO sb_consumos
            (nom_archivo, fecha, cod_entidad, tip_entidad, cla_entidad, nro_reg_a, tot_reg_detalle)
         VALUES
            ('CONSUMO', v_fec_actual, v_cod_entidad, '4', '2', 0, v_reg_consumo - 1);
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Ins.Cabeceras ' || SQLERRM);
   END;

   PROCEDURE pr_gen_ctaban_crc
   (
      p_modulo      IN cc_cta_corrientes.cod_modulo%TYPE,
      p_modalidad   IN cc_cta_corrientes.cod_modalidad%TYPE,
      p_oficina     IN cc_cta_corrientes.cod_oficina%TYPE,
      p_nro_cuenta  IN cc_cta_corrientes.nro_cuenta%TYPE,
      p_cod_persona IN ge_cta_clientes.cod_persona%TYPE
   ) IS
      v_cod_moneda     VARCHAR2(03);
      v_departamento   NUMBER(03);
      v_plazo          NUMBER(04);
      v_sal_cap        NUMBER(15) := 0;
      v_garan          NUMBER(15) := 0;
      v_fec_aper       DATE;
      v_tip_identif    VARCHAR2(03);
      v_nro_identif    VARCHAR2(15);
      v_mto_gar_cober  NUMBER(15);
      v_total_tc       NUMBER(15);
      v_total_dc       NUMBER(15);
      v_total_tr       NUMBER(15);
      v_total_dr       NUMBER(15);
      v_total_er       NUMBER(15);
      v_total_sr       NUMBER(15);
      v_tot_ctr_cred   NUMBER(15);
      v_tot_ctr_ries   NUMBER(15);
      v_actividad      NUMBER(3);
      v_item           VARCHAR2(3);
      v_dias_sobregiro NUMBER(5);
   BEGIN
      SELECT a.cod_moneda,
             decode(nvl(cod_departamento, 0), 0, 11, cod_departamento),
             fug_obt_plz_contable(0) || 0,
             abs(nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0)) *
             decode(a.cod_moneda, v_cod_mon_local, 1, v_cod_mon_fuerte, v_cot_fuerte,
                    pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)),
             fec_apertura,
             decode(substr(a.cod_rubro, 9, 2), '03', 901, '04', 902, 902) cod_actividad
        INTO v_cod_moneda, v_departamento, v_plazo, v_sal_cap, v_fec_aper, v_actividad
        FROM ge_clientes d, ba_personas e, ge_cta_clientes b, cc_cta_bancarias a
       WHERE a.nro_cuenta = b.nro_cuenta
         AND a.nro_cuenta = p_nro_cuenta
         AND b.cod_persona = d.cod_persona
         AND d.cod_persona = p_cod_persona
         AND d.cod_persona = e.cod_persona
         AND a.est_batch NOT IN ('C', 'X')
         AND relacion = 'P'
         AND nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) > 0;

      ------------------------------------------------------------------
      -- CALCULA EN MILES DE GUARANIES EL SALDO DE CUENTAS BANCARIAS --
      ------------------------------------------------------------------
      v_sal_cap := round(v_sal_cap, 0);
      v_garan   := 0;
      --- cargo las variables para act. o generar reg. en a_personas ---
      v_mto_gar_cober := v_garan;
      v_total_tc      := v_sal_cap;
      v_total_dc      := 0;
      v_total_tr      := v_sal_cap;
      v_total_dr      := 0;
      v_total_er      := 0;
      v_total_sr      := 0;
      v_cat           := 1;
      v_item          := '110';
      -- totales de control --------------------------------------------
      v_tot_ctr_cred := nvl(v_total_tc, 0) + nvl(v_total_dc, 0);
      v_tot_ctr_ries := nvl(v_total_tr, 0) + nvl(v_total_dr, 0) + nvl(v_total_er, 0) +
                        nvl(v_total_sr, 0);
      --genero o actualizo registro en a_personas -------------------
      pr_ins_personas(p_cod_persona, v_mto_gar_cober, v_total_tc, v_total_dc, v_total_tr,
                      v_total_dr, v_total_er, v_total_sr, v_tot_ctr_cred, v_tot_ctr_ries,
                      v_tip_identif, v_nro_identif, v_cat);
      --genero el registro en c_item --------------------------------
      pr_ins_item(p_cod_persona, v_tip_identif, v_nro_identif, v_item, v_plazo, p_oficina,
                  v_departamento, v_cod_moneda, v_actividad, v_sal_cap, v_sal_cap);

   EXCEPTION
      WHEN no_data_found THEN
         NULL; --PARA Q PROCESE LA SGTE
      --RAISE_APPLICATION_ERROR(-20000,'No existe CTA.CTE '||P_NRO_CUENTA);
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Gen. CTA.CTE ' || p_nro_cuenta || '-' || SQLERRM);
   END;
   /* Genera archivos ASCII a partir de tablas para la Central de Riesgos. */
   PROCEDURE pr_gen_crc_ascii(p_fecha IN DATE) IS
      --- Variables del proceso
      v_fec_proceso ge_calendarios.fec_actual%TYPE;
      v_mes_proceso VARCHAR2(06);
      v_nom_ascii   VARCHAR2(20);
      v_cod_entidad ge_par_generales.cod_entidad%TYPE;
      v_directorio  VARCHAR2(100);
      --- Lineas ASCII
      v_archivo   utl_file.file_type;
      v_lin_pers  VARCHAR2(325);
      v_lin_vincu VARCHAR2(52);
      v_lin_item  VARCHAR2(157);
      v_lin_cons  VARCHAR2(157);
      v_cabe_pers VARCHAR2(48);
      v_cabeceras VARCHAR2(33);

      --- Cursor de personas
      CURSOR personas IS
         SELECT tip_formulario,
                tip_identificador,
                nro_identificador,
                tip_persona,
                pri_apellido || ' ' || seg_apellido pri_apellido,
                NULL seg_apellido,
                ape_conyuge,
                pri_nombre || ' ' || seg_nombre pri_nombre,
                NULL seg_nombre,
                sigla_fecha,
                cod_gru_economico,
                mto_gar_cobertura,
                tot_tc,
                tot_dc,
                tot_tr,
                tot_dr,
                tot_er,
                tot_sr,
                tot_ctr_cred,
                tot_ctr_ries,
                decode(cla_rie_entidad, '1.1', '1a', '1.2', '1b', cla_rie_entidad) cla_rie_entidad,
                por_prevision,
                nro_registro
           FROM sb_personas_crc_det
          WHERE fecha = v_fec_proceso
          ORDER BY nro_registro;

      CURSOR vinculos IS
         SELECT tip_formulario,
                tip_ide_codeudor,
                nro_ide_codeudor,
                tip_ide_deudor,
                nro_ide_deudor,
                tip_vinculo,
                nro_registro
           FROM sb_vinculos_det
          WHERE fecha = v_fec_proceso
          ORDER BY nro_registro;

      CURSOR items IS
         SELECT tip_formulario,
                tip_identificador,
                nro_identificador,
                cod_item,
                cod_plazo,
                cod_region,
                cod_actividad,
                cod_moneda,
                mto_item,
                mto_riesgo,
                nro_registro
           FROM sb_items_det
          WHERE fecha = v_fec_proceso
          ORDER BY nro_registro;

      CURSOR consumos IS
         SELECT tip_formulario,
                tip_identificador,
                nro_identificador,
                nro_operacion,
                tip_operacion,
                mto_ori_credito,
                fec_operacion,
                cod_moneda,
                tas_interes,
                fec_pri_vencimiento,
                fec_vto_cuo_pen_antigua,
                fec_ult_vencimiento,
                dia_atraso,
                nro_cuo_canceladas,
                sal_deu_cons_activo,
                mto_cuo_atrasadas,
                nro_registro
           FROM sb_consumos_det
          WHERE fecha = v_fec_proceso
          ORDER BY nro_registro;
   BEGIN
      IF p_fecha IS NOT NULL THEN
         v_fec_proceso := p_fecha;
      ELSE
         pag_cal.pr_obt_dat_calendar(6);
         v_fec_proceso := pag_cal.g_ult_dia_mes; --pag_cal.fu_obt_fec_actual(6);
      END IF;
      v_mes_proceso := to_char(v_fec_proceso, 'YYYYMM');
      v_directorio  := 'FONDOS'; --VER
      --v_directorio  := 'C:\IT\';
      IF utl_file.is_open(v_archivo) THEN
         utl_file.fclose(v_archivo);
      END IF;

      --- Procesar archivo personas
      SELECT rpad(nom_archivo, 10, ' ') || to_char(last_day(fecha), 'YYYYMMDD') || cod_entidad ||
             lpad(tip_entidad, 2, 0) || lpad(cla_entidad, 2, 0) || lpad(top_riesgo, 15, 0) ||
             nro_reg_a || lpad(tot_reg_detalle, 6, 0)
        INTO v_cabe_pers
        FROM sb_personas_crc
       WHERE fecha = v_fec_proceso;

      v_cod_entidad := substr(v_cabe_pers, 19, 4);

      --   v_nom_ascii := 'CA-'||v_cod_entidad||v_mes_proceso||'.DAT';
      v_nom_ascii := 'ca-' || v_cod_entidad || '.dat';
      v_archivo   := utl_file.fopen(v_directorio, v_nom_ascii, 'w');

      utl_file.put_line(v_archivo, v_cabe_pers);

      FOR r_per IN personas LOOP
         v_lin_pers := lpad(r_per.tip_formulario, 2, 0);
         v_lin_pers := v_lin_pers || rpad(r_per.tip_identificador, 3, ' ');
         IF r_per.tip_identificador IN ('CRP', 'RUC') THEN
            v_lin_pers := v_lin_pers || rpad(r_per.nro_identificador, 15, ' ');
         ELSE
            v_lin_pers := v_lin_pers || lpad(r_per.nro_identificador, 15, '0');
         END IF;
         v_lin_pers := v_lin_pers || lpad(r_per.tip_persona, 3, 0);
         v_lin_pers := v_lin_pers || rpad(nvl(r_per.pri_apellido, ' '), 30, ' ');
         v_lin_pers := v_lin_pers || rpad(nvl(r_per.seg_apellido, ' '), 15, ' ');
         v_lin_pers := v_lin_pers || rpad(nvl(r_per.ape_conyuge, ' '), 15, ' ');
         v_lin_pers := v_lin_pers || rpad(r_per.pri_nombre, 60, ' ');
         v_lin_pers := v_lin_pers || rpad(nvl(r_per.seg_nombre, ' '), 15, ' ');
         v_lin_pers := v_lin_pers || lpad(nvl(to_char(r_per.sigla_fecha, 'yyyymmdd'), '0'), 15, ' ');
         v_lin_pers := v_lin_pers || lpad(r_per.cod_gru_economico, 3, 0);
         v_lin_pers := v_lin_pers || lpad(r_per.mto_gar_cobertura, 15, 0);
         v_lin_pers := v_lin_pers || lpad(r_per.tot_tc, 15, 0);
         v_lin_pers := v_lin_pers || lpad(r_per.tot_dc, 15, 0);
         v_lin_pers := v_lin_pers || lpad(r_per.tot_tr, 15, 0);
         v_lin_pers := v_lin_pers || lpad(r_per.tot_dr, 15, 0);
         v_lin_pers := v_lin_pers || lpad(r_per.tot_er, 15, 0);
         v_lin_pers := v_lin_pers || lpad(r_per.tot_sr, 15, 0);
         v_lin_pers := v_lin_pers || lpad(r_per.tot_ctr_cred, 15, 0);
         v_lin_pers := v_lin_pers || lpad(r_per.tot_ctr_ries, 15, 0);
         v_lin_pers := v_lin_pers || rpad(r_per.cla_rie_entidad, 2, ' ');
         v_lin_pers := v_lin_pers || lpad(r_per.por_prevision * 100, 6, 0);
         v_lin_pers := v_lin_pers || lpad(r_per.nro_registro, 6, 0);
         utl_file.put_line(v_archivo, v_lin_pers);
      END LOOP;
      utl_file.fclose(v_archivo);

      --- Procesar archivo vinculos
      SELECT rpad(nom_archivo, 10, ' ') || to_char(last_day(fecha), 'YYYYMMDD') || cod_entidad ||
             lpad(tip_entidad, 2, 0) || lpad(cla_entidad, 2, 0) || nro_reg_a ||
             lpad(tot_reg_detalle, 6, 0)
        INTO v_cabeceras
        FROM sb_vinculos
       WHERE fecha = v_fec_proceso;

      --   v_nom_ascii := 'CB-'||v_cod_entidad||v_mes_proceso||'.DAT';
      v_nom_ascii := 'cb-' || v_cod_entidad || '.dat';
      v_archivo   := utl_file.fopen(v_directorio, v_nom_ascii, 'w');

      utl_file.put_line(v_archivo, v_cabeceras);

      FOR r_vin IN vinculos LOOP
         v_lin_vincu := lpad(r_vin.tip_formulario, 2, 0);
         v_lin_vincu := v_lin_vincu || rpad(r_vin.tip_ide_codeudor, 3, ' ');
         IF r_vin.tip_ide_codeudor IN ('CRP', 'RUC') THEN
            v_lin_vincu := v_lin_vincu || rpad(r_vin.nro_ide_codeudor, 15, ' ');
         ELSE
            v_lin_vincu := v_lin_vincu || lpad(r_vin.nro_ide_codeudor, 15, '0');
         END IF;
         v_lin_vincu := v_lin_vincu || rpad(r_vin.tip_ide_deudor, 3, ' ');
         IF r_vin.tip_ide_deudor IN ('CRP', 'RUC') THEN
            v_lin_vincu := v_lin_vincu || rpad(r_vin.nro_ide_deudor, 15, ' ');
         ELSE
            v_lin_vincu := v_lin_vincu || lpad(r_vin.nro_ide_deudor, 15, '0');
         END IF;
         v_lin_vincu := v_lin_vincu || lpad(r_vin.tip_vinculo, 2, 0);
         v_lin_vincu := v_lin_vincu || lpad(r_vin.nro_registro, 6, 0);
         utl_file.put_line(v_archivo, v_lin_vincu);
      END LOOP;
      utl_file.fclose(v_archivo);

      --- Procesar archivo items
      SELECT rpad(nom_archivo, 10, ' ') || to_char(last_day(fecha), 'YYYYMMDD') || cod_entidad ||
             lpad(tip_entidad, 2, 0) || lpad(cla_entidad, 2, 0) || nro_reg_a ||
             lpad(tot_reg_detalle, 6, 0)
        INTO v_cabeceras
        FROM sb_items
       WHERE fecha = v_fec_proceso;

      v_nom_ascii := 'cc-' || v_cod_entidad || '.dat';
      --   v_nom_ascii := 'CC-'||v_cod_entidad||v_mes_proceso||'.DAT';
      v_archivo := utl_file.fopen(v_directorio, v_nom_ascii, 'w');

      utl_file.put_line(v_archivo, v_cabeceras);

      FOR r_ite IN items LOOP
         v_lin_item := lpad(r_ite.tip_formulario, 2, 0);
         v_lin_item := v_lin_item || rpad(r_ite.tip_identificador, 3, ' ');
         IF r_ite.tip_identificador IN ('CRP', 'RUC') THEN
            v_lin_item := v_lin_item || rpad(r_ite.nro_identificador, 15, ' ');
         ELSE
            v_lin_item := v_lin_item || lpad(r_ite.nro_identificador, 15, '0');
         END IF;
         v_lin_item := v_lin_item || rpad(r_ite.cod_item, 10, 0);
         v_lin_item := v_lin_item || lpad(r_ite.cod_plazo, 2, 0);
         v_lin_item := v_lin_item || lpad(r_ite.cod_region, 3, 0);
         v_lin_item := v_lin_item || lpad(r_ite.cod_actividad, 3, 0);
         v_lin_item := v_lin_item || lpad(r_ite.cod_moneda, 4, 0);
         v_lin_item := v_lin_item || lpad(r_ite.mto_item, 15, 0);
         v_lin_item := v_lin_item || lpad(r_ite.mto_riesgo, 15, 0);
         v_lin_item := v_lin_item || lpad(r_ite.nro_registro, 6, 0);
         utl_file.put_line(v_archivo, v_lin_item);
      END LOOP;
      utl_file.fclose(v_archivo);

      --- Procesar archivo consumos
      SELECT rpad(nom_archivo, 10, ' ') || to_char(last_day(fecha), 'YYYYMMDD') || cod_entidad ||
             lpad(tip_entidad, 2, 0) || lpad(cla_entidad, 2, 0) || nro_reg_a ||
             lpad(tot_reg_detalle, 6, 0)
        INTO v_cabeceras
        FROM sb_consumos
       WHERE fecha = v_fec_proceso;

      --   v_nom_ascii := 'CD-'||v_cod_entidad||v_mes_proceso||'.DAT';
      v_nom_ascii := 'cd-' || v_cod_entidad || '.dat';
      v_archivo   := utl_file.fopen(v_directorio, v_nom_ascii, 'w');

      utl_file.put_line(v_archivo, v_cabeceras);

      FOR r_con IN consumos LOOP
         v_lin_cons := lpad(r_con.tip_formulario, 2, 0);
         v_lin_cons := v_lin_cons || rpad(r_con.tip_identificador, 3, ' ');
         IF r_con.tip_identificador IN ('CRP', 'RUC') THEN
            v_lin_cons := v_lin_cons || rpad(r_con.nro_identificador, 15, ' ');
         ELSE
            v_lin_cons := v_lin_cons || lpad(r_con.nro_identificador, 15, '0');
         END IF;
         v_lin_cons := v_lin_cons || rpad(r_con.nro_operacion, 20, ' ');
         v_lin_cons := v_lin_cons || rpad(r_con.tip_operacion, 6, 0);
         v_lin_cons := v_lin_cons || lpad(r_con.mto_ori_credito * 100, 17, 0);
         v_lin_cons := v_lin_cons || rpad(nvl(to_char(r_con.fec_operacion, 'yyyymmdd'), ' '), 8, ' ');
         v_lin_cons := v_lin_cons || lpad(r_con.cod_moneda, 4, 0);
         v_lin_cons := v_lin_cons || lpad(r_con.tas_interes * 100, 5, 0);
         v_lin_cons := v_lin_cons ||
                       rpad(nvl(to_char(r_con.fec_pri_vencimiento, 'yyyymmdd'), 0), 8, 0);
         v_lin_cons := v_lin_cons ||
                       rpad(nvl(to_char(r_con.fec_vto_cuo_pen_antigua, 'yyyymmdd'), 0), 8, 0);
         v_lin_cons := v_lin_cons ||
                       rpad(nvl(to_char(r_con.fec_ult_vencimiento, 'yyyymmdd'), 0), 8, 0);
         v_lin_cons := v_lin_cons || lpad(r_con.dia_atraso, 4, 0);
         v_lin_cons := v_lin_cons || lpad(r_con.nro_cuo_canceladas, 3, 0);
         v_lin_cons := v_lin_cons || lpad(r_con.sal_deu_cons_activo * 100, 17, 0);
         v_lin_cons := v_lin_cons || lpad(r_con.mto_cuo_atrasadas * 100, 17, 0);
         v_lin_cons := v_lin_cons || lpad(r_con.nro_registro, 6, 0);
         utl_file.put_line(v_archivo, v_lin_cons);
      END LOOP;
      utl_file.fclose(v_archivo);
   EXCEPTION
      WHEN no_data_found THEN
         utl_file.fclose(v_archivo);
      WHEN utl_file.invalid_operation THEN
         utl_file.fclose(v_archivo);
      WHEN utl_file.invalid_path THEN
         utl_file.fclose(v_archivo);
         raise_application_error(-20000, 'Directorio invalido');
      WHEN utl_file.invalid_mode THEN
         utl_file.fclose(v_archivo);
         raise_application_error(-20000, 'Modo invalido');
      WHEN utl_file.invalid_filehandle THEN
         utl_file.fclose(v_archivo);
         raise_application_error(-20000, 'Invalida Filehandle');
      WHEN utl_file.read_error THEN
         utl_file.fclose(v_archivo);
         raise_application_error(-20000, 'Lectura errada');
      WHEN utl_file.write_error THEN
         utl_file.fclose(v_archivo);
         raise_application_error(-20000, 'Escritura errada');
      WHEN utl_file.internal_error THEN
         utl_file.fclose(v_archivo);
         raise_application_error(-20000, 'Error interno');
   END;

END pas_crc;
/

