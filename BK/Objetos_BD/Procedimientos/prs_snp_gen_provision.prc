CREATE OR REPLACE PROCEDURE IT.prs_snp_gen_provision(p_tip_movimiento IN VARCHAR2 DEFAULT 'G',
                                                  rg_msj           IN pas_snp.rg_msj DEFAULT NULL) IS

   /*
   || Propósito : Generar/Reversar Asientos Contables de Provisión por diferentes tipos de operaciones.
   || Parámetros: P_TIP_MOVIMIENTO => "G" (Generar Asientos) o "R" (Reversion de Asientos Generados)
   */

   v_cod_tra_provision ge_transacciones.cod_transaccion%TYPE;
   v_cod_tra_reversion ge_transacciones.cod_transaccion%TYPE;
   v_fre_proceso       ge_procesos_det.frecuencia%TYPE;
   v_fre_pag_provision ba_tab_dat_adicionales.val_parametro%TYPE;
   v_ind_activo        ge_procesos_det.activo%TYPE;
   v_fec_hab_fin_mes   ge_calendarios.fec_actual%TYPE;
   v_fec_provision     ge_calendarios.fec_actual%TYPE;
   v_fec_mes_anterior  ge_calendarios.fec_actual%TYPE;
   v_cod_moneda        ge_tip_asientos.cod_moneda%TYPE;
   v_mto_remunerar     sb_encajes_ml.mto_remunerar%TYPE;
   v_mto_rubro         cb_asientos_det.mto_mon_rubro%TYPE;
   v_mto_mon_local     cb_asientos_det.mto_mon_local%TYPE;
   v_nro_asiento       cb_asientos.nro_asiento%TYPE;
   v_cod_ofi_matriz    ba_oficinas.cod_oficina%TYPE;
   v_fec_actual        ge_calendarios.fec_actual%TYPE;
   v_cod_rubro1        ge_tip_asientos.cod_rubro%TYPE := NULL;
   v_cod_rubro2        ge_tip_asientos.cod_rubro%TYPE := NULL;
   v_tip_mov_rubro1    ge_tip_asientos.tip_movimiento%TYPE := NULL;
   v_tip_mov_rubro2    ge_tip_asientos.tip_movimiento%TYPE := NULL;
   v_cotizacion        ge_cotizaciones.val_conversion%TYPE := NULL;
   v_val_tasa          ge_tas_fechas.val_tasa%TYPE := NULL;
   v_fec_vigencia      ge_tas_fechas.fec_vigencia%TYPE := NULL;
   v_tip_valor         ge_tasas.tip_valor%TYPE := NULL;
   v_tip_tasa          ge_tasas.tipo%TYPE := NULL;
   v_cod_tas_provision ge_tasas.cod_tasa%TYPE := NULL;
   v_referencia        cb_asientos_det_his.referencia%TYPE;
   v_tip_operacion     ba_cod_referencias.val_maximo%TYPE;
   v_tra_eje_actual    ge_transacciones.cod_transaccion%TYPE := NULL;
   v_tra_eje_anterior  ge_transacciones.cod_transaccion%TYPE := NULL;
   v_msj_provision     varchar2(4000);
   v_dir_correo        VARCHAR2(4000) := nvl(pas_snp.g_err_dir_correo, pas_snp.g_gru_dir_correo);
   v_lugar             VARCHAR2(4000);
   v_des_provision     VARCHAR2(4000);
   v_plazo             NUMBER;
   v_can_dec_moneda    NUMBER;
   v_can_dec_mon_local NUMBER;
   ex_dat_invalido     EXCEPTION;
   ex_msj_indefinido   EXCEPTION;

   CURSOR cu_par_mensajes IS
      SELECT tab_relacion, referencia, parametro, val_parametro
        FROM ba_tab_dat_adicionales
       WHERE tab_relacion = 'GE_SNP_PAR_MENSAJES'
         AND parametro = 'SNP_IND_MSJ_PROVISION'
         AND val_parametro = 'S';

   CURSOR cu_monedas IS
      SELECT DISTINCT (b.cod_moneda) cod_moneda
        FROM cc_cta_bancarias b
       WHERE b.cod_modulo = pas_snp.fu_obt_cod_mod_padre
         AND b.cod_modalidad = pas_snp.fu_obt_cod_mad_padre
         AND b.estado IN ('A', 'N', 'S') /*Abierta, Normal, Bloqueo de Saldo*/
         ;

   FUNCTION lf_obt_cod_tas_provision(p_tip_provision IN ba_cod_referencias.val_maximo%TYPE) RETURN NUMBER IS
      v_cod_tasa ge_tasas.cod_tasa%TYPE := NULL;
   BEGIN
      IF upper(fue_obt_des_refcodes('SNP_COD_TAS_PROVISION', p_tip_provision)) NOT LIKE '%REF%NO%REG%SISTEMA%' THEN
         v_cod_tasa := to_number(fue_obt_des_refcodes('SNP_COD_TAS_PROVISION', p_tip_provision));
         IF v_cod_tasa IS NULL THEN
            RAISE no_data_found;
         ELSE
            -- Valida que exista la tasa en GE_TASAS
            SELECT cod_tasa
              INTO v_cod_tasa
              FROM ge_tasas
             WHERE cod_tasa = v_cod_tasa;
         END IF;
      ELSE
         RAISE no_data_found;
      END IF;

      RETURN v_cod_tasa;

   EXCEPTION
      WHEN no_data_found THEN
         pas_snp.g_cod_error := 56;
         pas_snp.g_msj_error := v_lugar || 'Código de Tasa inexistente para el dominio SNP_COD_TAS_PROVISION y tipo de Provisión ' || p_tip_provision || SQLERRM;
         RAISE pas_snp.ex_salir;
      WHEN OTHERS THEN
         pas_snp.g_cod_error := 56;
         pas_snp.g_msj_error := 'Error en LF_OBT_COD_TAS_PROVISION: ' || v_lugar || SQLERRM;
         RAISE pas_snp.ex_salir;
   END lf_obt_cod_tas_provision;

   PROCEDURE lp_obt_dat_rubro(p_cod_transaccion IN ge_transacciones.cod_transaccion%TYPE,
                              p_cod_moneda      IN ba_monedas.cod_moneda%TYPE,
                              p_cod_rubro1      OUT cb_rubros.cod_rubro%TYPE,
                              p_tip_mov_rubro1  OUT ge_tip_asientos.tip_movimiento%TYPE,
                              p_cod_rubro2      OUT cb_rubros.cod_rubro%TYPE,
                              p_tip_mov_rubro2  OUT ge_tip_asientos.tip_movimiento%TYPE) IS
      -- Obtiene los rubros para generar los asientos.
   BEGIN
      v_lugar := 'Obteniendo los rubros para la' || ' TRX. ' || p_cod_transaccion || ' MOD. ' || pas_snp.fu_obt_cod_mod_padre || ' MAD. ' || pas_snp.fu_obt_cod_mad_padre || ' MON. ' || p_cod_moneda || ', ';

      SELECT a.cod_rubro cod_rubro1, a.tip_movimiento tip_mov_rubro1, b.cod_rubro cod_rubro2, b.tip_movimiento tip_mov_rubro2
        INTO p_cod_rubro1, p_tip_mov_rubro1, p_cod_rubro2, p_tip_mov_rubro2
        FROM ge_transacciones t, ge_tip_asientos a, ge_tip_asientos b
       WHERE t.cod_transaccion = p_cod_transaccion -- Transaccion de Provision
         AND t.cod_modulo = pas_snp.fu_obt_cod_mod_padre -- Modulo de Cuentas Corrientes
         AND t.cod_modalidad = pas_snp.fu_obt_cod_mad_padre -- Modalidad de Cuentas Interbancarias
         AND t.cod_tip_asiento = a.cod_tip_asiento(+)
         AND t.cod_tip_asiento2 = b.cod_tip_asiento(+)
         AND a.cod_moneda(+) = p_cod_moneda
         AND b.cod_moneda(+) = p_cod_moneda;
      IF p_cod_rubro1 IS NULL THEN
         pas_snp.g_cod_error := 56;
         pas_snp.g_msj_error := v_lugar || 'Datos inexistentes para el Rubro 1';
         RAISE ex_dat_invalido;
      ELSIF p_cod_rubro2 IS NULL THEN
         pas_snp.g_cod_error := 56;
         pas_snp.g_msj_error := v_lugar || 'Datos inexistentes para el Rubro 2';
         RAISE ex_dat_invalido;
      END IF;
   EXCEPTION
      WHEN ex_dat_invalido THEN
         RAISE pas_snp.ex_salir;
      WHEN no_data_found THEN
         p_cod_rubro1        := NULL;
         p_tip_mov_rubro1    := NULL;
         p_cod_rubro2        := NULL;
         p_tip_mov_rubro2    := NULL;
         pas_snp.g_cod_error := 56;
         pas_snp.g_msj_error := v_lugar || 'Datos inexistentes';
         RAISE pas_snp.ex_salir;
   END lp_obt_dat_rubro;

   PROCEDURE lp_env_mai_error IS
      -- Se envía correo informando sobre errores al intentar realizar las provisiones
   BEGIN
      IF v_dir_correo IS NOT NULL  AND
         pas_snp.fu_obt_msj_error is not null THEN
         it_mail.mail(fug_obt_dir_correo, v_dir_correo, 'Informe de Provisiones SIPAP ', chr(10) || chr(10) || 'Error : ' || pas_snp.fu_obt_msj_error || chr(10) || chr(10) || 'Atentamente.');
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END lp_env_mai_error;

   PROCEDURE lp_ins_asientos_cab(p_cod_ofi_matriz IN cb_asientos.cod_oficina%TYPE,
                                 p_nro_asiento    IN cb_asientos.nro_asiento%TYPE,
                                 p_fec_actual     IN cb_asientos.fecha%TYPE,
                                 p_tot_control    IN cb_asientos.tot_control%TYPE) IS
      -- Obtiene los rubros para generar los asientos.
   BEGIN
      v_lugar := 'Generando Cabecera del Asiento, ';
      --Inserta la cabecera del Asiento
      INSERT INTO cb_asientos
         (cod_oficina, nro_asiento, cod_usuario, fecha, cod_modulo, cod_modalidad, tot_control, actualizado, reversado, cod_ofi_origen, ofi_integrada, confirmado)
      VALUES
         (p_cod_ofi_matriz, p_nro_asiento, USER, p_fec_actual, 2, 21, p_tot_control, 'N', 'N', p_cod_ofi_matriz, 'N', 'S');
   EXCEPTION
      WHEN OTHERS THEN
         pas_snp.g_cod_error := 56;
         pas_snp.g_msj_error := v_lugar || 'Insertando Cabecera de asientos';
         RAISE pas_snp.ex_salir;
   END lp_ins_asientos_cab;

   PROCEDURE lp_ins_asientos_det(p_fec_actual     IN cb_asientos.fecha%TYPE,
                                 p_cod_ofi_matriz IN cb_asientos.cod_oficina%TYPE,
                                 p_nro_asiento    IN cb_asientos.nro_asiento%TYPE,
                                 p_nro_linea      IN cb_asientos_det.nro_linea%TYPE DEFAULT 1,
                                 p_cod_rubro      IN cb_asientos_det.cod_rubro%TYPE,
                                 p_tip_mov_rubro  IN cb_asientos_det.tip_movimiento%TYPE,
                                 p_mto_mon_rubro  IN cb_asientos_det.mto_mon_rubro%TYPE,
                                 p_mto_mon_local  IN cb_asientos_det.mto_mon_local%TYPE,
                                 p_des_provision  IN cb_asientos_det.descripcion%TYPE,
                                 p_referencia     IN cb_asientos_det.referencia%TYPE,
                                 p_cotizacion     IN cb_asientos_det.val_cotizacion%TYPE) IS
      -- Obtiene los rubros para generar los asientos.
   BEGIN
      v_lugar := 'Generando Detalle del Asiento, ';
      --Inserta el Asiento
      INSERT INTO cb_asientos_det
         (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_rubro, mto_mon_local, descripcion, referencia, protegido, actualizado, val_cotizacion, distribuido, ref_movimiento)
      VALUES
         (p_fec_actual, p_cod_ofi_matriz, p_nro_asiento, p_nro_linea, p_cod_rubro, p_tip_mov_rubro, p_mto_mon_rubro, p_mto_mon_local, p_des_provision, p_referencia, 'N', 'N', p_cotizacion, 'N', NULL);
   EXCEPTION
      WHEN OTHERS THEN
         pas_snp.g_cod_error := 57;
         pas_snp.g_msj_error := v_lugar || 'Insertando Detalle de asientos';
         RAISE pas_snp.ex_salir;
   END lp_ins_asientos_det;

BEGIN
   --
   pas_snp.pr_ini_variables;

   v_lugar := 'Verificando si la mensajería corresponde al proceso de Provisión, ';
   if p_tip_movimiento != 'G' then
      -- Cuando el tipo de movimiento es REVERSION debe ejecutarse el proceso solamente para los mensajes configurados
      for msj_prov in cu_par_mensajes loop
          pas_snp.pr_set_texto(v_msj_provision, msj_prov.referencia, ',');
      end loop;
      if v_msj_provision is not null then
         v_msj_provision := ',' || v_msj_provision || ',';
     end if;
      if instr(nvl(v_msj_provision,'~'), ',' || rg_msj.cod_msj_swift || rg_msj.cod_tip_operacion || rg_msj.cod_sub_tip_operacion || ',', 1) = 0 then
         -- Si el mensaje no está configurado como un mensaje de provisión entonces sale del proceso.
         raise ex_msj_indefinido;
      end if;
   end if;

   --
   v_lugar := 'Buscando datos del calendario para el módulo de Contabilidad, ';
   -- Obtiene valores del registro de GE_CALENDARIOS para el módulo de Contabilidad.
   pag_cal.pr_obt_dat_calendar(2);
   -- Asigna las fechas a las variables de fecha .
   v_fec_hab_fin_mes  := pag_cal.g_ult_dia_mes_habil - 1;
   v_fec_actual       := pag_cal.g_fec_actual;
   v_fec_mes_anterior := pag_cal.g_pri_dia_mes - 1;

   -- Obtiene el codigo de Oficina Matriz
   v_lugar          := 'Obteniendo datos de la Oficina Matriz, ';
   v_cod_ofi_matriz := fug_obt_ofi_matriz;
   FOR men IN cu_par_mensajes
   LOOP
      BEGIN
         v_tip_operacion := substr(men.referencia, 4);
         v_lugar         := 'Buscando la Frecuencia del Pago de la Provisión para el tipo de operación ' || v_tip_operacion || ', ';
         -- Referencia en el asiento por operación
         IF p_tip_movimiento = 'G' THEN
            v_referencia := men.referencia;
         ELSE
            v_referencia := rg_msj.cod_msj_swift || rg_msj.cod_tip_operacion || rg_msj.cod_sub_tip_operacion;
         END IF;
         --
         v_fre_pag_provision := fue_tab_dat_adicional('GE_SNP_PAR_MENSAJES', 'SNP_FRE_PAG_PROVISION', v_referencia);
         --
         IF nvl(v_fre_pag_provision, '~') = '~' THEN
            pas_snp.g_cod_error := 56;
            pas_snp.g_msj_error := v_lugar || 'Frecuencia de Pago de la Provisión inexistente para el tipo de operación ' || v_tip_operacion;
            RAISE ex_dat_invalido;
         END IF;
      EXCEPTION
         WHEN ex_dat_invalido THEN
            RAISE pas_snp.ex_salir;
         WHEN no_data_found THEN
            pas_snp.g_cod_error := 56;
            pas_snp.g_msj_error := v_lugar || 'Transacción inexisten del Ejercicio Anterior para el tipo de operación ' || v_tip_operacion;
         WHEN OTHERS THEN
            RAISE;
      END;

      BEGIN
         v_lugar := 'Buscando transacciones definidas para el tratamiento de PROVISIONES del Ejercicio Anterior, ';
         --
         v_tra_eje_anterior := fue_tab_dat_adicional('GE_SNP_PAR_MENSAJES', 'SNP_TRA_EJE_ANTERIOR', men.referencia);
         --
         IF to_char(v_fec_actual, 'MM') = '01' AND v_tra_eje_anterior IS NULL THEN
            RAISE no_data_found;
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            pas_snp.g_cod_error := 56;
            pas_snp.g_msj_error := v_lugar || 'Transacción inexistente del Ejercicio Anterior para el tipo de operación ' || v_tip_operacion;
            RAISE pas_snp.ex_salir;
         WHEN OTHERS THEN
            RAISE;
      END;

      BEGIN
         v_lugar          := 'Buscando transacciones definidas para el tratamiento de PROVISIONES del Ejercicio Actual, ';
         v_tra_eje_actual := fue_tab_dat_adicional('GE_SNP_PAR_MENSAJES', 'SNP_TRA_EJE_ACTUAL', men.referencia);

         IF v_tra_eje_actual IS NULL THEN
            RAISE no_data_found;
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            pas_snp.g_cod_error := 56;
            pas_snp.g_msj_error := v_lugar || 'Transacción de la Provisión no definida para el tipo de operación ' || v_tip_operacion;
            RAISE pas_snp.ex_salir;
         WHEN OTHERS THEN
            RAISE;
      END;
      --
      v_lugar             := 'Recuperando el código de transacción apropiado para la generación de movimientos contables por PROVISION, ';
      v_cod_tra_provision := v_tra_eje_actual;
      IF to_char(v_fec_actual, 'MM') = '01' THEN
         v_cod_tra_reversion := v_tra_eje_anterior;
      ELSE
         v_cod_tra_reversion := v_tra_eje_actual;
      END IF;
      --
      -- Verifica la frecuencia del procedimiento
      v_lugar := 'Obteniendo la frecuencia del Proceso, ';
      BEGIN
         SELECT frecuencia, activo
           INTO v_fre_proceso, v_ind_activo
           FROM ge_procesos_det
          WHERE upper(cod_programa) LIKE '%PRS_SNP_GEN_PROVISION%'
            AND hor_fin IS NULL;
         IF v_ind_activo != 'S' THEN
            RAISE ex_dat_invalido;
         END IF;
      EXCEPTION
         WHEN ex_dat_invalido THEN
            pas_snp.g_cod_error := 56;
            pas_snp.g_msj_error := v_lugar || 'La Frecuencia para el Proceso PRS_SNP_GEN_PROVISION no se encuentra ACTIVA';
            RAISE pas_snp.ex_salir;
         WHEN no_data_found THEN
            pas_snp.g_cod_error := 56;
            pas_snp.g_msj_error := v_lugar || 'Frecuencia inexistente para el Proceso PRS_SNP_GEN_PROVISION';
            RAISE pas_snp.ex_salir;
         WHEN OTHERS THEN
            RAISE;
      END;

      IF p_tip_movimiento = 'G' THEN
         -- Verifica que sea fecha habil
         IF pag_cal.fu_obt_fec_habil(v_fec_hab_fin_mes, 1, v_cod_ofi_matriz) <> v_fec_hab_fin_mes THEN
            v_fec_hab_fin_mes := pag_cal.fu_obt_fec_habil(v_fec_hab_fin_mes - 1, -1, v_cod_ofi_matriz);
         END IF;

         v_lugar := 'Verificando datos con la Frecuencia configurada, ';
         IF v_fre_proceso = 'M' THEN
            -- Verifica que sea Fin de mes en Calendario Contable para continuar
            IF pag_cal.g_ult_dia_mes_habil <> pag_cal.g_ult_dia_mes_habil OR v_fec_hab_fin_mes > v_fec_actual THEN
               pas_snp.g_cod_error := 56;
               pas_snp.g_msj_error := v_lugar || 'El proceso solo se puede Ejecutar al fin de mes Contable.';
               RAISE pas_snp.ex_salir;
            END IF;
            v_lugar := 'Obteniendo el Plazo del mes, ';
            -- Verifica la cantidad de dias que contiene el mes actual.
            v_plazo         := pag_cal.g_ult_dia_mes - pag_cal.g_pri_dia_mes;
            v_fec_provision := v_fec_hab_fin_mes;
         ELSE
            pas_snp.g_cod_error := 56;
            pas_snp.g_msj_error := v_lugar || 'El proceso solo se puede Ejecutar al fin de mes Contable.';
            RAISE pas_snp.ex_salir;
         END IF;
      END IF;

      v_lugar             := 'Buscando cantidad de decimales para la moneda local, ';
      v_can_dec_mon_local := nvl(fug_obt_pardinamico(p_parametro => 'VAL_RED_MON_EXTRANJERA', p_cod_modulo => pas_snp.fu_obt_cod_mod_padre, p_cod_modalidad => pas_snp.fu_obt_cod_mad_padre, p_cod_moneda => pag_gen.fu_obt_mon_local), 0);

      v_lugar := 'Procesando movimientos de PROVISIONES por monedas, ';
      FOR mon IN cu_monedas
      LOOP
         -- Se inicializa todas las variables utilizadas.
         v_mto_rubro      := 0;
         v_mto_mon_local  := 0;
         v_cotizacion     := 0;
         v_mto_remunerar  := 0;
         v_cod_rubro1     := NULL;
         v_tip_mov_rubro1 := NULL;
         v_cod_rubro2     := NULL;
         v_tip_mov_rubro2 := NULL;
         v_can_dec_moneda := nvl(fug_obt_pardinamico(p_parametro => 'VAL_RED_MON_EXTRANJERA', p_cod_modulo => pas_snp.fu_obt_cod_mod_padre, p_cod_modalidad => pas_snp.fu_obt_cod_mad_padre, p_cod_moneda => mon.cod_moneda), 0);

         IF p_tip_movimiento = 'G' THEN
            -- Se obtiene la descripción de la operación para Generación Mensual de Provisión
            v_des_provision := upper(pas_snp.fu_obt_des_tip_operacion(substr(men.referencia, 1, 3), substr(v_tip_operacion, 1, 3), substr(v_tip_operacion, 4, 3)));

            IF v_tip_operacion IN ('022002', '021001') THEN
               -- ENCAJE LEGAL y FONDO DE GARANTIA
               IF v_tip_operacion = '022002' THEN
                  -- ENCAJE LEGAL
                  v_lugar             := 'Obteniendo la Tasa para el cálculo del Encaje en moneda ' || mon.cod_moneda || ', ';
                  v_cod_tas_provision := lf_obt_cod_tas_provision('ENC');
                  v_lugar             := 'Obteniendo el Monto Mensual del Encaje en moneda ' || mon.cod_moneda || ' para la fecha ' || to_char(v_fec_provision, 'DD/MM/RRRR') || ', ';
                  IF mon.cod_moneda = pas_snp.g_cod_mon_local THEN

                     BEGIN
                        SELECT round(SUM(nvl(m.mto_remunerar, 0)) / v_plazo, v_can_dec_moneda)
                          INTO v_mto_remunerar
                          FROM sb_encajes_ml m
                         WHERE m.fecha = v_fec_provision;

                        IF v_mto_remunerar = 0 THEN
                           RAISE no_data_found;
                        END IF;
                     EXCEPTION
                        WHEN no_data_found THEN
                           pas_snp.g_cod_error := 56;
                           pas_snp.g_msj_error := v_lugar || 'Monto Mensual (ML) del Encaje inexistente.';
                           RAISE pas_snp.ex_salir;
                        WHEN OTHERS THEN
                           RAISE;
                     END;

                  ELSE
                     BEGIN
                        SELECT round(SUM(nvl(e.mto_remunerar, 0)) / v_plazo, v_can_dec_moneda)
                          INTO v_mto_remunerar
                          FROM sb_encajes_me e
                         WHERE e.fecha = v_fec_provision
                           AND e.cod_moneda = mon.cod_moneda;

                        IF v_mto_remunerar = 0 THEN
                           RAISE no_data_found;
                        END IF;
                     EXCEPTION
                        WHEN no_data_found THEN
                           pas_snp.g_cod_error := 56;
                           pas_snp.g_msj_error := v_lugar || 'Monto Mensual (ME) del Encaje inexistente.';
                           RAISE pas_snp.ex_salir;
                        WHEN OTHERS THEN
                           RAISE;
                     END;
                  END IF;
               ELSIF v_tip_operacion = '021001' THEN
                  -- FONDO DE GARANTIA
                  v_lugar             := 'Obteniendo la Tasa para el cálculo del Fondo de Garantía en moneda ' || mon.cod_moneda || ', ';
                  v_cod_tas_provision := lf_obt_cod_tas_provision('FGD');
                  v_lugar             := 'Obteniendo el Monto Mensual del Fondo de Garantía en moneda ' || mon.cod_moneda || ' para la fecha ' || to_char(v_fec_provision, 'DD/MM/RRRR') || ', ';
                  IF mon.cod_moneda = pas_snp.g_cod_mon_local THEN
                     BEGIN
                        SELECT round(SUM(nvl(e.sujeto_e, 0) + nvl(e.sujeto_f, 0) + nvl(e.sujeto_g, 0)) / v_plazo, v_can_dec_moneda)
                          INTO v_mto_remunerar
                          FROM sb_encajes_ml e
                         WHERE e.fecha = v_fec_provision;

                        IF v_mto_remunerar = 0 THEN
                           RAISE no_data_found;
                        END IF;
                     EXCEPTION
                        WHEN no_data_found THEN
                           pas_snp.g_cod_error := 56;
                           pas_snp.g_msj_error := v_lugar || 'Monto Mensual (ML) del Fondo de Garantía inexistente.';
                           RAISE pas_snp.ex_salir;
                        WHEN OTHERS THEN
                           RAISE;
                     END;
                  ELSE
                     BEGIN
                        SELECT round(SUM(nvl(e.sujeto_a, 0) + nvl(e.sujeto_b, 0) + nvl(e.sujeto_c, 0) + nvl(e.sujeto_d, 0)) / v_plazo, v_can_dec_moneda)
                          INTO v_mto_remunerar
                          FROM sb_encajes_me e
                         WHERE e.fecha = v_fec_provision
                           AND e.cod_moneda = mon.cod_moneda;

                        IF v_mto_remunerar = 0 THEN
                           RAISE no_data_found;
                        END IF;
                     EXCEPTION
                        WHEN no_data_found THEN
                           pas_snp.g_cod_error := 56;
                           pas_snp.g_msj_error := v_lugar || 'Monto Mensual (ME) del Fondo de Garantía inexistente.';
                           RAISE pas_snp.ex_salir;
                        WHEN OTHERS THEN
                           RAISE;
                     END;
                  END IF;
               END IF;
               --
               v_lugar := 'Obteniendo Valor para la tasa ' || v_cod_tas_provision || ', ';
               pag_gen.pr_obt_val_tasa(pas_snp.fu_obt_cod_mod_padre, pas_snp.fu_obt_cod_mad_padre, v_cod_ofi_matriz, NULL, mon.cod_moneda, NULL, NULL, v_cod_tas_provision, NULL, v_fec_actual, v_val_tasa,-- OUT
                                       v_fec_vigencia,-- OUT
                                       v_tip_valor,-- OUT
                                       v_tip_tasa,-- OUT
                                       NULL);
               --
               -- Calculo del Interes (Saldo promedio del monto a remunerar x Tasa x plazo)/36500)
               v_mto_rubro     := pag_gen.fu_cal_int_simple(v_mto_remunerar, v_plazo, v_val_tasa);
               v_cotizacion    := pag_gen.fu_obt_cotizacion(mon.cod_moneda, v_fec_actual);
               v_mto_mon_local := round(v_mto_rubro * v_cotizacion, v_can_dec_mon_local);
            ELSIF v_tip_operacion IN ('020006', '020001') THEN
               --020006=MULTA POR LLEGADA TARDIA CAMARA COMPENSADORA
               --020001=GASTOS CENTRAL DE RIESGOS
               BEGIN
                  SELECT round(SUM(nvl(t.monto, 0)), v_can_dec_moneda)
                    INTO v_mto_rubro
                    FROM ge_snp_transferencias t
                   WHERE t.cod_msj_swift = substr(men.referencia, 1, 3)
                     AND t.cod_tip_operacion = substr(v_tip_operacion, 1, 3)
                     AND t.cod_sub_tip_operacion = substr(v_tip_operacion, 4, 3)
                     AND t.cod_modulo = pas_snp.fu_obt_cod_mod_padre
                     AND t.cod_modalidad = pas_snp.fu_obt_cod_mad_padre
                     AND t.cod_moneda = mon.cod_moneda
                     AND to_char(t.fec_valor, 'MMRRRR') = to_char(v_fec_mes_anterior, 'MMRRRR');
               EXCEPTION
                  WHEN no_data_found THEN
                     pas_snp.g_cod_error := 56;
                     pas_snp.g_msj_error := v_lugar || v_des_provision || ' inexistente.';
                     RAISE pas_snp.ex_salir;
                  WHEN OTHERS THEN
                     RAISE;
               END;
               IF mon.cod_moneda = pas_snp.g_cod_mon_local THEN
                  v_mto_mon_local := v_mto_rubro;
                  v_mto_rubro     := 0;
                  v_cotizacion    := NULL;
               ELSE
                  v_cotizacion    := pag_gen.fu_obt_cotizacion(mon.cod_moneda, v_fec_actual);
                  v_mto_mon_local := round(v_mto_rubro * v_cotizacion, v_can_dec_mon_local);
               END IF;
            END IF;

            -- Obteniendo los datos del rubro para la transacción de Provisión
            lp_obt_dat_rubro(v_cod_tra_provision, mon.cod_moneda, v_cod_rubro1, v_tip_mov_rubro1, v_cod_rubro2, v_tip_mov_rubro2);

            -- Solo para montos mayores a cero
            IF nvl(v_mto_mon_local, 0) > 0 THEN
               v_lugar := 'Obteniendo el Nro de Asiento, ';
               ------- Ve nro asiento -----------
               v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
               prg_act_par_dinamico('SIG_NRO_ASIENTO', NULL, NULL, NULL, NULL, (v_nro_asiento + 1));

               -- Se insertan los asientos de Provisión
               lp_ins_asientos_cab(v_cod_ofi_matriz, v_nro_asiento, v_fec_actual, CASE WHEN v_mto_rubro = 0 THEN v_mto_mon_local ELSE v_mto_rubro END);
               -- Detalle de asientos para el rubro 1
               lp_ins_asientos_det(v_fec_actual, v_cod_ofi_matriz, v_nro_asiento, 1, v_cod_rubro1, v_tip_mov_rubro1, nvl(v_mto_rubro, 0), v_mto_mon_local, v_des_provision, v_referencia, v_cotizacion);
               -- Detalle de asientos para el rubro 2
               lp_ins_asientos_det(v_fec_actual, v_cod_ofi_matriz, v_nro_asiento, 2, v_cod_rubro2, v_tip_mov_rubro2, nvl(v_mto_rubro, 0), v_mto_mon_local, v_des_provision, v_referencia, v_cotizacion);
            END IF;

            -- Se envía correo informando sobre las provisiones realizadas
            BEGIN
               IF pas_snp.g_gru_dir_correo IS NOT NULL THEN
                  it_mail.mail(fug_obt_dir_correo, pas_snp.g_gru_dir_correo, 'Se ha generado la Provisión de ' || v_des_provision || '.', 'Fecha Valor     : ' || to_char(v_fec_provision, 'DD/MM/YYYY') || chr(10) || 'Moneda          : ' || v_cod_moneda || chr(10) || 'Monto           : ' || v_mto_mon_local || chr(10) || chr(10) || 'Atentamente.');
               END IF;
            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
         END IF;
      END LOOP;
      -- Se envía correo informando sobre las provisiones realizadas por MT Recibido
      IF rg_msj.nro_referencia IS NOT NULL THEN
         BEGIN
            IF pas_snp.g_gru_dir_correo IS NOT NULL THEN
               it_mail.mail(fug_obt_dir_correo, pas_snp.g_gru_dir_correo, 'Se Procesó Transferencia Recibida por Provisión. ',
                            'Se recibió el MT de ' || v_des_provision || chr(10) || 'Fecha Valor     : ' || to_char(rg_msj.fec_valor, 'DD/MM/YYYY') || chr(10) || 'Nro. Referencia : ' || rg_msj.nro_referencia || chr(10) || 'Nro.Ref.Externa : ' || rg_msj.nro_ref_externa || chr(10) || 'Moneda          : ' || rg_msj.cod_moneda || chr(10) || 'Monto           : ' || rg_msj.monto || chr(10) || chr(10) || 'Atentamente.');
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
      END IF;
   END LOOP;

   IF p_tip_movimiento = 'R' THEN
      -- Se obtiene la descripción de la operación para el MT recibido
      v_des_provision := upper(pas_snp.fu_obt_des_tip_operacion(rg_msj.cod_msj_swift, rg_msj.cod_tip_operacion, rg_msj.cod_sub_tip_operacion));

      -- Obteniendo los datos del rubro para la transacción de Provisión
      lp_obt_dat_rubro(v_cod_tra_provision, rg_msj.cod_moneda, v_cod_rubro1, v_tip_mov_rubro1, v_cod_rubro2, v_tip_mov_rubro2);
      --
      -- Reversión de Movimientos Contables.
      v_lugar := 'Obteniendo el Monto del Asiento para la Reversión, ';
      BEGIN
         SELECT nvl((c.mto_mon_rubro * -1), 0), nvl((c.mto_mon_local * -1), 0), nvl(val_cotizacion, 0)
           INTO v_mto_rubro, v_mto_mon_local, v_cotizacion
           FROM cb_asientos_det_his c
          WHERE c.cod_oficina = v_cod_ofi_matriz
            AND c.cod_rubro = v_cod_rubro1
            AND c.tip_movimiento = v_tip_mov_rubro1
            AND upper(c.descripcion) = v_des_provision
            AND c.referencia = v_referencia
            AND c.mto_mon_local > 0
            AND c.fecha BETWEEN trunc(add_months(rg_msj.fec_valor,
                                                 CASE
                                                     WHEN v_fre_pag_provision = 'T' THEN
                                                      -3 -- Frecuencia de Pago Trimestral
                                                     ELSE
                                                      -1 -- Frecuencia de Pago Mensual
                                                  END), 'MON') AND last_day(add_months(rg_msj.fec_valor, -1))
            AND rownum = 1;
      EXCEPTION
         WHEN no_data_found THEN
            v_mto_rubro     := 0;
            v_mto_mon_local := 0;
            v_cotizacion    := 0;
         WHEN OTHERS THEN
            RAISE;
      END;
   END IF;

   -- Obteniendo los datos del rubro para la transacción de reversión
   lp_obt_dat_rubro(v_cod_tra_reversion, rg_msj.cod_moneda, v_cod_rubro1, v_tip_mov_rubro1, v_cod_rubro2, v_tip_mov_rubro2);

   -- Solo para montos menores a cero
   IF nvl(v_mto_mon_local, 0) < 0 AND p_tip_movimiento = 'R' THEN
      v_lugar := 'Obteniendo el Nro de Asiento, ';
      ------- Ve nro asiento -----------
      v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
      prg_act_par_dinamico('SIG_NRO_ASIENTO', NULL, NULL, NULL, NULL, (v_nro_asiento + 1));

      -- Se insertan los asientos de Reversión
      lp_ins_asientos_cab(v_cod_ofi_matriz, v_nro_asiento, v_fec_actual, CASE WHEN v_mto_rubro = 0 THEN v_mto_mon_local ELSE v_mto_rubro END);
      -- Detalle de asientos para el rubro 1
      lp_ins_asientos_det(v_fec_actual, v_cod_ofi_matriz, v_nro_asiento, 1, v_cod_rubro1, v_tip_mov_rubro1, nvl(v_mto_rubro, 0), v_mto_mon_local, v_des_provision, v_referencia, v_cotizacion);
      -- Detalle de asientos para el rubro 2
      lp_ins_asientos_det(v_fec_actual, v_cod_ofi_matriz, v_nro_asiento, 2, v_cod_rubro2, v_tip_mov_rubro2, nvl(v_mto_rubro, 0), v_mto_mon_local, v_des_provision, v_referencia, v_cotizacion);
   END IF;

EXCEPTION
    WHEN ex_msj_indefinido then
     null;
   WHEN pas_snp.ex_salir THEN
      lp_env_mai_error;
   WHEN OTHERS THEN
      pas_snp.g_cod_error := 56;
      pas_snp.g_msj_error := v_lugar || ' - ' || SQLERRM;
      lp_env_mai_error;
END prs_snp_gen_provision;
/

