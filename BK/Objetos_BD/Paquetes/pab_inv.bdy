CREATE OR REPLACE PACKAGE BODY IT.PAB_INV IS
   PROCEDURE pr_gen_sal_inventarios IS
   v_fecha           date := pag_cal.fu_obt_fec_actual(1);
   v_hor_inicio      varchar2(8);
   v_hor_fin         varchar2(8);
   v_can_dia_reg_log number := to_number(fug_obt_pardinamico('CAN_DIA_REG_LOG'));
   BEGIN
      ---DE-2320 - Optimización del proceso PAB_INV.PR_GEN_SAL_INVENTARIOS - DYD-SDSL-3367
      --Eliminar registros de dias atras configurado en parámetro--
      delete from ge_log_procesos g
      where g.fecha <= (v_fecha - v_can_dia_reg_log);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_gen_inv_libranza; ---Libranzas a Pagar
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_GEN_INV_LIBRANZA', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_tra_rec_cta_orden; --Cuentas de Orden
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_TRA_REC_CTA_ORDEN', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_doc_pendientes; --Documentos pendientes de confirmar moneda local
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_DOC_PENDIENTES', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_cam_ext; --Documentos pendientes de confirmacion cámara extranjera
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_CAM_EXT', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_cam_interna; --Cheques Recibidos Cámara Interna
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_CAM_INTERNA', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_trans_emi; --Transferencias a Emitir
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_TRANS_EMI', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_pres_inc; --Créditos Incobrables de Préstamos
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_PRES_INC', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_cam_48; --Cheques Recibidos 48 hs.
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_CAM_48', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_cam_act_24; --Cheques Compensación 24hs. Activo Cargo Otro
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_CAM_ACT_24', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_cam_pas_24; -- Cheques Compensación 24hs. Pasivo Cargo Nuestro
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_CAM_PAS_24', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_tar_noutilizada; -- Prestamos a utilizar mediante tarjetas de credito
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_TAR_NOUTILIZADA', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_car_sobregiros; -- Cargos por Sobregiros en Suspenso.
      prg_act_log_procesos('PAB_INV','PR_INV_CAR_SOBREGIROS', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_cam_loc_24h; -- Cheques a compensar camara local 24hs
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_CAM_LOC_24H', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_cam_ext_24h; -- Cheques recibidos a compensar 24hs. camara Extranjera
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_CAM_EXT_24H', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_com_exterior; -- Comercio exterior partidas acreedoras.
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_COM_EXTERIOR', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_cta_cte_contingencia; -- Contigencia de Cuentas Corrientes.
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_CTA_CTE_CONTINGENCIA', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_ing_var_caja; -- Ingresos varios por caja Clearing
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_ING_VAR_CAJA', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_cam_local; -- Documentos pendientes de confirmacion en camara local extranjera
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_CAM_LOCAL', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_ope_can_ven_cheques; --Operaciones a Cancelar Venta de Cheques
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_OPE_CAN_VEN_CHEQUES', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_che_cam_interna; --Cheques Recibido de Camara Interna
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_CHE_CAM_INTERNA', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_pag_proveedores; --Inventario de pago a proveedores pendientes.
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_PAG_PROVEEDORES', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_com_diferidas; --- Inventario de Comisiones Diferidas - A Devengar
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_COM_DIFERIDAS', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_val_custodia; -- Inventario de Valores en Custodia
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_VAL_CUSTODIA', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_dev_bon_subordinados; -- Devengados de Plusvalía y Minusvalía de los Bonos Subordinados.
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_DEV_BON_SUBORDINADOS', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      lp_acu_prev_comex; -- Previsiones de comex
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','LP_ACU_PREV_COMEX', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_embargos; -- Inventario de Cuentas Embargadas.
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_EMBARGOS', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_com_seguros; -- Inventario de Comisiones Seguros
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_COM_SEGUROS', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_cus_cheq; -- Inventario Custodia de Cheques
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_CUS_CHEQ', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_hor_extendido; -- Inventario de cheques horario extendido
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_HOR_EXTENDIDO', v_fecha, v_hor_inicio, v_hor_fin);
      --pr_inv_seg_fra; -- Inventario de Seguros cotra Fraude TD.
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_inv_vta_cartera; -- Inventario de Ventas de Cartera
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_INV_VTA_CARTERA', v_fecha, v_hor_inicio, v_hor_fin);
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      pr_tra_rec_ord_par; -- Transferencias Recibidas Cuentas de Orden en la 52
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_INV','PR_TRA_REC_ORD_PAR', v_fecha, v_hor_inicio, v_hor_fin);
   END;
   -- Obtiene el codigo de rubro que corresponde a una cuenta
   PROCEDURE fu_obt_cod_rubro
   (
      p_cod_modulo       IN NUMBER,
      p_cod_modalidad    IN NUMBER,
      p_cod_transaccion  IN NUMBER,
      p_cod_moneda       IN VARCHAR2,
      p_cod_sec_contable IN VARCHAR2,
      p_cod_tip_deudor   IN NUMBER,
      p_residente        IN VARCHAR2,
      p_cod_plazo        IN VARCHAR2,
      p_tip_movimiento   IN VARCHAR2,
      p_cod_rubro        IN OUT VARCHAR2,
      p_est_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_tip_renovacion   IN VARCHAR2 DEFAULT NULL,
      p_cat_automatica   IN NUMBER DEFAULT NULL,
      p_tip_interes      IN VARCHAR2 DEFAULT NULL,
      p_tip_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_cod_sit_contable IN NUMBER DEFAULT NULL,
      p_cod_sec_credito  IN NUMBER DEFAULT NULL
   ) IS
      v_cod_tip_asiento  ge_transacciones.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_transacciones.cod_tip_asiento2%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_ind_deudor       ge_tip_asientos.ind_deudor%TYPE;
      v_ind_plazo        ge_tip_asientos.ind_plazo%TYPE;
      v_ind_producto     ge_tip_asientos.ind_producto%TYPE;
   BEGIN
      /* busco la transaccion que le corresponde */
      SELECT tr.cod_tip_asiento, cod_tip_asiento2, cod_pro_contable
        INTO v_cod_tip_asiento, v_cod_tip_asiento2, v_cod_pro_contable
        FROM ge_modalidades mo, ge_transacciones tr
       WHERE tr.cod_modulo = p_cod_modulo
         AND tr.cod_modalidad = p_cod_modalidad
         AND tr.cod_transaccion = p_cod_transaccion
         AND mo.cod_modulo = p_cod_modulo
         AND mo.cod_modalidad = p_cod_modalidad;

      /* busco la cuenta contable que le corresponde */
      SELECT ind_plazo, ind_deudor, cod_rubro, ind_producto
        INTO v_ind_plazo, v_ind_deudor, p_cod_rubro, v_ind_producto
        FROM ge_tip_asientos
       WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
         AND cod_moneda = p_cod_moneda
         AND (cod_sec_contable IS NULL OR cod_sec_contable = p_cod_sec_contable)
         AND (tip_renovacion IS NULL OR tip_renovacion = nvl(p_tip_renovacion, 'A'))
         AND (tip_interes IS NULL OR tip_interes = p_tip_interes)
         AND (tip_cuenta IS NULL OR tip_cuenta = p_tip_cuenta)
         AND (cat_automatica IS NULL OR cat_automatica = p_cat_automatica)
         AND (est_cuenta IS NULL OR est_cuenta = p_est_cuenta)
         AND (ind_residente = 'X' OR ind_residente = p_residente)
         AND (cod_sit_contable = p_cod_sit_contable OR cod_sit_contable IS NULL)
         AND tip_movimiento = p_tip_movimiento
         AND nro_linea =
             (SELECT MIN(nro_linea)
                FROM ge_tip_asientos
               WHERE cod_tip_asiento = v_cod_tip_asiento
                 AND cod_moneda = p_cod_moneda
                 AND (cod_sec_contable IS NULL OR cod_sec_contable = p_cod_sec_contable)
                 AND (tip_renovacion IS NULL OR tip_renovacion = nvl(p_tip_renovacion, 'A'))
                 AND (tip_interes IS NULL OR tip_interes = p_tip_interes)
                 AND (tip_cuenta IS NULL OR tip_cuenta = p_tip_cuenta)
                 AND (cat_automatica IS NULL OR cat_automatica = p_cat_automatica)
                 AND (est_cuenta IS NULL OR est_cuenta = p_est_cuenta)
                 AND (ind_residente = 'X' OR ind_residente = p_residente)
                 AND (cod_sit_contable = p_cod_sit_contable OR cod_sit_contable IS NULL)
                 AND tip_movimiento = p_tip_movimiento);
      IF v_ind_plazo = 'S' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 2) || p_cod_plazo || substr(p_cod_rubro, 4, 12);
      END IF;
      IF v_ind_deudor = 'S' OR substr(p_cod_rubro, 9, 2) = 'TD' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 8) || (ltrim(to_char(p_cod_tip_deudor, '00'))) ||
                        substr(p_cod_rubro, 11, 5);
      END IF;
      ---Reemplaza el codigo del producto -----------------------
      IF v_ind_producto = 'S' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 10) || ltrim(to_char(v_cod_pro_contable, '000')) ||
                        substr(p_cod_rubro, 14, 2);
      END IF;
      IF substr(p_cod_rubro, 11, 3) = 'SEC' THEN
         -- es solo para prestamos, para contabilizar por sector
         p_cod_rubro := substr(p_cod_rubro, 1, 10) ||
                        ltrim(to_char(fup_obt_sec_rubro(p_cod_sec_credito), '000')) ||
                        substr(p_cod_rubro, 14, 2);
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         p_cod_rubro := NULL;
   END;
   ---FIN DE OBTENER RUBROS CONTABLES

   --Para obtener rubros contables caso de libranzas a pagar y cuentas de orden (caso especial)
   PROCEDURE fu_obt_tra_cod_rubro
   (
      p_cod_modulo       IN NUMBER,
      p_cod_modalidad    IN NUMBER,
      p_cod_transaccion  IN NUMBER,
      p_cod_moneda       IN VARCHAR2,
      p_cod_sec_contable IN VARCHAR2,
      p_cod_tip_deudor   IN NUMBER,
      p_residente        IN VARCHAR2,
      p_cod_plazo        IN VARCHAR2,
      p_tip_movimiento   IN VARCHAR2,
      p_cod_rubro        IN OUT VARCHAR2,
      p_est_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_cod_rub          IN VARCHAR2 DEFAULT NULL,
      p_tip_renovacion   IN VARCHAR2 DEFAULT NULL,
      p_cat_automatica   IN NUMBER DEFAULT NULL,
      p_tip_interes      IN VARCHAR2 DEFAULT NULL,
      p_tip_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_cod_sit_contable IN NUMBER DEFAULT NULL,
      p_cod_sec_credito  IN NUMBER DEFAULT NULL
   ) IS
      v_cod_tip_asiento  ge_transacciones.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_transacciones.cod_tip_asiento2%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_ind_deudor       ge_tip_asientos.ind_deudor%TYPE;
      v_ind_plazo        ge_tip_asientos.ind_plazo%TYPE;
      v_ind_producto     ge_tip_asientos.ind_producto%TYPE;
   BEGIN
      /* busco la transaccion que le corresponde */
      SELECT tr.cod_tip_asiento, cod_tip_asiento2, cod_pro_contable
        INTO v_cod_tip_asiento, v_cod_tip_asiento2, v_cod_pro_contable
        FROM ge_modalidades mo, ge_transacciones tr
       WHERE tr.cod_modulo = p_cod_modulo
         AND tr.cod_modalidad = p_cod_modalidad
         AND tr.cod_transaccion = p_cod_transaccion
         AND mo.cod_modulo = p_cod_modulo
         AND mo.cod_modalidad = p_cod_modalidad;

      /* busco la cuenta contable que le corresponde */
      SELECT ind_plazo, ind_deudor, cod_rubro, ind_producto
        INTO v_ind_plazo, v_ind_deudor, p_cod_rubro, v_ind_producto
        FROM ge_tip_asientos
       WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
         AND cod_moneda = p_cod_moneda
         AND (cod_sec_contable IS NULL OR cod_sec_contable = p_cod_sec_contable)
         AND (tip_renovacion IS NULL OR tip_renovacion = nvl(p_tip_renovacion, 'A'))
         AND (tip_interes IS NULL OR tip_interes = p_tip_interes)
         AND (tip_cuenta IS NULL OR tip_cuenta = p_tip_cuenta)
         AND (cat_automatica IS NULL OR cat_automatica = p_cat_automatica)
         AND (est_cuenta IS NULL OR est_cuenta = p_est_cuenta)
         AND (ind_residente = 'X' OR ind_residente = p_residente)
         AND (cod_sit_contable = p_cod_sit_contable OR cod_sit_contable IS NULL)
         AND tip_movimiento = p_tip_movimiento
         AND substr(cod_rubro, 1, 1) <> p_cod_rub
         AND nro_linea =
             (SELECT MIN(nro_linea)
                FROM ge_tip_asientos
               WHERE cod_tip_asiento = v_cod_tip_asiento
                 AND cod_moneda = p_cod_moneda
                 AND (cod_sec_contable IS NULL OR cod_sec_contable = p_cod_sec_contable)
                 AND (tip_renovacion IS NULL OR tip_renovacion = nvl(p_tip_renovacion, 'A'))
                 AND (tip_interes IS NULL OR tip_interes = p_tip_interes)
                 AND (tip_cuenta IS NULL OR tip_cuenta = p_tip_cuenta)
                 AND (cat_automatica IS NULL OR cat_automatica = p_cat_automatica)
                 AND (est_cuenta IS NULL OR est_cuenta = p_est_cuenta)
                 AND (ind_residente = 'X' OR ind_residente = p_residente)
                 AND (cod_sit_contable = p_cod_sit_contable OR cod_sit_contable IS NULL)
                 AND tip_movimiento = p_tip_movimiento
                 AND substr(cod_rubro, 1, 1) <> p_cod_rub);
      IF v_ind_plazo = 'S' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 2) || p_cod_plazo || substr(p_cod_rubro, 4, 12);
      END IF;
      IF v_ind_deudor = 'S' OR substr(p_cod_rubro, 9, 2) = 'TD' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 8) || (ltrim(to_char(p_cod_tip_deudor, '00'))) ||
                        substr(p_cod_rubro, 11, 5);
      END IF;
      ---Reemplaza el codigo del producto -----------------------
      IF v_ind_producto = 'S' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 10) || ltrim(to_char(v_cod_pro_contable, '000')) ||
                        substr(p_cod_rubro, 14, 2);
      END IF;
      IF substr(p_cod_rubro, 11, 3) = 'SEC' THEN
         -- es solo para prestamos, para contabilizar por sector
         p_cod_rubro := substr(p_cod_rubro, 1, 10) ||
                        ltrim(to_char(fup_obt_sec_rubro(p_cod_sec_credito), '000')) ||
                        substr(p_cod_rubro, 14, 2);
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         p_cod_rubro := NULL;
   END;
   --- fin del obtener codigo de rubro------------------------------------

   -- Transferencias Recibidas (Libranzas a pagar)
   PROCEDURE pr_gen_inv_libranza IS
      v_cod_modulo      cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad   cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_oficina     cb_sal_inventarios.cod_oficina%TYPE;
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_refe_tip        VARCHAR2(15);
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento  VARCHAR2(01);
      v_cod_plazo       NUMBER(03);
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_rub         VARCHAR2(02);

      ---cursor
      CURSOR transf IS
         SELECT nro_referencia,
                cod_tip_referencia,
                cod_modulo,
                cod_modalidad,
                cod_moneda,
                cod_oficina,
                nvl(fec_valor, fec_operacion),
                cod_per_beneficiario,
                estado,
                saldo,
                l.nom_beneficiario
           FROM lc_transferencias l
          WHERE cod_modalidad = 75
            AND estado IN ('PE', 'B')
            AND (nvl(fec_valor, fec_operacion) <= fue_obt_fec_calendar(7));

   BEGIN
      v_cod_plazo       := 1;
      v_tip_saldo       := 'C'; --capital - efectivo.
      v_tip_movimiento  := 'C';
      v_cod_oficina     := 31; --la contabilización siempre se hace en oficina 31
      v_cod_modulo      := 4;
      v_cod_modalidad   := 45;
      v_cod_transaccion := 1503;
      v_cod_rub         := 5;

      FOR i IN transf LOOP
         ----se obtiene el rubro contable que le corresponde
         fu_obt_tra_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, i.cod_moneda, NULL
                              /*i.cod_sec_contable*/, NULL /*i.cod_tip_deudor*/, NULL
                              /*i.residente*/, v_cod_plazo, v_tip_movimiento, v_cod_rubro, NULL
                              /*i.estado*/, v_cod_rub, NULL, /*v_tip_renovacion*/ NULL,
                              /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL, /*v_tip_operacion*/
                              NULL /*v_cod_sit_contable*/);
         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia;

            v_refe_tip := to_char(i.nro_referencia) || to_char(i.cod_tip_referencia);

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_refe_tip;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_refe_tip, i.saldo, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.saldo, 0) <> 0 THEN

                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, v_cod_oficina, NULL, NULL, NULL, i.cod_moneda,
                      NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, i.saldo, v_cod_rubro,
                      v_nro_referencia, NULL, NULL, NULL);

                  v_refe_tip := to_char(i.nro_referencia) || to_char(i.cod_tip_referencia);
                  IF nvl(i.saldo, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, v_refe_tip, i.saldo, 0);
                  END IF;

               END IF;
         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_GEN_INV_LIBRANZA:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de transferencia recibidas (libranzas a pagar)

   -- Transferencias Recibidas Cuentas de Orden
   PROCEDURE pr_tra_rec_cta_orden IS
      v_cod_oficina     cb_sal_inventarios.cod_oficina%TYPE;
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_refe_tip        VARCHAR2(15);
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento  VARCHAR2(01);
      v_cod_plazo       NUMBER(03);
      v_cod_modulo      cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad   cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_rub         VARCHAR(02);

      ---cursor
      CURSOR orden IS
         SELECT nro_referencia,
                cod_tip_referencia,
                cod_modulo,
                cod_modalidad,
                cod_moneda,
                cod_oficina,
                fec_valor,
                cod_per_beneficiario,
                estado,
                saldo,
                l.nom_beneficiario
           FROM lc_transferencias l
          WHERE cod_modalidad = 75
            AND estado = 'PE'
            AND nvl(fec_valor, fec_operacion) > fue_obt_fec_calendar(7)
          ORDER BY cod_moneda;

   BEGIN
      v_cod_plazo       := 1;
      v_tip_saldo       := 'C'; --capital - efectivo.
      v_cod_oficina     := 31;
      v_tip_movimiento  := 'C';
      v_cod_modulo      := 4;
      v_cod_modalidad   := 45;
      v_cod_transaccion := 1503;
      v_cod_rub         := 2;

      FOR i IN orden LOOP
         ----se obtiene el rubro contable que le corresponde
         fu_obt_tra_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, i.cod_moneda, NULL,
                              /*i.cod_sec_contable*/ NULL, /*i.cod_tip_deudor*/ NULL,
                              /*i.residente*/ v_cod_plazo, v_tip_movimiento, v_cod_rubro, NULL,
                              /*i.estado*/ v_cod_rub, NULL, /*v_tip_renovacion*/ NULL,
                              /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL, /*v_tip_operacion*/
                              NULL /*v_cod_sit_contable*/);

         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia;

            v_refe_tip := to_char(i.nro_referencia) || to_char(i.cod_tip_referencia);

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_refe_tip;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_refe_tip, i.saldo, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.saldo, 0) <> 0 THEN

                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, v_cod_oficina, NULL, NULL, NULL, i.cod_moneda,
                      NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, i.saldo, v_cod_rubro,
                      v_nro_referencia, NULL, NULL, NULL);

                  v_refe_tip := to_char(i.nro_referencia) || to_char(i.cod_tip_referencia);
                  IF nvl(i.saldo, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, v_refe_tip, i.saldo, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_TRA_REC_CTA_ORDEN:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Transferencias Recibidas Cuentas de Orden

   -- Documentos pendientes de confirmacion de moneda local
   PROCEDURE pr_inv_doc_pendientes IS
      v_tip_saldo      cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento VARCHAR2(01);
      v_cod_plazo      NUMBER(03);
      v_cod_rubro      cb_sal_inventarios.cod_rubro%TYPE;
      v_rowid          VARCHAR2(30);
      v_nro_referencia cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_mon_local  VARCHAR2(02);
      v_residente       ge_clientes.residente%type;
      v_cod_sec_contable ge_clientes.cod_sec_contable%type;
      v_cod_tip_deudor   ge_clientes.cod_tip_deudor%type;
      v_cat_riesgo       ge_clientes.cat_riesgo%type;

      ---cursor
      CURSOR doc IS
          --DE-2320 : Optimizacion PAV_INV--
    --DYDMR-4797 Incidencia SAU - ITGF - DE-2320 - pab_inv - Seguimiento en producción
          --Obs: Se reemplaza el uso del gv_movimientos--
         SELECT DISTINCT M.cod_transaccion,
                r.cod_modulo,
                r.cod_modalidad,
                m.concepto,
                r.cod_oficina,
                m.fecha,
                r.cod_moneda,
                r.nro_documento,
                r.sal_retenido,
                r.nro_cuenta
           FROM ah_retenciones r, ah_movimientos_his m, ge_ret_monedas x
          WHERE r.liberado = 'N'
            and r.fec_inicio<=m.FECHA
            AND m.nro_documento = r.nro_documento
            AND r.nro_cuenta = m.nro_cuenta
            AND r.monto = m.monto
            AND r.cod_retencion = m.cod_retencion
            AND m.reversado = 'N'
            AND m.cod_moneda = v_cod_mon_local
            AND m.cod_transaccion <> 606
            and x.cod_retencion = r.cod_retencion
            and x.cod_moneda = r.cod_moneda
            and m.fecha >= (r.fec_inicio-x.can_dias)
          union
          SELECT DISTINCT M.cod_transaccion,
                r.cod_modulo,
                r.cod_modalidad,
                m.concepto,
                r.cod_oficina,
                m.fecha,
                r.cod_moneda,
                r.nro_documento,
                r.sal_retenido,
                r.nro_cuenta
           FROM ah_retenciones r, cc_movimientos_his m, ge_ret_monedas x
          WHERE r.liberado = 'N'
            and r.fec_inicio<=m.FECHA
            AND m.nro_documento = r.nro_documento
            AND r.nro_cuenta = m.nro_cuenta
            AND r.monto = m.monto
            AND r.cod_retencion = m.cod_retencion
            AND m.reversado = 'N'
            AND m.cod_moneda = v_cod_mon_local
            AND m.cod_transaccion <> 606
            and x.cod_retencion = r.cod_retencion
            and x.cod_moneda = r.cod_moneda
            and m.fecha >= (r.fec_inicio-x.can_dias)
          union
          SELECT DISTINCT M.cod_transaccion,
                r.cod_modulo,
                r.cod_modalidad,
                m.concepto,
                r.cod_oficina,
                m.fecha,
                r.cod_moneda,
                r.nro_documento,
                r.sal_retenido,
                r.nro_cuenta
           FROM ah_retenciones r, pr_movimientos_his m, ge_ret_monedas x
          WHERE r.liberado = 'N'
            and r.fec_inicio<=m.FECHA
            AND m.nro_documento = r.nro_documento
            AND r.nro_cuenta = m.nro_cuenta
            AND r.monto = m.monto
            AND r.cod_retencion = m.cod_retencion
            AND m.reversado = 'N'
            AND m.cod_moneda = v_cod_mon_local
            AND m.cod_transaccion <> 606
            and x.cod_retencion = r.cod_retencion
            and x.cod_moneda = r.cod_moneda
            and m.fecha >= (r.fec_inicio-x.can_dias)
          union
          SELECT DISTINCT M.cod_transaccion,
                r.cod_modulo,
                r.cod_modalidad,
                m.concepto,
                r.cod_oficina,
                m.fecha,
                r.cod_moneda,
                r.nro_documento,
                r.sal_retenido,
                r.nro_cuenta
           FROM ah_retenciones r, ta_movimientos_his m, ge_ret_monedas x
          WHERE r.liberado = 'N'
            and r.fec_inicio<=m.FECHA
            AND m.nro_documento = r.nro_documento
            AND r.nro_cuenta = m.nro_cuenta
            AND r.monto = m.monto
            AND r.cod_retencion = m.cod_retencion
            AND m.reversado = 'N'
            AND m.cod_moneda = v_cod_mon_local
            AND m.cod_transaccion <> 606
            and x.cod_retencion = r.cod_retencion
            and x.cod_moneda = r.cod_moneda
            and m.fecha >= (r.fec_inicio-x.can_dias);

   BEGIN
      v_cod_plazo      := 1;
      v_tip_saldo      := 'R'; --capital - efectivo.
      v_tip_movimiento := 'C';
      v_cod_mon_local  := pag_gen.fu_obt_mon_local;
      FOR i IN doc LOOP

         BEGIN
            select c.residente,
                   c.cod_sec_contable,
                   c.cod_tip_deudor,
                   c.cat_riesgo
              into v_residente,
                   v_cod_sec_contable,
                   v_cod_tip_deudor,
                   v_cat_riesgo
              from ge_cta_clientes g, ge_clientes c
             where g.cod_persona = c.cod_persona
               AND g.relacion = 'P'
               and g.nro_cuenta=i.nro_cuenta;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
                 v_cod_sec_contable := NULL;
                 v_cod_tip_deudor := null;
                 v_cat_riesgo := null;
                 v_residente := null;
         END;
         --- busco la cuenta que le corresponde al saldo ----
         fu_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, i.cod_transaccion, i.cod_moneda, NULL,
                          --/*v_cod_sector*/
                          NULL, /*v_tip_deudor*/ NULL, /*v_residente*/ to_char(v_cod_plazo),
                          v_tip_movimiento, v_cod_rubro, NULL, /*v_estado*/ NULL,
                          /*v_tip_renovacion*/ NULL, /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL,
                          /*v_tip_operacion*/ NULL /*v_cod_sit_contable*/);
         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND tip_saldo = v_tip_saldo
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.sal_retenido
             WHERE nro_referencia = v_nro_referencia
               AND ROWID = v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.sal_retenido
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.sal_retenido, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.sal_retenido, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, v_cod_sec_contable,
                      v_cod_tip_deudor, v_residente, i.cod_moneda, NULL, v_tip_saldo, v_cod_plazo,
                      NULL, NULL, i.sal_retenido, v_cod_rubro, v_nro_referencia, NULL, v_cat_riesgo,
                      NULL);

                  IF nvl(i.sal_retenido, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.sal_retenido, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_DOC_PENDIENTES:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Documentos pendientes de confirmacion

   -- Documentos pendientes de confirmacion cámara extranjera
   PROCEDURE pr_inv_cam_ext IS
      v_tip_saldo      cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento VARCHAR2(01);
      v_cod_plazo      NUMBER(03);
      v_cod_rubro      cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_referencia cb_sal_inventarios.nro_referencia%TYPE;

      ---cursor
      CURSOR ext IS
         SELECT t.nro_cuenta,
                t.cod_modulo,
                t.cod_modalidad,
                t.cod_oficina,
                t.cod_moneda,
                e.cod_transaccion,
                c.residente,
                c.cod_sec_contable,
                c.cat_riesgo,
                t.liberado estado,
                t.sal_retenido
           FROM ah_retenciones t, ge_transacciones e, ge_cta_clientes g, ge_clientes c
          WHERE t.liberado = 'N'
            AND e.cod_retencion IS NOT NULL
            AND t.cod_modulo = e.cod_modulo
            AND t.cod_modalidad = e.cod_modalidad
            AND t.cod_retencion = e.cod_retencion
            AND g.cod_persona = c.cod_persona
            AND t.nro_cuenta = g.nro_cuenta
            AND g.relacion = 'P'
            AND e.cod_transaccion IN (633);

   BEGIN
      v_cod_plazo      := 1;
      v_tip_saldo      := 'R'; --Retenido
      v_tip_movimiento := 'C';

      FOR i IN ext LOOP

         --- busco la cuenta que le corresponde al saldo ----
         fu_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, i.cod_transaccion, i.cod_moneda,
                          i.cod_sec_contable, NULL, /*v_tip_deudor*/ i.residente,
                          to_char(v_cod_plazo), v_tip_movimiento, v_cod_rubro, NULL, /*v_estado*/
                          NULL, /*v_tip_renovacion*/ i.cat_riesgo, NULL, /*v_tip_interes*/ NULL,
                          /*v_tip_operacion*/ NULL /*v_cod_sit_contable*/);
         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND tip_saldo = v_tip_saldo
               AND cod_sec_contable = i.cod_sec_contable
               AND situacion = i.estado
               AND residente = i.residente
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.sal_retenido
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.sal_retenido
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.sal_retenido, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.sal_retenido, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.cod_sec_contable, NULL,
                      i.residente, i.cod_moneda, i.estado, v_tip_saldo, v_cod_plazo, NULL, NULL,
                      i.sal_retenido, v_cod_rubro, v_nro_referencia, NULL, i.cat_riesgo, NULL);

                  IF nvl(i.sal_retenido, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.sal_retenido, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_CAM_EXT:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Documentos pendientes de confirmacion cámara extranjera

   -- Cheques Recibidos Cámara Interna
   PROCEDURE pr_inv_cam_interna IS
      v_tip_saldo      cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento VARCHAR2(01);
      v_cod_plazo      NUMBER(03);
      v_cod_rubro      cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_referencia cb_sal_inventarios.nro_referencia%TYPE;

      ---cursor
      CURSOR inter IS
         SELECT t.nro_cuenta,
                t.cod_modulo,
                t.cod_modalidad,
                t.cod_oficina,
                t.cod_moneda,
                e.cod_transaccion,
                c.residente,
                c.cod_sec_contable,
                c.cat_riesgo,
                t.liberado estado,
                t.sal_retenido
           FROM ah_retenciones t, ge_transacciones e, ge_cta_clientes g, ge_clientes c
          WHERE t.liberado = 'N'
            AND e.cod_retencion IS NOT NULL
            AND t.cod_modulo = e.cod_modulo
            AND t.cod_modalidad = e.cod_modalidad
            AND t.cod_retencion = e.cod_retencion
            AND g.cod_persona = c.cod_persona
            AND t.nro_cuenta = g.nro_cuenta
            AND g.relacion = 'P'
            AND e.cod_transaccion IN (606);

   BEGIN
      v_cod_plazo      := 1;
      v_tip_saldo      := 'R'; --Retenido
      v_tip_movimiento := 'D';

      FOR i IN inter LOOP

         --- busco la cuenta que le corresponde al saldo ----
         fu_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, i.cod_transaccion, i.cod_moneda,
                          i.cod_sec_contable, NULL, /*v_tip_deudor*/ i.residente,
                          to_char(v_cod_plazo), v_tip_movimiento, v_cod_rubro, NULL, /*v_estado*/
                          NULL, /*v_tip_renovacion*/ i.cat_riesgo, NULL, /*v_tip_interes*/ NULL,
                          /*v_tip_operacion*/ NULL /*v_cod_sit_contable*/);
         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND tip_saldo = v_tip_saldo
               AND cod_sec_contable = i.cod_sec_contable
               AND situacion = i.estado
               AND residente = i.residente
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.sal_retenido
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.sal_retenido
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.sal_retenido, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.sal_retenido, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.cod_sec_contable, NULL,
                      i.residente, i.cod_moneda, i.estado, v_tip_saldo, v_cod_plazo, NULL, NULL,
                      i.sal_retenido, v_cod_rubro, v_nro_referencia, NULL, i.cat_riesgo, NULL);

                  IF nvl(i.sal_retenido, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.sal_retenido, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_CAM_INTERNA:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Cheques Recibidos Cámara Interna

   -- Transferencias a Emitir
   PROCEDURE pr_inv_trans_emi IS
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_rowid           VARCHAR2(30);
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_refe_tip        VARCHAR2(15);
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento  VARCHAR2(01);
      v_cod_plazo       NUMBER(03);
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      ---cursor
      CURSOR emit IS
         SELECT nro_referencia,
                cod_tip_referencia,
                cod_modulo,
                cod_modalidad,
                cod_moneda,
                cod_oficina,
                nvl(fec_valor, fec_operacion),
                cod_per_beneficiario,
                estado,
                monto
           FROM lc_transferencias
          WHERE cod_modalidad = 72
            AND estado IN ('P', 'C', 'PE');

   BEGIN
      v_cod_plazo       := 1;
      v_tip_saldo       := 'C'; --capital - efectivo.
      v_tip_movimiento  := 'C';
      v_cod_transaccion := 264;

      FOR i IN emit LOOP
         ----se obtiene el rubro contable que le corresponde
         pab_inv.fu_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, v_cod_transaccion, i.cod_moneda,
                                  NULL, /*i.cod_sec_contable*/ NULL, /*i.cod_tip_deudor*/ NULL,
                                  /*i.residente*/ v_cod_plazo, v_tip_movimiento, v_cod_rubro, NULL,
                                  /*i.estado*/ NULL, /*v_tip_renovacion*/ NULL, /*v_cat_riesgo*/
                                  NULL, /*v_tip_interes*/ NULL, /*v_tip_operacion*/ NULL
                                  /*v_cod_sit_contable*/);

         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_plazo = v_cod_plazo
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia
               AND ROWID = v_rowid;

            v_refe_tip := to_char(i.nro_referencia) || to_char(i.cod_tip_referencia);

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_refe_tip;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_refe_tip, i.monto, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.monto, 0) <> 0 THEN

                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, NULL, NULL, NULL, i.cod_moneda,
                      NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, i.monto, v_cod_rubro,
                      v_nro_referencia, NULL, NULL, NULL);

                  v_refe_tip := to_char(i.nro_referencia) || to_char(i.cod_tip_referencia);
                  IF nvl(i.monto, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, v_refe_tip, i.monto, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_TRANS_EMI:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de transferencia  a emitir

   -- Créditos Incobrables Préstamos
   PROCEDURE pr_inv_pres_inc IS
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento  VARCHAR2(01);
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_cod_rubro_2     cb_sal_inventarios.cod_rubro%TYPE;
      v_sal_total       cb_sal_inventarios.sal_total%TYPE;
      v_sal_negativo    NUMBER;
      v_nro_cuenta      ge_cta_clientes.nro_cuenta%type;

      ---cursor
      CURSOR pres IS
         SELECT a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                a.nro_cuenta,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                a.cod_moneda,
                a.tip_interes,
                to_number(nvl(c.cat_riesgo, 1)) cat_riesgo,
                a.cod_sec_credito,
                a.est_batch,
                a.tipo,
                a.tip_renovacion,
                cod_plazo,
                (nvl(a.sal_cap_batch, 0) + nvl(a.sal_int_batch, 0) + nvl(a.val_int_devengar, 0) +
                nvl(a.dev_no_cobrado, 0) + nvl(a.sal_int_ade_batch, 0)) saldo
           FROM ge_plz_contables d, ge_clientes c, ge_cta_clientes b, pr_cta_prestamos a
          WHERE b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND c.cod_persona = b.cod_persona
            AND a.est_batch = 'I'
            AND can_dias = (SELECT MIN(can_dias)
                              FROM ge_plz_contables
                             WHERE can_dias >= a.fec_vencimiento - a.fec_inicio)
         UNION ALL
         SELECT t.cod_modulo,
                t.cod_modalidad,
                t.cod_oficina,
                t.nro_cuenta,
                ge.cod_sec_contable,
                ge.cod_tip_deudor,
                ge.residente,
                t.cod_moneda,
                'V' tip_interes,
                fup_obt_categoria(ge.cat_automatica, ge.cat_subjetiva) cat_riesgo,
                11 cod_sec_credito,
                t.est_batch,
                'A' tipo,
                'A' tip_renovacion,
                1 cod_plazo,
                t.sal_tot_batch saldo
           FROM ov_cta_vencidas t,
                ge_clientes ge,
                ge_cta_clientes gcc,
                (SELECT a.monto, a.nro_cuenta
                   FROM ov_previsiones a
                  WHERE a.fecha =
                        (SELECT MAX(b.fecha) FROM ov_previsiones b WHERE a.nro_cuenta = b.nro_cuenta)) ov_previsiones,
                (SELECT nvl(ov.tot_val_saldo, 0) + nvl(ov.tot_val_garantia, 0) +
                        nvl(ov.tot_val_prevision, 0) mto_valuado,
                        ov.nro_cuenta
                   FROM ov_valuaciones ov) ov_valuaciones
          WHERE t.nro_cuenta = gcc.nro_cuenta
            AND ge.cod_persona = gcc.cod_persona
            AND gcc.relacion = 'P'
            AND t.est_batch = 'I'
            AND ov_previsiones.nro_cuenta(+) = t.nro_cuenta
            AND ov_valuaciones.nro_cuenta(+) = t.nro_cuenta;

   BEGIN
      v_tip_saldo       := 'C'; --'I'; --Incobrables.
      v_tip_movimiento  := 'D';
      v_cod_transaccion := 959;
      FOR i IN pres LOOP
         v_nro_cuenta := i.nro_cuenta;
         fu_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, v_cod_transaccion, i.cod_moneda,
                          i.cod_sec_contable, i.cod_tip_deudor, i.residente, to_char(i.cod_plazo),
                          v_tip_movimiento, v_cod_rubro, i.est_batch, i.tip_renovacion, i.cat_riesgo,
                          i.tip_interes, i.tipo, i.cod_sec_credito);

         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_sec_contable = i.cod_sec_contable
               AND cod_tip_deudor = i.cod_tip_deudor
               AND residente = i.residente
               AND situacion = i.est_batch
               AND cod_plazo = i.cod_plazo
               AND tip_operacion = i.tipo
               AND tip_renovacion = i.tip_renovacion
               AND tip_interes = i.tip_interes
               AND cat_automatica = i.cat_riesgo
               AND cod_sit_contable = i.cod_sec_credito
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.saldo, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.saldo, 0) <> 0 THEN

                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.cod_sec_contable,
                      i.cod_tip_deudor, i.residente, i.cod_moneda, i.est_batch, v_tip_saldo,
                      i.cod_plazo, i.tipo, i.tip_interes, i.saldo, v_cod_rubro,     /*DYDMR-6598 - 10/05/2017 se reemplaza i.tip_renovacion por i.tipo*/
                      v_nro_referencia, i.tip_renovacion, i.cat_riesgo, i.cod_sec_credito);

                  IF nvl(i.saldo, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.saldo, 0);
                  END IF;

               END IF;

         END;

         --------------------------------------------------------------------------------------
         --Inicio Inserción Inventario de tipo Crédito

         fu_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, 960, i.cod_moneda, NULL,
                          /*i.cod_sec_contable*/ NULL, /*i.cod_tip_deudor*/ NULL,
                          --i.residente
                          NULL, 'C', v_cod_rubro_2, NULL, /*i.estado*/ NULL, /*v_tip_renovacion*/
                          NULL, /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL, /*v_tip_operacion*/
                          NULL /*v_cod_sit_contable*/);

         BEGIN
            SELECT nro_referencia, sal_total
              INTO v_nro_referencia, v_sal_total
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_sec_contable = i.cod_sec_contable
               AND cod_tip_deudor = i.cod_tip_deudor
               AND residente = i.residente
               AND situacion = i.est_batch
               AND cod_plazo = i.cod_plazo
               AND tip_operacion = i.tipo
               AND tip_renovacion = i.tip_renovacion
               AND tip_interes = i.tip_interes
               AND cat_automatica = i.cat_riesgo
               AND cod_sit_contable = i.cod_sec_credito
               AND cod_rubro = v_cod_rubro_2;

            -- Verificamos si el valor total del inventario ya se encuentra en negativo
            IF nvl(v_sal_total, 0) > 0 THEN
               v_sal_negativo := NULL;
            ELSE
               v_sal_negativo := 1;
            END IF;

            UPDATE cb_sal_inventarios
               SET sal_total =
                   (nvl(sal_total, 0) * nvl(v_sal_negativo, -1)) + (i.saldo * -1)
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual =
                   (nvl(sal_actual, 0) * nvl(v_sal_negativo, -1)) + (i.saldo * -1)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, (i.saldo * -1), 0);
            END IF;
            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.saldo, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.cod_sec_contable,
                      i.cod_tip_deudor, i.residente, i.cod_moneda, i.est_batch, v_tip_saldo,
                      i.cod_plazo, i.tipo, i.tip_interes, (i.saldo * -1), v_cod_rubro_2,    /*DYDMR-6598 - 10/05/2017 se reemplaza i.tip_renovacion por i.tipo*/
                      v_nro_referencia, i.tip_renovacion, i.cat_riesgo, i.cod_sec_credito);

                  IF nvl(i.saldo, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, (i.saldo * -1), 0);
                  END IF;
               END IF;
         END;

      --     Fin Inserción Inventario de tipo Crédito
      --------------------------------------------------------------------------------------
      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_PRES_INC:' || SQLERRM||' Nro. Cuenta: '||v_nro_cuenta);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- Créditos Incobrables Préstamos

   -- Cheques Recibidos 48 hs.
   PROCEDURE pr_inv_cam_48 IS
      v_tip_saldo      cb_sal_inventarios.tip_saldo%TYPE;
      v_cod_plazo      NUMBER(03);
      v_nro_referencia cb_sal_inventarios.nro_referencia%TYPE;
      v_fecha          date;

      ---cursor
      CURSOR inv IS
         SELECT d.cod_rubro,
                m.cod_modulo,
                m.cod_modalidad,
                m.cod_moneda,
                'E' estado,
                m.nro_cuenta,
                d.tip_movimiento,
                m.reversado,
                m.monto saldo,
                m.cod_transaccion,
                d.cod_oficina,
                g.residente,
                g.cod_sec_contable,
                g.cat_riesgo,
                g.cod_tip_deudor
           FROM ge_movimientos         m,
                cb_asi_automaticos_det d,
                ge_transacciones       t,
                ge_cuentas             c,
                ge_cta_clientes        cc,
                ba_personas            p,
                ge_clientes            g
          WHERE m.nro_documento4 = d.ref_movimiento
          and d.fecha=v_fecha
            AND m.fecha = d.fecha
            AND m.cod_mod_padre = t.cod_modulo
            AND m.cod_mad_padre = t.cod_modalidad
            AND m.cod_tra_padre = t.cod_transaccion
            AND d.cod_rubro = '111201110400399' /*and d.tip_movimiento = 'D'*/
            AND m.nro_cuenta = c.nro_cuenta
            AND m.nro_cuenta = cc.nro_cuenta
            AND cc.cod_persona = p.cod_persona
            AND g.cod_persona = cc.cod_persona
            AND g.cod_persona = p.cod_persona
            AND m.cod_transaccion <> 905
            AND cc.relacion = 'P'
               -- Muestra los reversados solo si no son del día.
            AND m.reversado = 'N'
            --DYDMR-5880 - No se deben exponer en ningún caso los Depósitos Reversados.-
            --AND (m.reversado = 'N' OR (m.reversado = 'S' AND m.fecha <> m.fec_valor))
 UNION ALL
          SELECT -- Codigo de la persona
            d.cod_rubro,
            m.cod_modulo,
            m.cod_modalidad,
            m.cod_moneda,
            'E' estado,
             -- Nro de la Cuenta
            CASE
            WHEN m.cod_mod_padre = 9 AND m.cod_mad_padre = 91 AND m.cod_tra_padre = 360 AND
            m.monto > 0 THEN
            ltrim(rtrim(substr(m.concepto, 14)))
            WHEN m.cod_modulo = 7 THEN
            m.cod_persona
            ELSE
            to_char(m.nro_documento)
            END nro_cuenta,
            d.tip_movimiento,
            m.reversado,
            m.monto saldo,
            m.cod_transaccion,
            d.cod_oficina,
            'X' residente,
            'X' cod_sec_contable,
            '0' cat_riesgo,
            0 cod_tip_deudor
          FROM ge_movimientos m, cb_asi_automaticos_det d, ge_transacciones t, ba_modulos o
          WHERE m.nro_documento4 = d.ref_movimiento
            and d.fecha=v_fecha
            AND m.fecha = d.fecha
            AND m.cod_mod_padre = o.cod_modulo
            AND m.cod_mod_padre = t.cod_modulo
            AND m.cod_mad_padre = t.cod_modalidad
            AND m.cod_tra_padre = t.cod_transaccion
            AND d.cod_rubro = '111201110400399'
            AND m.cod_transaccion <> 905
            AND m.nro_cuenta IS NULL
            AND (m.reversado = 'N' OR (m.reversado = 'S' AND m.fecha <> m.fec_valor));

   BEGIN
      v_cod_plazo := 1;
      v_tip_saldo := 'R'; --Retenido
      v_fecha:=pag_cal.FU_OBT_FEC_ACTUAL(1);

      FOR i IN inv LOOP

         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND tip_saldo = v_tip_saldo
               AND cod_sec_contable = i.cod_sec_contable
               AND situacion = i.estado
               AND residente = i.residente
               AND cat_automatica = i.cat_riesgo
               AND cod_rubro = i.cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.saldo, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.saldo, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.cod_sec_contable,
                      i.cod_tip_deudor, i.residente, i.cod_moneda, i.estado, v_tip_saldo,
                      v_cod_plazo, NULL, NULL, i.saldo, i.cod_rubro, v_nro_referencia, NULL,
                      i.cat_riesgo, NULL);

                  IF nvl(i.saldo, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.saldo, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_CAM_48:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Cheques Recibidos 48 hs.

   -- Cheques Compensación 24hs. Activo Cargo Otro
   PROCEDURE pr_inv_cam_act_24 IS
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_cod_plazo       NUMBER(03);
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_fec_actual      DATE := pag_cal.fu_obt_fec_actual(4);
      v_cod_modulo      cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad   cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_tip_movimiento  VARCHAR2(01);
      v_cod_mon_local   VARCHAR2(02);
      v_residente       VARCHAR2(01);

      ---cursor
      CURSOR act IS
         SELECT a.nro_cheque, a.cod_oficina, b.tipo, a.monto saldo
           FROM ge_bancos b, cc_che_remitidos a
          WHERE a.cod_banco = b.cod_banco
            and nvl(a.tip_dato,1) = 1  -- /* 16/10/2013 PN DI: Debe traer solo cheques en GS.*/
            AND fecha = v_fec_actual
            AND a.retencion = '24';

   BEGIN
      v_cod_plazo       := 1;
      v_tip_saldo       := 'R'; --Retenido
      v_cod_modulo      := 4;
      v_cod_modalidad   := 41;
      v_cod_transaccion := 192;
      v_tip_movimiento  := 'D';
      v_cod_mon_local   := pag_gen.fu_obt_mon_local;
      v_residente       := 'X';

      FOR i IN act LOOP
         --- busco la cuenta que le corresponde al saldo ----
         fu_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_mon_local, NULL,
                          /*i.cod_sec_contable*/ NULL, /*v_tip_deudor*/ v_residente,
                          to_char(v_cod_plazo), v_tip_movimiento, v_cod_rubro, NULL, /*v_estado*/
                          NULL, /*v_tip_renovacion*/ NULL, /*i.cat_riesgo*/ NULL, /*v_tip_interes*/
                          NULL, /*v_tip_operacion*/ NULL /*v_cod_sit_contable*/);

         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = v_cod_mon_local
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND residente = v_residente
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cheque;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cheque, i.saldo, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.saldo, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, i.cod_oficina, NULL, NULL, v_residente,
                      v_cod_mon_local, NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, i.saldo,
                      v_cod_rubro, v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(i.saldo, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cheque, i.saldo, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_CAM_ACT_24:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Cheques Compensación 24hs. Activo Cargo Otro

   -- Cheques Compensación 24hs. Pasivo Cargo Nuestro
   PROCEDURE pr_inv_cam_pas_24 IS
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_cod_plazo       NUMBER(03);
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_fec_actual      DATE := pag_cal.fu_obt_fec_actual(4);
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_tip_movimiento  VARCHAR2(01);
      v_cod_mon_local   VARCHAR2(02);

      ---cursor
      CURSOR act IS
         SELECT t.nro_cheque,
                t.nro_cuenta,
                t.cod_ofi_camara,
                c.residente,
                c.cat_riesgo,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                g.cod_modulo,
                g.cod_modalidad,
                t.monto
           FROM cc_che_recibidos t, ge_cta_clientes g, ge_clientes c
          WHERE t.fec_proceso = v_fec_actual
            AND t.tip_importe = 0
            AND t.est_cheque = 'P'
            AND t.com_directa = 'N'
            AND g.cod_persona = c.cod_persona
            AND t.nro_cuenta = g.nro_cuenta
            AND g.relacion = 'P';

   BEGIN
      v_cod_plazo       := 1;
      v_tip_saldo       := 'R'; --Retenido
      v_cod_transaccion := 521;
      v_tip_movimiento  := 'C';
      v_cod_mon_local   := pag_gen.fu_obt_mon_local;

      FOR i IN act LOOP
         --- busco la cuenta que le corresponde al saldo ----
         fu_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, v_cod_transaccion, v_cod_mon_local, NULL,
                          /*i.cod_sec_contable*/ NULL, /*v_tip_deudor*/ i.residente,
                          to_char(v_cod_plazo), v_tip_movimiento, v_cod_rubro, NULL, /*v_estado*/
                          NULL, /*v_tip_renovacion*/ NULL, /*i.cat_riesgo*/ NULL, /*v_tip_interes*/
                          NULL, /*v_tip_operacion*/ NULL /*v_cod_sit_contable*/);

         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_ofi_camara
               AND cod_moneda = v_cod_mon_local
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND residente = i.residente
               AND cod_tip_deudor = i.cod_tip_deudor
               AND cod_sec_contable = i.cod_sec_contable
               AND cat_automatica = i.cat_riesgo
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.monto, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.monto, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_ofi_camara, i.cod_sec_contable, NULL,
                      i.residente, v_cod_mon_local, NULL, v_tip_saldo, v_cod_plazo, NULL, NULL,
                      i.monto, v_cod_rubro, v_nro_referencia, NULL, i.cat_riesgo, NULL);

                  IF nvl(i.monto, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.monto, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_CAM_PAS_24:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Cheques Compensación 24hs. Pasivo Cargo Nuestro

   -- Prestamos a utilizar mediante tarjetas de credito
    PROCEDURE pr_inv_tar_noutilizada IS
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_cod_plazo       NUMBER(03);
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_fec_actual      DATE := pag_cal.fu_obt_fec_actual(4);
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_tip_movimiento  cb_sal_inventarios.tip_saldo%TYPE;
      v_cod_mon_local   VARCHAR2(02);
      v_msj             VARCHAR2(4000) := null;

   BEGIN
      v_cod_plazo       := 1;
      v_tip_saldo       := 'O'; --O = Saldo Contingente
      v_cod_transaccion := 224;
      v_cod_mon_local   := pag_gen.fu_obt_mon_local;
      
    -----------------------------------------------------------------------------------
    -- PASO 1: Cargar y preparar TODOS los datos en la tabla temporal
    -----------------------------------------------------------------------------------
    -- Limpiamos tabla temporal
    sql_util.ejecute_dml('truncate table cb_sal_movimientos',v_msj); 

    -- Insertamos en la tabla temporal los datos base del cursor
    -- y ya calculamos los dos cod_rubro (débito y crédito) al mismo tiempo.
    INSERT INTO cb_sal_movimientos (
        nro_cuenta, cod_oficina, residente, cod_sec_contable, cod_tip_deudor,
        cod_modulo, cod_modalidad, sal_total, cat_riesgo, 
        cod_rub_debito, cod_rub_credito -- Columnas temporales para los rubros
    )
    SELECT
        t.nro_cuenta, t.cod_oficina, c.residente, c.cod_sec_contable,
        c.cod_tip_deudor, g.cod_modulo, g.cod_modalidad,
        (CASE WHEN t.estado != 'B' THEN
                         (CASE WHEN (nvl(t.sal_facturar,0) + nvl(t.sal_facturado,0)+ nvl(t.sal_financiado,0) + nvl(t.sal_cuo_pendientes,0))> (NVL(t.lin_credito, 0) + NVL(t.lin_cuotas, 0)) THEN 0
                               WHEN (nvl(t.sal_facturar,0) + nvl(t.sal_facturado,0)+ nvl(t.sal_financiado,0) + nvl(t.sal_cuo_pendientes,0)) <= 0 THEN (NVL(t.lin_credito, 0) + NVL(t.lin_cuotas, 0))
                               ELSE ((NVL(t.lin_credito, 0) + NVL(t.lin_cuotas, 0)) - (nvl(t.sal_facturar,0) + nvl(t.sal_facturado,0)+ nvl(t.sal_financiado,0) + nvl(t.sal_cuo_pendientes,0)))
                         END)
                      ELSE 0
                 END) monto, 
        c.cat_riesgo,
    -- Llamamos a la función para obtener el rubro de Débito
        fub_obt_rub_transaccion(g.cod_modulo, g.cod_modalidad, v_cod_transaccion, v_cod_mon_local,
                                                c.cod_persona, to_char(v_cod_plazo), 'D'),
    -- Llamamos a la función para obtener el rubro de Crédito
        fub_obt_rub_transaccion(g.cod_modulo, g.cod_modalidad, v_cod_transaccion, v_cod_mon_local,
                                                c.cod_persona, to_char(v_cod_plazo), 'C')
    FROM ta_cta_tarjetas t
    JOIN ge_cta_clientes g ON t.nro_cuenta = g.nro_cuenta
    JOIN ge_clientes c ON g.cod_persona = c.cod_persona
    WHERE g.relacion = 'P'
      AND t.estado <> 'C';
   -----------------------------------------------------------------------------------
    -- PASO 2: MERGE para los movimientos de DÉBITO ('D')
    -----------------------------------------------------------------------------------
    MERGE INTO cb_sal_inventarios inv
    USING (
        SELECT
            cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, residente, cat_riesgo,
            cod_rub_debito AS cod_rubro,
            SUM(sal_total) AS monto_total
        FROM cb_sal_movimientos
        WHERE sal_total != 0 
        GROUP BY cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, residente, cat_riesgo, cod_rub_debito
    ) src
    ON (
        inv.cod_modulo = src.cod_modulo AND inv.cod_modalidad = src.cod_modalidad AND
        inv.cod_oficina = src.cod_oficina AND inv.cod_sec_contable = src.cod_sec_contable AND
        inv.residente = src.residente AND inv.cod_moneda = v_cod_mon_local AND
        nvl(inv.cat_automatica,'X') = nvl(src.cat_riesgo,'X') AND inv.cod_rubro = src.cod_rubro AND
        inv.tip_saldo = v_tip_saldo AND inv.cod_plazo = v_cod_plazo
    )
    WHEN MATCHED THEN
        UPDATE SET inv.sal_total = NVL(inv.sal_total, 0) + src.monto_total
    WHEN NOT MATCHED THEN
        INSERT (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, residente, cod_moneda,
                cat_automatica, cod_rubro, tip_saldo, cod_plazo, sal_total, nro_referencia)
        VALUES (src.cod_modulo, src.cod_modalidad, src.cod_oficina, src.cod_sec_contable, src.residente, v_cod_mon_local,
                src.cat_riesgo, src.cod_rubro, v_tip_saldo, v_cod_plazo, src.monto_total, s_nro_referencia.nextval);
                
    -----------------------------------------------------------------------------------
    -- PASO 3: MERGE para los movimientos de CRÉDITO ('C')
    -----------------------------------------------------------------------------------
    MERGE INTO cb_sal_inventarios inv
    USING (
        SELECT
            cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, residente, cat_riesgo,
            cod_rub_credito AS cod_rubro,
            SUM(sal_total * -1) AS monto_total -- Monto se multiplica por -1
        FROM cb_sal_movimientos
        WHERE sal_total != 0 
        GROUP BY cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, residente, cat_riesgo, cod_rub_credito
    ) src
    ON (
        inv.cod_modulo = src.cod_modulo AND inv.cod_modalidad = src.cod_modalidad AND
        inv.cod_oficina = src.cod_oficina AND inv.cod_sec_contable = src.cod_sec_contable AND
        inv.residente = src.residente AND inv.cod_moneda = v_cod_mon_local AND
        nvl(inv.cat_automatica,'X') = nvl(src.cat_riesgo,'X') AND inv.cod_rubro = src.cod_rubro AND
        inv.tip_saldo = v_tip_saldo AND inv.cod_plazo = v_cod_plazo
    )
    WHEN MATCHED THEN
        UPDATE SET inv.sal_total = NVL(inv.sal_total, 0) + src.monto_total
    WHEN NOT MATCHED THEN
        INSERT (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, residente, cod_moneda,
                cat_automatica, cod_rubro, tip_saldo, cod_plazo, sal_total, nro_referencia)
        VALUES (src.cod_modulo, src.cod_modalidad, src.cod_oficina, src.cod_sec_contable, src.residente, v_cod_mon_local,
                src.cat_riesgo, src.cod_rubro, v_tip_saldo, v_cod_plazo, src.monto_total, s_nro_referencia.nextval);

    -----------------------------------------------------------------------------------
    -- PASO 4: MERGE final para la tabla de DETALLE
    -----------------------------------------------------------------------------------
    MERGE INTO cb_sal_inventarios_det det
    USING (
        WITH 
        -- Unimos los movimientos de débito y crédito para procesar el detalle
        movimientos_unidos AS (
            SELECT nro_cuenta, cod_rub_debito AS cod_rubro, sal_total AS monto, cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, residente, cat_riesgo
            FROM cb_sal_movimientos WHERE sal_total != 0
            UNION ALL
            SELECT nro_cuenta, cod_rub_credito AS cod_rubro, sal_total * -1 AS monto, cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, residente, cat_riesgo
            FROM cb_sal_movimientos WHERE sal_total != 0 
        ),
        -- Obtenemos el nro_referencia de la tabla principal (ya actualizada)
        datos_finales AS (
            SELECT
                inv.nro_referencia,
                mu.nro_cuenta,
                SUM(mu.monto) AS monto_final
            FROM movimientos_unidos mu
            JOIN cb_sal_inventarios inv ON
                 inv.cod_modulo = mu.cod_modulo AND inv.cod_modalidad = mu.cod_modalidad AND
                 inv.cod_oficina = mu.cod_oficina AND inv.cod_sec_contable = mu.cod_sec_contable AND
                 inv.residente = mu.residente AND inv.cod_moneda = v_cod_mon_local AND
                 nvl(inv.cat_automatica,'X') = nvl(mu.cat_riesgo,'X') AND inv.cod_rubro = mu.cod_rubro AND
                 inv.tip_saldo = v_tip_saldo AND inv.cod_plazo = v_cod_plazo
            GROUP BY inv.nro_referencia, mu.nro_cuenta
        )
        SELECT * FROM datos_finales
    ) src
    ON (det.nro_referencia = src.nro_referencia AND det.nro_cuenta = src.nro_cuenta)
    WHEN MATCHED THEN
        UPDATE SET det.sal_actual = NVL(det.sal_actual, 0) + src.monto_final
    WHEN NOT MATCHED THEN
        INSERT (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
        VALUES (src.nro_referencia, src.nro_cuenta, src.monto_final, 0);
    EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_TC_NO_UTIL:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Prestamos a utilizar mediante tarjetas de credito

   -- Cargos por Sobregiros en Suspenso.
   PROCEDURE pr_inv_car_sobregiros IS

      --Variables.
      v_nro_referencia cb_sal_inventarios.nro_referencia%TYPE;
      v_tip_saldo      cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento cb_sal_inventarios.tip_operacion%TYPE;
      v_cod_rubro      cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_plazo      NUMBER(03);

      --Cursor.
      CURSOR c_sob_suspenso IS
         SELECT css.cod_modulo,
                css.cod_modalidad,
                ge.cod_oficina,
                ge.cod_moneda,
                css.nro_cuenta,
                css.cod_transaccion,
                SUM(css.monto) monto
           FROM cc_sob_suspenso css, ge_cuentas ge
          WHERE css.fec_regularizacion IS NULL
            AND css.nro_cuenta = ge.nro_cuenta
          GROUP BY css.cod_modulo,
                   css.cod_modalidad,
                   ge.cod_oficina,
                   ge.cod_moneda,
                   css.nro_cuenta,
                   css.cod_transaccion;

   BEGIN

      --Seteo las variables.
      v_cod_plazo      := 1;
      v_tip_saldo      := 'I';
      v_tip_movimiento := 'C';

      FOR reg IN c_sob_suspenso LOOP

         --Se obtiene el rubro contable.
         v_cod_rubro := fub_obt_rub_transaccion(reg.cod_modulo, reg.cod_modalidad,
                                                reg.cod_transaccion, reg.cod_moneda,
                                                fug_obt_cli_principal(reg.nro_cuenta),
                                                to_char(v_cod_plazo), v_tip_movimiento);
         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = reg.cod_modulo
               AND cod_modalidad = reg.cod_modalidad
               AND cod_oficina = reg.cod_oficina
               AND cod_moneda = reg.cod_moneda
               AND cod_rubro = v_cod_rubro;

            -- Actualizo la cabecera.
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + reg.monto
             WHERE nro_referencia = v_nro_referencia;

            -- Actualizo el detalle.
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + reg.monto
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = reg.nro_cuenta;

            --Inserto la cabecera.
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, reg.nro_cuenta, reg.monto, 0);
            END IF;

         EXCEPTION
            WHEN no_data_found THEN

               IF nvl(reg.monto, 0) <> 0 THEN
                  -- Obtener el valor de la referencia.
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  --Inserto el registro en la tabla.
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (reg.cod_modulo, reg.cod_modalidad, reg.cod_oficina, NULL, NULL, NULL,
                      reg.cod_moneda, NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, reg.monto,
                      v_cod_rubro, v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(reg.monto, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, reg.nro_cuenta, reg.monto, 0);
                  END IF;

               END IF;
         END;
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_GEN_CAR_SOBREGIROS:' || SQLERRM);
   END;
   -- Fin Cargos por Sobregiros en Suspenso.

   -- Cheques a compensar camara local 24hs.
   PROCEDURE pr_inv_cam_loc_24h IS
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento  cb_sal_inventarios.tip_operacion%TYPE;
      v_cod_plazo       cb_sal_inventarios.cod_plazo%TYPE;
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_cod_modulo      ge_modalidades.cod_modulo%TYPE;
      v_cod_modalidad   ge_modalidades.cod_modalidad%TYPE;
      v_fec_actual      DATE;
      v_fec_anterior    DATE;
      v_cod_mon_fuerte  cb_sal_inventarios.cod_moneda%TYPE;

      ---cursor
      CURSOR loc IS

         SELECT *
           FROM cc_che_enviados c
          WHERE c.cod_moneda = v_cod_mon_fuerte
            AND c.estado = 'I'
            AND ((c.fecha = v_fec_actual AND c.cod_retencion IN (1, 2)) OR
                (c.fecha <= v_fec_anterior AND c.cod_retencion IN (1, 2, 3)));

   BEGIN
      v_cod_plazo       := 1;
      v_tip_saldo       := 'R'; --Retenido
      v_tip_movimiento  := 'D';
      v_cod_transaccion := 610;
      v_cod_modulo      := 4;
      v_cod_modalidad   := 41;
      pag_cal.pr_obt_dat_calendar(4);
      v_fec_actual     := pag_cal.fu_obt_fec_actual(4);
      v_fec_anterior   := pag_cal.g_fec_anterior;
      v_cod_mon_fuerte := pas_bcp.fu_obt_mon_fuerte;

      FOR i IN loc LOOP

         --- busco la cuenta que le corresponde al saldo ----
         fu_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, i.cod_moneda, NULL,
                          /*i.cod_sec_contable*/ NULL, /*i.cod_tip_deudor*/ NULL, /*i.residente*/
                          v_cod_plazo, v_tip_movimiento, v_cod_rubro, NULL, /*i.estado*/ NULL,
                          /*v_tip_renovacion*/ NULL, /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL,
                          /*v_tip_operacion*/ NULL /*v_cod_sit_contable*/);
         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = i.cod_ofi_origen
               AND cod_moneda = i.cod_moneda
               AND tip_saldo = v_tip_saldo
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, nvl(i.nro_cuenta, i.nro_cheque), i.monto, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.monto, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, i.cod_ofi_origen, NULL, NULL, NULL,
                      i.cod_moneda, NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, i.monto, v_cod_rubro,
                      v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(i.monto, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, nvl(i.nro_cuenta, i.nro_cheque), i.monto, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_CAM_LOCAL_24HS:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Cheques a compensar camara local 24hs.

   -- Cheques recibidos a compensar 24hs. camara Extranjera
   PROCEDURE pr_inv_cam_ext_24h IS
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento  cb_sal_inventarios.tip_operacion%TYPE;
      v_cod_plazo       cb_sal_inventarios.cod_plazo%TYPE;
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_cod_modulo      ge_modalidades.cod_modulo%TYPE;
      v_cod_modalidad   ge_modalidades.cod_modalidad%TYPE;
      /*v_cod_mon_fuerte    cb_sal_inventarios.cod_moneda%type;*/

      ---cursor
      CURSOR ext IS

         SELECT nvl(c.nro_cuenta, c.nro_cheque) nro_cuenta, c.cod_moneda, c.monto, c.cod_ofi_origen
           FROM ge_che_exterior c
          WHERE c.estado = 'I';
      /*and c.cod_moneda = v_cod_mon_fuerte*/
      --Modificado por Nilsa Aponte (Simgia S.R.L.), se modifica
      ---comentando el filtro de moneda para incluir el inventario de registros con moneda EUROS
      ---en fecha 16/06/2011

   BEGIN
      v_cod_plazo       := 1;
      v_tip_saldo       := 'R'; --Retenido
      v_tip_movimiento  := 'D'; --crédito
      v_cod_transaccion := 633;
      v_cod_modulo      := 4;
      v_cod_modalidad   := 41;
      /*v_cod_mon_fuerte := pas_bcp.fu_obt_mon_fuerte;*/

      FOR i IN ext LOOP

         --- busco la cuenta que le corresponde al saldo ----
         fu_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, i.cod_moneda, NULL,
                          /*i.cod_sec_contable*/ NULL, /*i.cod_tip_deudor*/ NULL, /*i.residente*/
                          v_cod_plazo, v_tip_movimiento, v_cod_rubro, NULL, /*i.estado*/ NULL,
                          /*v_tip_renovacion*/ NULL, /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL,
                          /*v_tip_operacion*/ NULL /*v_cod_sit_contable*/);
         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = i.cod_ofi_origen
               AND cod_moneda = i.cod_moneda
               AND tip_saldo = v_tip_saldo
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.monto, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.monto, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, i.cod_ofi_origen, NULL, NULL, NULL,
                      i.cod_moneda, NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, i.monto, v_cod_rubro,
                      v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(i.monto, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.monto, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_CAM_EXT_24HS:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Cheques recibidos a compensar 24hs. camara Extranjera

   -- Comercio exterior partidas acreedoras.
   PROCEDURE pr_inv_com_exterior IS
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
      v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
      v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
      v_cod_tip_deudor   cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_residente        cb_sal_inventarios.residente%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_situacion        cb_sal_inventarios.situacion%TYPE;
      v_tip_operacion    cb_sal_inventarios.tip_operacion%TYPE;
      v_sal_tot_batch    cb_sal_inventarios.sal_total%TYPE;
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes      cb_sal_inventarios.tip_interes%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_cuenta       cb_sal_inventarios_det.nro_cuenta%TYPE;
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_persona      ge_clientes.cod_persona%TYPE;
      v_cod_sit_contable cb_sal_inventarios.cod_sit_contable%TYPE;
      v_rowid            VARCHAR2(30);
      v_tip_deudor       VARCHAR2(03);
      v_cod_plazo        NUMBER(03) := 1;

 ------------------------- DEFINE MOVIMIEN -----------------------------
      CURSOR movimien IS
      --cci utilizadas con saldo
         SELECT a.nro_cuenta nro_cuenta,
                a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina sucursal,
                b.cod_persona cliente,
                --nvl(x.sal_utilizado, 0) importe,
                case
                  when nvl(a.mto_prepago,0)>0 and nvl(x.mto_utilizado,0)>=nvl(a.mto_prepago,0) then
                    nvl(x.mto_utilizado,0)-nvl(a.mto_prepago,0)
                  when nvl(a.mto_prepago,0)>0 and nvl(x.mto_utilizado,0)<nvl(a.mto_prepago,0) then
                    0
                  else
                    nvl(x.sal_utilizado, 0)
                end importe, -- DYDMR-2455 -- CN: 09/2015
                a.cod_moneda,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                'U' situacion,
                ge.cod_sit_contable,
                NULL rubro
           FROM ge_clientes c,
                cx_cta_importaciones a,
                ge_cta_clientes b,
                ( SELECT nro_cuenta cuenta, /*fec_vencimiento,*/ -- DYDMR-2455 -- CN:09/2015 - No se utiliza y ocasiona duplicacion de registros
                     SUM(saldo) sal_utilizado,
                     SUM(mto_utilizado) mto_utilizado  -- DYDMR-2455 -- CN: 09/2015
                    FROM cx_embarques
                   GROUP BY nro_cuenta /*, fec_vencimiento*/ ) x,
                ge_cuentas ge
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND x.cuenta(+) = a.nro_cuenta
            AND b.nro_cuenta = ge.nro_cuenta
            AND b.cod_persona = c.cod_persona
            AND a.estado NOT IN ('C', 'S') -- cancelada y solicitada -- DYDMR-4765 - 16/03/2017
            AND fux_obt_sal_mto_utilizado(a.nro_cuenta) > 0 --sólo si tiene saldo utilizado pendiente de cobro
            and ( case
                    when nvl(a.mto_prepago,0)>0 and nvl(x.mto_utilizado,0)>=nvl(a.mto_prepago,0) then
                      nvl(x.mto_utilizado,0)-nvl(a.mto_prepago,0)
                    when nvl(a.mto_prepago,0)>0 and nvl(x.mto_utilizado,0)<nvl(a.mto_prepago,0) then
                      0
                    else
                      nvl(x.sal_utilizado, 0)
                  end ) > 0  -- DYDMR-2455 -- CN: 09/2015
         UNION ALL
         SELECT a.nro_cuenta nro_cuenta,
                a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina sucursal,
                b.cod_persona cliente,
                --(saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)) importe,
                case
                  when nvl(a.mto_prepago,0)>0 and nvl(x.mto_utilizado,0)<=nvl(a.mto_prepago,0) then
                    nvl(a.monto,0)-nvl(a.mto_prepago,0)
                  else
                    (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta))
                end importe, -- DYDMR-2455 -- CN: 09/2015
                a.cod_moneda,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                'A' situacion,
                ge.cod_sit_contable,
                NULL rubro
           FROM ge_clientes c, cx_cta_importaciones a, ge_cta_clientes b, ge_cuentas ge,
                (SELECT nro_cuenta cuenta,
                        SUM(saldo) sal_utilizado,
                        SUM(mto_utilizado) mto_utilizado  -- DYDMR-2455 -- CN: 09/2015
                   FROM cx_embarques
                  GROUP BY nro_cuenta ) x
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND x.cuenta(+) = a.nro_cuenta
            AND b.cod_persona = c.cod_persona
            AND a.estado NOT IN ('C', 'S') -- cancelada y solicitada -- DYDMR-4765 - 16/03/2017
      AND b.nro_cuenta = ge.nro_cuenta
            AND (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)) > 0 --sólo si tiene saldo no utilizado
            and ( case
                    when nvl(a.mto_prepago,0)>0 and nvl(x.mto_utilizado,0)<=nvl(a.mto_prepago,0) then
                      nvl(a.monto,0)-nvl(a.mto_prepago,0)
                    else
                      (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta))
                  end ) > 0  -- DYDMR-2455 -- CN: 09/2015
         UNION ALL
         --cce sólo confirmadas
         SELECT a.nro_cuenta nro_cuenta,
                a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina sucursal,
                b.cod_persona cliente,
                (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)) importe,
                a.cod_moneda,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                'A' situacion,
                ge.cod_sit_contable,
                NULL rubro
           FROM ge_clientes c, cx_cta_exportaciones a, ge_cta_clientes b, ge_cuentas ge
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND b.nro_cuenta = ge.nro_cuenta
            AND (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)) > 0 --sólo si tiene saldo no utilizado
            AND b.cod_persona = c.cod_persona
         UNION ALL
         SELECT a.nro_cuenta nro_cuenta,
                a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina sucursal,
                b.cod_persona cliente,
                nvl(x.sal_utilizado, 0) importe,
                a.cod_moneda,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                'U',
                ge.cod_sit_contable,
                NULL rubro
           FROM ge_clientes c,
                cx_cta_exportaciones a,
                ge_cta_clientes b,
                (SELECT nro_cuenta cuenta, fec_vencimiento, SUM(saldo) sal_utilizado
                   FROM cx_embarques
                  GROUP BY nro_cuenta, fec_vencimiento) x,
                ge_cuentas ge
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND x.cuenta = a.nro_cuenta
            AND b.cod_persona = c.cod_persona
            AND b.nro_cuenta = ge.nro_cuenta
            AND (fux_obt_sal_mto_utilizado(a.nro_cuenta)) > 0 --sólo si tiene saldo no utilizado
         UNION ALL
         --cobranzas de importación avaladas
         SELECT a.nro_cuenta nro_cuenta,
                a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina sucursal,
                b.cod_persona cliente,
                nvl(saldo, 0) importe,
                a.cod_moneda,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                'A',
                ge.cod_sit_contable,
                NULL rubro
           FROM ge_clientes c, cx_cta_cobranzas a, ge_cta_clientes b, ge_cuentas ge
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND a.cod_modalidad IN (83, 84)
            AND a.estado = 'A'
            AND b.cod_persona = c.cod_persona
            AND b.nro_cuenta = ge.nro_cuenta
            AND saldo > 0 --sólo si tiene saldo
         UNION ALL
         --fianzas emitidas
         SELECT a.nro_cuenta nro_cuenta,
                a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina sucursal,
                b.cod_persona cliente,
                nvl(monto, 0) importe,
                a.cod_moneda,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                'A',
                ge.cod_sit_contable,
                NULL rubro
           FROM ge_clientes c, cx_fianzas a, ge_cta_clientes b, ge_cuentas ge
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND a.cod_modalidad = 88
            AND a.estado = 'A'
            AND b.nro_cuenta = ge.nro_cuenta
            AND b.cod_persona = c.cod_persona;

   BEGIN
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;
      ------------------------- LEER MOVIMIEN ------------------------------
      OPEN movimien;
      LOOP
         FETCH movimien
            INTO v_nro_cuenta,
                 v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_persona,
                 v_sal_tot_batch,
                 v_cod_moneda,
                 v_cod_sec_contable,
                 v_cod_tip_deudor,
                 v_residente,
                 v_situacion,
                 v_cod_sit_contable,
                 v_cod_rubro;
         EXIT WHEN movimien%NOTFOUND;

         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO).
         v_tip_saldo     := 'S'; -- Saldo
         v_sal_tot_batch := v_sal_tot_batch * (-1);

         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA).
         v_tip_interes := 'X';

         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA).
         v_tip_operacion := 'X';

         IF v_cod_rubro IS NULL THEN
            -- OBTIENE LA TRANSACCION.
            v_cod_transaccion := CASE
                                    WHEN v_situacion = 'U' THEN
                                     891
                                    ELSE
                                     874
                                 END;

            --- OBTIENE EL RUBRO CONTABLE.
            fu_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                             v_cod_sec_contable, v_tip_deudor, v_residente, to_char(v_cod_plazo),
                             'C', v_cod_rubro, NULL, NULL, NULL, NULL, NULL, v_cod_sit_contable,
                             NULL);
         END IF;

         -- ACTUALIZA EL INVENTARIO.
         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_situacion
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_operacion
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + v_sal_tot_batch
             WHERE ROWID = v_rowid;

            ------------Genero detalle----------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + v_sal_tot_batch
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_tot_batch, 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               --
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               --
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
                   v_cod_plazo, v_tip_operacion, v_tip_interes, v_sal_tot_batch, v_cod_rubro,
                   v_nro_referencia);
               --
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_tot_batch, 0);
         END;
         -------------------------------------------------------
      END LOOP;
      CLOSE movimien;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR PR_INV_COM_EXTERIOR :' || SQLERRM);
   END;
   -- Fin Comercio exterior partidas acreedoras.

   -- Contigencia de Cuentas Corrientes.
   PROCEDURE pr_inv_cta_cte_contingencia IS

      --Variables.
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_cod_rub_acreedor cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_rub_deudor   cb_sal_inventarios.cod_rubro%TYPE;
      v_tot_contingencia cb_sal_inventarios.sal_total%TYPE;
      v_tot_con_negativa cb_sal_inventarios.sal_total%TYPE;
      v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
      v_cod_plazo        NUMBER(03);
      v_redondeo         NUMBER(05);

      --Cursor.
      CURSOR c_cta_cte IS
         SELECT b.cod_persona,
                a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                a.nro_cuenta,
                a.cod_moneda,
                nvl(sal_total, 0) - nvl(sal_bloqueado, 0) - nvl(sal_retenido, 0) sal_actual,
                a.estado,
                f.dias_sobregiro,
                g.linea
           FROM cc_cta_corrientes a,
                ge_cta_clientes b,
                (SELECT can_dias dias_sobregiro, d.nro_cuenta FROM cc_sobregiros_res d) f,
                (SELECT SUM(monto) linea, c.nro_cuenta
                   FROM cc_lin_sobregiros c
                  WHERE c.estado = 'A'
                  GROUP BY c.nro_cuenta) g
          WHERE a.nro_cuenta = b.nro_cuenta
            AND f.nro_cuenta(+) = a.nro_cuenta
            AND g.nro_cuenta(+) = a.nro_cuenta
            AND g.linea > 0
            --and a.cod_ente is not null -- ICL 22/03/2012 Mail HB: Contingencia solo considerar Nómina
            AND b.relacion = 'P' --solo los principales de cuenta
            AND a.estado NOT IN ('C', 'X', /*'I',*/ 'A'); --no canceladas / DYDMR-6301 - Debe incluir las Inactivas.

   BEGIN

      --Seteo las variables.
      v_cod_plazo       := 1;
      v_tip_saldo       := 'O';
      v_cod_transaccion := 920;

      FOR reg IN c_cta_cte LOOP

         --Obtengo el valor de la cantidad de decimales a ser redondeados de acuerdo al tipo de moneda.
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', reg.cod_modulo,
                                           reg.cod_modalidad, reg.cod_moneda);

         --Obtengo el importe de la contigencia.
         IF reg.sal_actual < 0 THEN
            IF abs(reg.sal_actual) >= reg.linea THEN
               v_tot_contingencia := 0;
            ELSE
               v_tot_contingencia := nvl((reg.linea - abs(reg.sal_actual)), v_redondeo);
            END IF;
         ELSE
            v_tot_contingencia := reg.linea;
         END IF;
         v_tot_con_negativa := v_tot_contingencia * (-1);

         --Se obtiene el rubro contable.
         v_cod_rub_acreedor := fub_obt_rub_transaccion(reg.cod_modulo, reg.cod_modalidad,
                                                       v_cod_transaccion, reg.cod_moneda,
                                                       reg.cod_persona, to_char(v_cod_plazo), 'C');
         v_cod_rub_deudor   := fub_obt_rub_transaccion(reg.cod_modulo, reg.cod_modalidad,
                                                       v_cod_transaccion, reg.cod_moneda,
                                                       reg.cod_persona, to_char(v_cod_plazo), 'D');

         -- Parte Acreedora.
         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = reg.cod_modulo
               AND cod_modalidad = reg.cod_modalidad
               AND cod_oficina = reg.cod_oficina
               AND cod_moneda = reg.cod_moneda
               AND cod_rubro = v_cod_rub_acreedor;

            -- Actualizo la cabecera.
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + v_tot_con_negativa
             WHERE nro_referencia = v_nro_referencia;

            -- Actualizo el detalle.
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + v_tot_con_negativa
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = reg.nro_cuenta;

            --Inserto la cabecera.
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, reg.nro_cuenta, v_tot_con_negativa, 0);
            END IF;

         EXCEPTION
            WHEN no_data_found THEN

               IF nvl(v_tot_con_negativa, 0) <> 0 THEN
                  -- Obtener el valor de la referencia.
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  --Inserto el registro en la tabla.
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (reg.cod_modulo, reg.cod_modalidad, reg.cod_oficina, NULL, NULL, NULL,
                      reg.cod_moneda, NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, v_tot_con_negativa,
                      v_cod_rub_acreedor, v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(v_tot_con_negativa, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, reg.nro_cuenta, v_tot_con_negativa, 0);
                  END IF;

               END IF;
         END;

         --Parte Deudora.
         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = reg.cod_modulo
               AND cod_modalidad = reg.cod_modalidad
               AND cod_oficina = reg.cod_oficina
               AND cod_moneda = reg.cod_moneda
               AND cod_rubro = v_cod_rub_deudor;

            -- Actualizo la cabecera.
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + v_tot_contingencia
             WHERE nro_referencia = v_nro_referencia;

            -- Actualizo el detalle.
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + v_tot_contingencia
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = reg.nro_cuenta;

            --Inserto la cabecera.
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, reg.nro_cuenta, v_tot_contingencia, 0);
            END IF;

         EXCEPTION
            WHEN no_data_found THEN

               IF nvl(v_tot_contingencia, 0) <> 0 THEN
                  -- Obtener el valor de la referencia.
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  --Inserto el registro en la tabla.
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (reg.cod_modulo, reg.cod_modalidad, reg.cod_oficina, NULL, NULL, NULL,
                      reg.cod_moneda, NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, v_tot_contingencia,
                      v_cod_rub_deudor, v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(v_tot_contingencia, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, reg.nro_cuenta, v_tot_contingencia, 0);
                  END IF;

               END IF;
         END;
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_CTA_CTE_CONTINGENCIA:' || SQLERRM);
   END;
   -- Fin Contigencia de Cuentas Corrientes.

   -- Ingresos varios por caja Clearing
   -- Se deja en duro el rubro contable a pedido de Ingrid Larrain.

   PROCEDURE pr_ing_var_caja IS
      v_tip_saldo      cb_sal_inventarios.tip_saldo%TYPE;
      v_cod_plazo      cb_sal_inventarios.cod_plazo%TYPE;
      v_nro_referencia cb_sal_inventarios_det.nro_referencia%TYPE;
      v_fecha          date;

      ---cursor
      CURSOR c_mov_caja IS

         SELECT m.cod_modulo,
                m.cod_modalidad,
                m.cod_moneda,
                d.cod_rubro,
                TRIM(rtrim(substr(m.concepto, 14))) nro_cuenta,
                d.tip_movimiento,
                m.fecha,
                m.monto saldo,
                m.cod_transaccion,
                d.cod_oficina,
                gc.residente,
                gc.cod_sec_contable,
                gc.cat_riesgo,
                gc.cod_tip_deudor
           FROM ge_movimientos         m,
                cb_asi_automaticos_det d,
                ge_transacciones       t,
                ge_cta_clientes        c,
                ge_clientes            gc
          WHERE m.nro_documento4 = d.ref_movimiento
            and d.fecha=v_fecha
            AND m.fecha = d.fecha
            AND m.cod_mod_padre = t.cod_modulo
            AND m.cod_mad_padre = t.cod_modalidad
            AND m.cod_tra_padre = t.cod_transaccion
            AND d.cod_rubro = '150102570222205'
            AND d.tip_movimiento = 'D'
            AND gc.cod_persona = c.cod_persona
            AND TRIM(rtrim(substr(m.concepto, 14))) = c.nro_cuenta
            AND c.relacion = 'P'
            AND (m.reversado = 'N' OR (m.reversado = 'S' AND m.fecha <> m.fec_valor))

         UNION ALL
         SELECT m.cod_modulo,
                m.cod_modalidad,
                m.cod_moneda,
                d.cod_rubro,
                to_char(m.nro_documento4) nro_cuenta,
                d.tip_movimiento,
                m.fecha,
                m.monto saldo,
                m.cod_transaccion,
                d.cod_oficina,
                'X' residente,
                'N' cod_sec_contable,
                '1' cat_riesgo,
                1 cod_tip_deudor
           FROM ge_movimientos m, cb_asi_automaticos_det d
          WHERE m.nro_documento4 = d.ref_movimiento
            and d.fecha=v_fecha
            AND m.fecha = d.fecha
            AND d.cod_rubro = '150102570222205'
            AND d.tip_movimiento = 'D'
            AND m.cod_modulo <> 6
            AND (m.reversado = 'N' OR (m.reversado = 'S' AND m.fecha <> m.fec_valor));

   BEGIN
      v_cod_plazo := 1;
      v_tip_saldo := 'R'; --Retenido
      v_fecha:=pag_cal.FU_OBT_FEC_ACTUAL(1);

      FOR i IN c_mov_caja LOOP

         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND tip_saldo = v_tip_saldo
               AND cod_sec_contable = i.cod_sec_contable
               AND cod_tip_deudor = i.cod_tip_deudor
               AND residente = i.residente
               AND cat_automatica = i.cat_riesgo
               AND cod_rubro = i.cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.saldo, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.saldo, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.cod_sec_contable,
                      i.cod_tip_deudor, i.residente, i.cod_moneda, NULL, v_tip_saldo, v_cod_plazo,
                      NULL, NULL, i.saldo, i.cod_rubro, v_nro_referencia, NULL, i.cat_riesgo, NULL);

                  IF nvl(i.saldo, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.saldo, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_ING_VAR_CAJA:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Ingresos varios por caja Clearing

   -- Documentos pendientes de confirmacion en camara local extranjera
   PROCEDURE pr_inv_cam_local IS
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento  cb_sal_inventarios.tip_operacion%TYPE;
      v_cod_plazo       cb_sal_inventarios.cod_plazo%TYPE;
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_mon_local   ba_monedas.cod_moneda%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_residente       ge_clientes.residente%type;
      v_cod_sec_contable ge_clientes.cod_sec_contable%type;
      v_cod_tip_deudor   ge_clientes.cod_tip_deudor%type;
      v_cat_riesgo       ge_clientes.cat_riesgo%type;

      ---cursor
      CURSOR c_mov_local IS
            --DE-2320 : Optimizacion PAV_INV--
            --Obs: Se reemplaza el uso del gv_movimientos--
         SELECT DISTINCT t.cod_modulo,
                         t.cod_modalidad,
                         m.concepto,
                         t.cod_oficina,
                         m.fecha,
                         t.cod_moneda,
                         t.nro_documento,
                         --t.monto sal_retenido,
                         t.sal_retenido,
                         t.nro_cuenta,
                         m.cod_transaccion
           FROM ah_retenciones t, AH_movimientos_HIS m, ge_ret_monedas x
          WHERE t.liberado = 'N'
            and t.fec_inicio<=m.FECHA
            AND m.nro_documento = t.nro_documento
            AND t.nro_cuenta = m.nro_cuenta
            AND t.monto = m.monto
            AND m.reversado = 'N'
            AND m.cod_moneda <> v_cod_mon_local
            AND m.cod_transaccion IN (607, 610, 906, 614, 615, 935)
            and x.cod_retencion = t.cod_retencion
            and x.cod_moneda = t.cod_moneda
            and m.fecha >= (t.fec_inicio-x.can_dias)
            UNION
            SELECT DISTINCT t.cod_modulo,
                         t.cod_modalidad,
                         m.concepto,
                         t.cod_oficina,
                         m.fecha,
                         t.cod_moneda,
                         t.nro_documento,
                         --t.monto sal_retenido,
                         t.sal_retenido,
                         t.nro_cuenta,
                         m.cod_transaccion
           FROM ah_retenciones t, CC_movimientos_HIS m, ge_ret_monedas x
          WHERE t.liberado = 'N'
            and t.fec_inicio<=m.FECHA
            AND m.nro_documento = t.nro_documento
            AND t.nro_cuenta = m.nro_cuenta
            AND t.monto = m.monto
            AND m.reversado = 'N'
            AND m.cod_moneda <> v_cod_mon_local
            AND m.cod_transaccion IN (607, 610, 906, 614, 615, 935)
            and x.cod_retencion = t.cod_retencion
            and x.cod_moneda = t.cod_moneda
            and m.fecha >= (t.fec_inicio-x.can_dias)
            UNION
            SELECT DISTINCT t.cod_modulo,
                         t.cod_modalidad,
                         m.concepto,
                         t.cod_oficina,
                         m.fecha,
                         t.cod_moneda,
                         t.nro_documento,
                         --t.monto sal_retenido,
                         t.sal_retenido,
                         t.nro_cuenta,
                         m.cod_transaccion
           FROM ah_retenciones t, PR_movimientos_HIS m, ge_ret_monedas x
          WHERE t.liberado = 'N'
            and t.fec_inicio<=m.FECHA
            AND m.nro_documento = t.nro_documento
            AND t.nro_cuenta = m.nro_cuenta
            AND t.monto = m.monto
            AND m.reversado = 'N'
            AND m.cod_moneda <> v_cod_mon_local
            AND m.cod_transaccion IN (607, 610, 906, 614, 615, 935)
            and x.cod_retencion = t.cod_retencion
            and x.cod_moneda = t.cod_moneda
            and m.fecha >= (t.fec_inicio-x.can_dias);

   BEGIN
      v_cod_plazo       := 1;
      v_tip_saldo       := 'R'; --Retenido
      v_tip_movimiento  := 'C'; --crédito
      v_cod_transaccion := 610;
      v_cod_mon_local   := pag_gen.fu_obt_mon_local;

      FOR i IN c_mov_local LOOP
         BEGIN
            select c.residente,
                   c.cod_sec_contable,
                   c.cod_tip_deudor,
                   c.cat_riesgo
              into v_residente,
                   v_cod_sec_contable,
                   v_cod_tip_deudor,
                   v_cat_riesgo
              from ge_cta_clientes g, ge_clientes c
             where g.cod_persona = c.cod_persona
               AND g.relacion = 'P'
               and g.nro_cuenta=i.nro_cuenta;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
                 v_cod_sec_contable := NULL;
                 v_cod_tip_deudor := null;
                 v_cat_riesgo := null;
                 v_residente := null;
         END;

         --- busco la cuenta que le corresponde al saldo ----
         fu_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, v_cod_transaccion, i.cod_moneda,
                          v_cod_sec_contable, v_cod_tip_deudor, v_residente, v_cod_plazo,
                          v_tip_movimiento, v_cod_rubro, NULL, /*i.estado*/ NULL,
                          /*v_tip_renovacion*/ NULL, /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL,
                          /*v_tip_operacion*/ NULL /*v_cod_sit_contable*/);
         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND tip_saldo = v_tip_saldo
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cat_automatica = v_cat_riesgo
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.sal_retenido
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.sal_retenido
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.sal_retenido, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.sal_retenido, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, v_cod_sec_contable,
                      v_cod_tip_deudor, v_residente, i.cod_moneda, NULL, v_tip_saldo, v_cod_plazo,
                      NULL, NULL, i.sal_retenido, v_cod_rubro, v_nro_referencia, NULL, v_cat_riesgo,
                      NULL);

                  IF nvl(i.sal_retenido, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.sal_retenido, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_CAM_LOCAL:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Documentos pendientes de confirmacion en camara local extranjera

   --------------------------------------------------------------------------------------------------------------------
   -- Operaciones a Cancelar Venta de Cheques
   -- Cheques de Gerencia
   -- Para el Campo Nro.Cta. Cuando el saldo es "D" tiene el numero de Referencia del Asiento y cuando el saldo es "C" tiene
   -- el numero del cheque,cuando no tiene ningun numero de referencia tiene el numero de cta 999.
   PROCEDURE pr_inv_ope_can_ven_cheques IS
      v_tip_saldo      cb_sal_inventarios.tip_saldo%TYPE;
      v_cod_plazo      NUMBER(03);
      v_nro_referencia cb_sal_inventarios.nro_referencia%TYPE;

      ---cursor
      CURSOR inv IS
         SELECT a.cod_rubro,
                a.cod_modulo,
                a.cod_modalidad,
                a.cod_moneda,
                a.estado,
                nvl(nvl(a.nro_documento, a.nro_documento4), 999) num_cheque,
                a.tip_mov_rubro,
                a.reversado,
                (CASE
                   WHEN a.tip_mov_rubro = 'C' THEN
                    a.monto
                   WHEN a.tip_mov_rubro = 'D' THEN
                    (a.monto * (-1))
                   ELSE
                    a.monto
                END) saldo,
                a.cod_transaccion,
                a.cod_oficina
           FROM ge_movimientos a
          WHERE a.cod_rubro IN (240402600299899, 240402600299805, 240402600299817);

   BEGIN
      v_cod_plazo := 1;
      v_tip_saldo := 'H'; --Retenido

      FOR i IN inv LOOP

         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND tip_saldo = v_tip_saldo
               AND situacion = i.estado
               AND cod_rubro = i.cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.num_cheque;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.num_cheque, i.saldo, 0);
            END IF;
            ------------------------------------------------------------------------------------------------------------------
         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.saldo, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, NULL, NULL, NULL, i.cod_moneda,
                      i.estado, v_tip_saldo, v_cod_plazo, NULL, NULL, i.saldo, i.cod_rubro,
                      v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(i.saldo, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.num_cheque, i.saldo, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_OPE_CAN_VEN_CHEQUES:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Documentos pendientes de confirmacion en camara local extranjera

   -- Datos de Cheques Recibido de Camara Interna --OMM 24/06/2011
   PROCEDURE pr_inv_che_cam_interna IS
      v_tip_movimiento cb_sal_inventarios.tip_operacion%TYPE;
      v_cod_plazo      cb_sal_inventarios.cod_plazo%TYPE;
      v_cod_rubro      cb_sal_inventarios.cod_rubro%TYPE;
      v_tip_saldo      cb_sal_inventarios.tip_saldo%TYPE;
      v_nro_referencia cb_sal_inventarios_det.nro_referencia%TYPE;
      v_monto          cb_sal_inventarios.sal_total%TYPE;

      ---cursor
      CURSOR c_mov_interna IS

         SELECT DISTINCT m.cod_modulo,
                         m.cod_modalidad,
                         m.concepto,
                         m.cod_ofi_origen cod_oficina,
                         m.fecha,
                         m.cod_moneda,
                         m.nro_documento,
                         m.monto,
                         m.cod_transaccion,
                         m.nro_cuenta,
                         decode(m.cod_transaccion, '606', m.nro_cuenta, m.nro_documento) documento
           FROM ge_movimientos m, cj_movimientos c
          WHERE m.reversado = 'N'
            AND m.fecha = c.fecha
            AND m.hora = c.hora
            AND m.cod_usuario = c.cod_usuario
            AND m.cod_tra_padre = c.cod_tra_padre
            AND ((m.cod_transaccion = 606 AND m.cod_tra_padre in (351,371)) OR
                (m.cod_transaccion = 614 AND m.cod_tra_padre = 394) OR
                (m.cod_transaccion = 505 AND m.cod_tra_padre = 131 AND EXISTS
                 (SELECT 1
                     FROM cj_movimientos a
                    WHERE a.fecha = c.fecha
                      AND a.cod_usuario = c.cod_usuario
                      AND a.nro_documento = c.nro_doc_referencia
                      AND a.cod_tra_padre IN (351, 371, 394))) OR
                (m.cod_transaccion = 591 AND m.cod_tra_padre = 355 AND EXISTS
                 (SELECT 1
                     FROM cj_movimientos j
                    WHERE j.fecha = c.fecha
                      AND j.cod_usuario = c.cod_usuario
                      AND j.nro_documento = c.nro_doc_referencia
                      AND j.cod_tra_padre IN (351, 371, 394))));

   BEGIN

      v_cod_plazo := 1;
      v_tip_saldo := 'H'; -- Cheque Recibido de Camara Interna

      FOR i IN c_mov_interna LOOP

         -- Invierte el tipo de movimiento para obtener el rubro por la funcion
         SELECT decode(gt.tipo, 'C', 'D', 'C')
           INTO v_tip_movimiento
           FROM ge_transacciones gt
          WHERE gt.cod_transaccion = i.cod_transaccion
            AND gt.cod_modulo = i.cod_modulo
            AND gt.cod_modalidad = i.cod_modalidad;

         IF v_tip_movimiento = 'D' THEN
            v_monto := i.monto * (-1);
         ELSE
            v_monto := i.monto;
         END IF;

         --- busco la cuenta que le corresponde al saldo ----
         fu_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, i.cod_transaccion, i.cod_moneda, NULL,
                          --i.cod_sec_contable,
                          NULL,
                          --i.cod_tip_deudor,
                          NULL,
                          --i.residente,
                          v_cod_plazo, v_tip_movimiento, v_cod_rubro, NULL, /*i.estado*/ NULL,
                          /*v_tip_renovacion*/ NULL, /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL,
                          /*v_tip_operacion*/ NULL /*v_cod_sit_contable*/);

         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND tip_saldo = v_tip_saldo
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + v_monto
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + v_monto
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.documento;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.documento, v_monto, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.monto, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_moneda, situacion, tip_saldo,
                      sal_total, cod_rubro, nro_referencia)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.cod_moneda, NULL, v_tip_saldo,
                      v_monto, v_cod_rubro, v_nro_referencia);

                  IF nvl(i.monto, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.documento, v_monto, 0);
                  END IF;

               END IF;

         END;

      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_CAM_INTERNA:' || SQLERRM);
   END; -- Fin de Cheques Recibido de Camara Interna

   --Inventario de pago a proveedores pendientes.
   PROCEDURE pr_inv_pag_proveedores IS

      --Variables.
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_cod_modulo      cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad   cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_oficina     cb_sal_inventarios.cod_oficina%TYPE;
      v_tip_movimiento  cb_sal_inventarios.tip_operacion%TYPE;
      v_cod_plazo       NUMBER(03);

      --Cursor.
      CURSOR c_pag_proveedores IS
         -- AP 2538 15/11/2011 V.V.
           SELECT cod_moneda,nvl(mto_mon_pago,0) monto, nvl(nro_factura, 999999) nro_cuenta
             FROM pv_compras
            WHERE estado = 'A'
              AND tip_comprobante = 'F';

   BEGIN

      --Seteo las variables.
      v_cod_modulo      := 28;
      v_cod_modalidad   := 281;
      v_cod_oficina     := 31;
      v_cod_plazo       := 1;
      v_tip_saldo       := 'O';
      v_cod_transaccion := 2891;
      v_tip_movimiento  := 'C';

      FOR reg IN c_pag_proveedores LOOP

         --Se obtiene el rubro contable.
         v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad, v_cod_transaccion,
                                                reg.cod_moneda, NULL, to_char(v_cod_plazo),
                                                v_tip_movimiento);

         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_moneda = reg.cod_moneda
               AND cod_rubro = v_cod_rubro;

            -- Actualizo la cabecera.
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + nvl(reg.monto, 0)
             WHERE nro_referencia = v_nro_referencia;

            -- Actualizo el detalle.
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + nvl(reg.monto, 0)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = substr(reg.nro_cuenta, 1, 15);

            --Inserto la cabecera.
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, substr(reg.nro_cuenta, 1, 15), nvl(reg.monto, 0), 0);
            END IF;

         EXCEPTION
            WHEN no_data_found THEN

               IF nvl(reg.monto, 0) != 0 THEN
                  -- Obtener el valor de la referencia.
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  --Inserto el registro en la tabla.
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, NULL, NULL, NULL,
                      reg.cod_moneda, NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, nvl(reg.monto, 0),
                      v_cod_rubro, v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(reg.monto, 0) != 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, substr(reg.nro_cuenta, 1, 15), nvl(reg.monto, 0), 0);
                  END IF;

               END IF;
         END;
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_CTA_CTE_CONTINGENCIA:' || SQLERRM);
   END;
   --Fin inventario de pago a proveedores pendientes.

   PROCEDURE pr_inv_com_diferidas IS
      --- Realizado por Ingrid Larraín, 19/08/2011 por Desconexion AS400
      --- Inventario de Comisiones Diferidas - A Devengar
      --- Variables auxiliares
      v_cod_modulo      NUMBER(03);
      v_cod_modalidad   NUMBER(03);
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_cod_oficina     NUMBER(03);
      v_nro_cuenta      VARCHAR2(15);
      v_cod_sector      VARCHAR2(01);
      v_tip_deudor      NUMBER(02);
      v_residente       VARCHAR2(01);
      v_cod_moneda      VARCHAR2(03);
      v_estado          VARCHAR2(01);
      v_tip_saldo       VARCHAR2(01);
      v_cod_rubro       VARCHAR2(15);
      v_cat_riesgo      VARCHAR2(1);
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_rowid           VARCHAR2(30);
      v_fec_actual      DATE := pag_cal.fu_obt_fec_actual(6);
      v_redondeo        NUMBER(10);
      v_error           VARCHAR2(100);
      v_mon_local       VARCHAR2(03) := pag_gen.fu_obt_mon_local;
      --- Cursor de comisiones diferidas
      CURSOR c_com_diferidas IS
         SELECT g.cod_transaccion,
                g.cod_modulo,
                g.cod_modalidad,
                g.cod_oficina,
                g.nro_cuenta,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                g.cod_moneda,
                g.estado,
                (decode(g.cod_moneda, v_mon_local, nvl(g.monto, 0), nvl(g.mto_equ_local, 0)) -
                nvl(g.mto_dev_acumulado, 0)) monto,
                nvl(c.cat_riesgo, 1) cat_riesgo,
                b.cod_persona,
                nvl(g.mto_dev_acumulado, 0) mto_dev_acumulado
           FROM ge_mov_diferidos g, ge_clientes c, ge_cta_clientes b, ge_cuentas a
          WHERE b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND c.cod_persona = b.cod_persona
            AND g.estado = 'N' -- Solo normales
            AND g.nro_cuenta = a.nro_cuenta
            --dydmr-4953 - 14/09/2016
            -- Condicion agregada para los registros que quedaron con valor 0 y
            -- estado N, entonces se valida que tambien el monto sea mayor a 0.
            AND (decode(g.cod_moneda, v_mon_local, nvl(g.monto, 0), nvl(g.mto_equ_local, 0)) - nvl(g.mto_dev_acumulado, 0))>0;
   BEGIN
      --- Recorrer cuadre de gastos
      BEGIN
         FOR reg IN c_com_diferidas LOOP
            --- Variables auxiliares
            v_error := 'En asignacion';
            ------
            v_cod_modulo      := reg.cod_modulo;
            v_cod_modalidad   := reg.cod_modalidad;
            v_cod_oficina     := reg.cod_oficina;
            v_cod_sector      := reg.cod_sec_contable;
            v_error           := 'En asignacion2';
            v_tip_deudor      := reg.cod_tip_deudor;
            v_residente       := reg.residente;
            --v_cod_moneda      := reg.cod_moneda;
            v_cod_moneda      := v_mon_local; -- RABF 07/nov/11 - Siempre es en moneda local
            v_estado          := reg.estado;
            v_error           := 'En asignacion3';
            v_tip_saldo       := 'A'; -- A devengar
            v_nro_cuenta      := reg.nro_cuenta;
            v_error           := 'En asignacion4';
            v_cod_transaccion := reg.cod_transaccion;
            --- busco la cuenta que le corresponde al saldo ----
            v_error     := 'Obt. rubro';
            v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad, v_cod_transaccion,
                                                   v_cod_moneda, reg.cod_persona, NULL, 'C', v_estado,
                                                   NULL, v_cat_riesgo, NULL, NULL, NULL, NULL);
            ----
            v_error := 'En referencia';
            BEGIN
               SELECT nro_referencia, ROWID
                 INTO v_nro_referencia, v_rowid
                 FROM cb_sal_inventarios
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_oficina = v_cod_oficina
                  AND cod_sec_contable = v_cod_sector
                  AND cod_tip_deudor = v_tip_deudor
                  AND residente = v_residente
                  AND cod_moneda = v_cod_moneda
                  AND situacion = v_estado
                  AND tip_saldo IN (v_tip_saldo)
                  AND cat_automatica = v_cat_riesgo
                  AND cod_rubro = v_cod_rubro;
               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + nvl(reg.monto, 0)
                WHERE ROWID = v_rowid;
               --- genero detalle ---------------------------------
               v_error := 'Upd. sal inv.';
               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + nvl(reg.monto, 0)
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = v_nro_cuenta;
               IF SQL%NOTFOUND THEN
                  v_error := 'Ins. sal inv.';
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, nvl(reg.monto, 0), 0);
               END IF;
            EXCEPTION
               WHEN no_data_found THEN
                  -- INSERTA SALDO DE DEVENGADO --
                  v_error := 'Ins. sal inv.2.';
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sector, v_tip_deudor,
                      v_residente, v_cod_moneda, v_estado, v_tip_saldo, NULL, NULL, NULL,
                      nvl(reg.monto, 0), v_cod_rubro, v_nro_referencia, NULL, v_cat_riesgo, NULL);
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, nvl(reg.monto, 0), 0);
            END;
         END LOOP;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000, 'ERROR COM.DIF.: ' || v_error || ' ' || SQLERRM);
      END;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN COM.DIF.:' || SQLERRM);
   END;
   --- Fin de inventario de Comisiones Diferidas - A Devengar
   -- Datos de Inventario de Valores en Custodia --OMM 20/07/2011
   PROCEDURE pr_inv_val_custodia IS
      v_cod_plazo      cb_sal_inventarios.cod_plazo%TYPE;
      v_cod_rubro      cb_sal_inventarios.cod_rubro%TYPE;
      v_tip_saldo      cb_sal_inventarios.tip_saldo%TYPE;
      v_nro_referencia cb_sal_inventarios_det.nro_referencia%TYPE;

      ---cursor
    CURSOR c_movimientos IS

        SELECT DISTINCT m.cod_modulo,
                     m.cod_modalidad,
                     m.concepto,
                     m.cod_ofi_origen,
                     m.fecha,
                     m.cod_moneda,
                     m.nro_documento,
                     m.cod_transaccion,
                     m.nro_cuenta,
                      m.monto,
                     (m.monto * -1) mto_cre
       FROM ge_movimientos_his m, ge_val_custodias gv
      WHERE m.reversado = 'N'
        AND m.cod_tra_padre = 3160
        AND m.cod_transaccion IN (3161, 3162)
        AND m.cod_modulo = 1
        AND m.cod_modalidad = 1
        AND m.fecha = trunc(gv.fec_insercion)
        AND m.nro_documento = gv.cod_val_custodia
        AND gv.estado<>'C'
   UNION
        SELECT DISTINCT m.cod_modulo,
                     m.cod_modalidad,
                     m.concepto,
                     m.cod_ofi_origen,
                     m.fecha,
                     m.cod_moneda,
                     m.nro_documento,
                     m.cod_transaccion,
                     m.nro_cuenta,
                     m.monto,
                     (m.monto * -1) mto_cre
       FROM ge_movimientos m, ge_val_custodias gv
      WHERE m.reversado = 'N'
        AND m.cod_tra_padre = 3160
        AND m.cod_transaccion IN (3161, 3162)
        AND m.cod_modulo = 1
        AND m.cod_modalidad = 1
        AND m.fecha = trunc(gv.fec_insercion)
        AND m.nro_documento = gv.cod_val_custodia
        AND gv.estado <>'C'
    UNION
       SELECT DISTINCT 1 cod_modulo,
                 1 cod_modalidad,
                 ltrim(m.descripcion,60) concepto,
                 31 cod_ofi_origen,
                 m.fec_ingreso fecha,
                 m.cod_moneda,
                 m.cod_val_custodia nro_documento,
                 decode(m.estado, 'V', 3161, 3162) cod_transaccion,
                 m.nro_cta_debito nro_cuenta,
                 m.mto_total monto,
                 (m.mto_total * -1) mto_cre
        FROM ge_val_custodias m
        WHERE m.estado <>'C'
          and not exists (Select 1 from ge_movimientos_his g
                         WHERE g.reversado = 'N'
                           AND g.cod_tra_padre = 3160
                           AND g.cod_transaccion IN (3161, 3162)
                           AND g.cod_modulo = 1
                           AND g.cod_modalidad = 1
                           and g.fecha = trunc(m.fec_insercion)
                           and g.nro_documento = m.cod_val_custodia);
   BEGIN

      v_cod_plazo := 1;
      v_tip_saldo := 'H'; -- Valores en Custodia

      FOR i IN c_movimientos LOOP
            --OMM 20/09/2011 Realiza la pata del Credito
         --- busco la cuenta que le corresponde al saldo ----
         fu_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, i.cod_transaccion, i.cod_moneda, NULL,
                          --i.cod_sec_contable,
                          NULL,
                          --i.cod_tip_deudor,
                          'S',
                          --i.residente,
                          v_cod_plazo, 'C', v_cod_rubro, NULL, /*i.estado*/ NULL,
                          /*v_tip_renovacion*/ NULL, /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL,
                          /*v_tip_operacion*/ NULL /*v_cod_sit_contable*/);

         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_ofi_origen
               AND cod_moneda = i.cod_moneda
               AND tip_saldo = v_tip_saldo
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.mto_cre
             WHERE nro_referencia = v_nro_referencia;

            -- Se utiliza nro de documento del contrato de Custodia, x que la cuenta no se graba
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.mto_cre
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_documento;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_documento, i.mto_cre, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.mto_cre, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_moneda, situacion, tip_saldo,
                      sal_total, cod_rubro, nro_referencia)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_ofi_origen, i.cod_moneda, NULL,
                      v_tip_saldo, i.mto_cre, v_cod_rubro, v_nro_referencia);

                  IF nvl(i.monto, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_documento, i.mto_cre, 0);
                  END IF;

               END IF;

         END;
      --OMM 20/09/2011 Realiza la pata del Debito
               --- busco la cuenta que le corresponde al saldo ----
         fu_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, i.cod_transaccion, i.cod_moneda, NULL,
                          --i.cod_sec_contable,
                          NULL,
                          --i.cod_tip_deudor,
                          'S',
                          --i.residente,
                          v_cod_plazo, 'D', v_cod_rubro, NULL, /*i.estado*/ NULL,
                          /*v_tip_renovacion*/ NULL, /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL,
                          /*v_tip_operacion*/ NULL /*v_cod_sit_contable*/);

         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_ofi_origen
               AND cod_moneda = i.cod_moneda
               AND tip_saldo = v_tip_saldo
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia;

            -- Se utiliza nro de documento del contrato de Custodia, x que la cuenta no se graba
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_documento;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_documento, i.monto, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.monto, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_moneda, situacion, tip_saldo,
                      sal_total, cod_rubro, nro_referencia)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_ofi_origen, i.cod_moneda, NULL,
                      v_tip_saldo, i.monto, v_cod_rubro, v_nro_referencia);

                  IF nvl(i.monto, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_documento, i.monto, 0);
                  END IF;

               END IF;

         END;



      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_VAL_CUSTODIA:' || SQLERRM);
   END; -- Fin de Inventario de Valores en Custodia

   -- Devengados de Plusvalía y Minusvalía de los Bonos Subordinados.
   PROCEDURE pr_inv_dev_bon_subordinados is
      ------------------------------------------------------------------------
      ---- VARIABLES CURSOR MOVIMIEN
      ------------------------------------------------------------------------
      v_tip_saldo        VARCHAR2(01);
      v_tip_interes      VARCHAR2(01);
      v_cod_rubro        VARCHAR2(15);
      v_rowid            VARCHAR2(30);
      v_tip_movimiento   VARCHAR2(01);
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_tip_operacion    cb_sal_inventarios.tip_operacion%TYPE;
      v_situacion        cb_sal_inventarios.situacion%TYPE;
      v_cod_empresa      ge_entes.cod_ente%TYPE;
      ------------------------- DEFINE MOVIMIENTOS -----------------------------
      CURSOR c_dev IS
         SELECT /*+ index(a PK_AH_CTA_CERTIFICADOS) index(c PK_GE_CLIENTES) +*/
          a.cod_modulo,
          a.cod_modalidad,
          a.cod_transaccion,
          a.cod_oficina,
          a.nro_cuenta,
          c.cod_sec_contable,
          c.cod_tip_deudor,
          c.residente,
          a.cod_moneda,
          cod_plazo,
          nvl(monto,0) - nvl(a.mto_dev_acumulado,0) mto_dev_acumulado
           FROM ge_plz_contables d, ge_clientes c, ge_cta_clientes b, ah_dev_bon_subordinados a
          WHERE b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND c.cod_persona = b.cod_persona
            and a.cod_transaccion is not null
            AND a.estado <> 'C'
            AND can_dias = (SELECT MIN(can_dias)
                              FROM ge_plz_contables
                             WHERE can_dias >= a.fec_vencimiento - a.fec_inicio);
   BEGIN
      v_situacion := 'N';
      --- Obtiene el Ente
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
      -------------------------------------------------------------
      -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) --
      -------------------------------------------------------------
      v_tip_saldo := 'D';
      -------------------------------------------------
      -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA) --
      -------------------------------------------------
      v_tip_interes := 'X';
      --------------------------------------------------
      -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA) --
      --------------------------------------------------
      v_tip_operacion := 'X';
      ------------------------- LEER MOVIMIEN ----------
      FOR i IN c_dev LOOP
         -------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) --
         -------------------------------------------------------------
         IF i.cod_transaccion = fug_obt_parentes(v_cod_empresa, 'COD_TRA_DEV_PLUSVALIA') THEN
            v_tip_movimiento := 'D';
         ELSIF i.cod_transaccion = fug_obt_parentes(v_cod_empresa, 'COD_TRA_DEV_MINUSVALIA') THEN
            v_tip_movimiento := 'C';
         ELSE
            v_tip_movimiento := 'D';
         END IF;
         --- busco el rubro
         fu_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, i.cod_transaccion, i.cod_moneda,
                          i.cod_sec_contable, i.cod_tip_deudor, i.residente, to_char(i.cod_plazo),
                          v_tip_movimiento, v_cod_rubro);
         -------------------------------
         -- ACTUALIZA SALDO DEVENGADO --
         -------------------------------
         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_sec_contable = i.cod_sec_contable
               AND cod_tip_deudor = i.cod_tip_deudor
               AND residente = i.residente
               AND cod_moneda = i.cod_moneda
               AND situacion = v_situacion
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = i.cod_plazo
               AND tip_operacion = v_tip_operacion
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            --
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + nvl(i.mto_dev_acumulado,0)
             WHERE ROWID = v_rowid;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + nvl(i.mto_dev_acumulado,0)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, nvl(i.mto_dev_acumulado,0), 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               -----------------------------
               -- INSERTA SALDO DEVENGADO --
               -----------------------------
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.cod_sec_contable,
                   i.cod_tip_deudor, i.residente, i.cod_moneda, v_situacion, v_tip_saldo,
                   i.cod_plazo, v_tip_operacion, v_tip_interes, nvl(i.mto_dev_acumulado,0), v_cod_rubro,
                   v_nro_referencia);
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, nvl(i.mto_dev_acumulado,0), 0);
         END;
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_DEV_BON_SUBORDINADOS:' || SQLERRM);
   END; -- Fin de Inventario de Devengados de Plusvalía y Minusvalía
   ---------------------------------------------------------------------------------------------------------------------
   ---------------------------------------------------------------------------------------------------------------------
   -- Previsión de Comex
   PROCEDURE lp_acu_prev_comex IS
      v_cod_modulo      cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad   cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_nro_cuenta      ge_cuentas.nro_cuenta%TYPE;
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento  VARCHAR2(01);
      v_cod_plazo       NUMBER(03);
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_rowid           VARCHAR2(30);
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;

      ---cursor
      CURSOR com IS
         SELECT c.cod_modulo,
                c.cod_modalidad,
                c.cod_oficina,
                c.nro_cuenta,
                ge.cod_sec_contable,
                ge.cod_tip_deudor,
                ge.residente,
                fup_obt_categoria(ge.cat_automatica, ge.cat_subjetiva) cat_riesgo,
                v.fecha,
                c.cod_moneda,
                c.est_batch,
                nvl(v.monto, 0) mto_prevision
           FROM cx_previsiones    v,
                cx_cta_importaciones c,
                ge_clientes       ge,
                ge_cta_clientes   gc
            WHERE c.nro_cuenta = v.nro_cuenta
            AND ge.cod_persona = gc.cod_persona
            AND gc.nro_cuenta = c.nro_cuenta
            AND gc.relacion = 'P'
            AND c.est_batch != 'C' --cancelado
            AND v.fecha =
                (SELECT MAX(b.fecha) FROM cx_previsiones b WHERE c.nro_cuenta = b.nro_cuenta)
  union all
  SELECT c.cod_modulo,
                c.cod_modalidad,
                c.cod_oficina,
                c.nro_cuenta,
                ge.cod_sec_contable,
                ge.cod_tip_deudor,
                ge.residente,
                fup_obt_categoria(ge.cat_automatica, ge.cat_subjetiva) cat_riesgo,
                v.fecha,
                c.cod_moneda,
                c.est_batch,
                nvl(v.monto, 0) mto_prevision
            FROM cx_previsiones    v,
                cx_fianzas c,
                ge_clientes       ge,
                ge_cta_clientes   gc
            WHERE c.nro_cuenta = v.nro_cuenta
            AND ge.cod_persona = gc.cod_persona
            AND gc.nro_cuenta = c.nro_cuenta
            AND gc.relacion = 'P'
            AND c.est_batch != 'C' --cancelado
            AND v.fecha =
                (SELECT MAX(b.fecha) FROM cx_previsiones b WHERE c.nro_cuenta = b.nro_cuenta);

   BEGIN
      v_tip_saldo       := 'V'; --prevision.
      v_tip_movimiento  := 'C';
      v_cod_transaccion := 756;
      v_cod_plazo       := 1;

      FOR i IN com LOOP
         fu_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, v_cod_transaccion, i.cod_moneda,
                          i.cod_sec_contable, i.cod_tip_deudor, i.residente, 1, v_tip_movimiento,
                          v_cod_rubro, i.est_batch, /*v_tip_renovacion*/ NULL, i.cat_riesgo,
                          /*v_tip_interes*/ NULL, /*v_tip_operacion*/ NULL,
                          /*v_cod_sit_contable*/ NULL);

         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_sec_contable = i.cod_sec_contable
               AND cod_tip_deudor = i.cod_tip_deudor
               AND situacion = i.est_batch
               AND cat_automatica = i.cat_riesgo
               AND residente = i.residente
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.mto_prevision
             WHERE nro_referencia = v_nro_referencia;
            --       and rowid= v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.mto_prevision
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.mto_prevision, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN

               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion, cat_automatica,
                   cod_sit_contable)
               VALUES
                  (i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.cod_sec_contable,
                   i.cod_tip_deudor, i.residente, i.cod_moneda, i.est_batch, v_tip_saldo,
                   v_cod_plazo, NULL, NULL, i.mto_prevision, v_cod_rubro, v_nro_referencia, NULL,
                   i.cat_riesgo, NULL);

               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.mto_prevision, 0);

         END;

       END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_PREV_COMEX:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de previsiones de sobregiros

   -- Inventario de cuentas embargadas.
   PROCEDURE pr_inv_embargos IS
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento  VARCHAR2(01);
      v_cod_plazo       NUMBER(03);
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_rowid           VARCHAR2(30);
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_cau_embargo ge_par_causales.val_parametro%TYPE;

      ---cursor
      CURSOR emb IS
         select gcc.cod_modulo, gcc.cod_modalidad, gem.cod_ofi_origen cod_oficina,
                gcc.nro_cuenta,
                gec.cod_sec_contable,
                gec.cod_tip_deudor,
                gec.residente,
                fup_obt_categoria(gec.cat_automatica, gec.cat_subjetiva) cat_riesgo,
                gem.fecha,
                cte.cod_moneda,
                cte.est_batch,
                nvl(xx_mto_emb_ge_blo,0) mto_embargado
              from ge_cuentas ge,
                   ge_cta_clientes gcc,
                   cc_cta_corrientes cte,
                   ge_clientes gec,
                   ge_embargos gem,
                   ge_embargos_det ged,
                   (select x.nro_cuenta xx_nro_cuenta,
                      sum(nvl(x.monto,0)) xx_mto_emb_ge_blo, x.nro_documento
                    from ge_bloqueos x
                    where x.cod_causa = v_cod_cau_embargo --EMBARGOS--
                    group by x.nro_cuenta, x.nro_documento)
             where ge.nro_cuenta = gcc.nro_cuenta
               and gcc.cod_persona = gec.cod_persona
               and ged.nro_cuenta = ge.nro_cuenta
               and gem.cod_embargo = ged.cod_embargo
               and cte.nro_cuenta = gcc.nro_cuenta
               and xx_nro_cuenta = ge.nro_cuenta
               and nro_documento = ged.cod_embargo
               and gem.estado = 'A'
               and gcc.relacion = 'P'
               and cte.est_batch != 'C' --cancelado
         union all -- DYDMR-8611
         select gcc.cod_modulo, gcc.cod_modalidad, gem.cod_ofi_origen cod_oficina,
                gcc.nro_cuenta,
                gec.cod_sec_contable,
                gec.cod_tip_deudor,
                gec.residente,
                fup_obt_categoria(gec.cat_automatica, gec.cat_subjetiva) cat_riesgo,
                gem.fecha,
                ahv.cod_moneda,
                ahv.est_batch,
                nvl(xx_mto_emb_ge_blo,0) mto_embargado
              from ge_cuentas ge,
                   ge_cta_clientes gcc,
                   ah_cta_vistas ahv,
                   ge_clientes gec,
                   ge_embargos gem,
                   ge_embargos_det ged,
                   (select x.nro_cuenta xx_nro_cuenta,
                      sum(nvl(x.monto,0)) xx_mto_emb_ge_blo, x.nro_documento
                    from ge_bloqueos x
                    where x.cod_causa = v_cod_cau_embargo --EMBARGOS--
                    group by x.nro_cuenta, x.nro_documento)
             where ge.nro_cuenta = gcc.nro_cuenta
               and gcc.cod_persona = gec.cod_persona
               and ged.nro_cuenta = ge.nro_cuenta
               and gem.cod_embargo = ged.cod_embargo
               and ahv.nro_cuenta = gcc.nro_cuenta
               and xx_nro_cuenta = ge.nro_cuenta
               and nro_documento = ged.cod_embargo
               and gem.estado = 'A'
               and gcc.relacion = 'P'
               and ahv.est_batch != 'C';
   BEGIN
      v_tip_saldo       := 'Q';
      v_tip_movimiento  := 'C';
      v_cod_transaccion := 855;
      v_cod_plazo       := 1;
      v_cod_cau_embargo := fug_obt_pardinamico('COD_CAU_BLO_EMBAR');
      FOR i IN emb LOOP
         fu_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, v_cod_transaccion, i.cod_moneda,
                          i.cod_sec_contable, i.cod_tip_deudor, i.residente, 1, v_tip_movimiento,
                          v_cod_rubro, i.est_batch, /*v_tip_renovacion*/ NULL, i.cat_riesgo,
                          /*v_tip_interes*/ NULL, /*v_tip_operacion*/ NULL,
                          /*v_cod_sit_contable*/ NULL);

         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_sec_contable = i.cod_sec_contable
               AND cod_tip_deudor = i.cod_tip_deudor
               AND situacion = i.est_batch
               AND cat_automatica = i.cat_riesgo
               AND residente = i.residente
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.mto_embargado
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.mto_embargado
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.mto_embargado, 0);
            END IF;

         EXCEPTION
            WHEN no_data_found THEN

               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion, cat_automatica,
                   cod_sit_contable)
               VALUES
                  (i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.cod_sec_contable,
                   i.cod_tip_deudor, i.residente, i.cod_moneda, i.est_batch, v_tip_saldo,
                   v_cod_plazo, NULL, NULL, i.mto_embargado, v_cod_rubro, v_nro_referencia, NULL,
                   i.cat_riesgo, NULL);

               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.mto_embargado, 0);

         END;

       END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_EMBARGOS:' || SQLERRM);
   END;
   -- fin de Inventario de cuentas embargadas.

   -- Inventario de Comisiones Seguros Vida e Incendio
   PROCEDURE pr_inv_com_seguros IS
    CURSOR c_prestamos IS
      SELECT *
        FROM pr_cta_prestamos a
       WHERE a.estado NOT IN ('I','N')
         AND EXISTS (SELECT 1 FROM pr_cta_gastos b
                      WHERE b.nro_cuenta = a.nro_cuenta
                        AND b.cod_transaccion IN (1520,1521)
                        AND b.fec_ult_pago IS NULL)
         -----------------------------------------------------------
         --Proyecto SDSEGVID-3 Seguro de Vida Distribuido (1521)----
         --Exclusion ctas c/seg. distr. son contabil. en ganancias--
         -----------------------------------------------------------
         and not exists (select 1
                           from ba_tab_dat_adicionales x
                          where x.tab_relacion = 'PR_SOLICITUDES'
                            and x.parametro = 'PRE_IND_CUO_CAL_SEGURO'
                            and x.referencia = a.nro_solicitud
                            and x.val_parametro = 'S')
  ORDER BY a.fec_inicio;

    CURSOR c_detalles(p_nro_cta pr_cta_gastos.nro_cuenta%TYPE) IS
      SELECT *
        FROM pr_cta_gastos b
       WHERE b.nro_cuenta = p_nro_cta
         AND cod_transaccion IN (1520,1521)
         AND b.fec_ult_pago IS NULL
    ORDER BY 1;

  v_cod_ent_segvida      ge_entes.cod_ente%TYPE;
  v_cod_ent_segince      ge_entes.cod_ente%TYPE;
  v_cod_tas_pri_vida     ge_tasas.cod_tasa%TYPE;
  v_cod_tas_pri_incendio ge_tasas.cod_tasa%TYPE;
  v_cod_tas_vida         ge_tasas.cod_tasa%TYPE;
  v_cod_tas_incendio     ge_tasas.cod_tasa%TYPE;
  v_redondeo             NUMBER;
  v_fec_vigencia         DATE;
  v_tip_valor            ge_tasas.tip_valor%TYPE;
  v_tipo                 ge_tasas.tipo%TYPE;
  v_val_tas_pri_vida     ge_tas_fechas.val_tasa%TYPE;
  v_val_tas_vida         ge_tas_fechas.val_tasa%TYPE;
  v_val_tas_pri_incendio ge_tas_fechas.val_tasa%TYPE;
  v_val_tas_incendio     ge_tas_fechas.val_tasa%TYPE;
  v_val_tas_vida_global  ge_tas_fechas.val_tasa%TYPE; -- tasa final a aplicar directo al cargo.
  v_val_tas_ince_global  ge_tas_fechas.val_tasa%TYPE; -- tasa final a aplicar directo al cargo.
  v_tot_car_incendio     NUMBER;
  v_tot_car_vida         NUMBER;
  v_mto_car_vida         NUMBER;
  v_mto_car_incendio     NUMBER;
  v_cod_sec_contable     ge_clientes.cod_sec_contable%TYPE;
  v_cod_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
  v_residente            ge_clientes.residente%TYPE;
  v_cod_plazo            ge_plz_contables.cod_plazo%TYPE;
  v_cat_riesgo           NUMBER;
  v_saldo                NUMBER;
  v_nro_referencia       cb_sal_inventarios.nro_referencia%TYPE;
  v_cod_rubro            cb_sal_inventarios.cod_rubro%TYPE;
  v_tip_movimiento       VARCHAR2(1);
  v_cod_tra_rubro        ge_transacciones.cod_transaccion%TYPE;
  v_tip_saldo            cb_sal_inventarios.tip_saldo%TYPE;
  v_cod_mon_local        ge_movimientos.cod_moneda%type  := pag_gen.fu_obt_mon_local;

  --------------------------------------------------------------------------------------------
  function Fu_red_centena(p_importe in number)  return number is
  v_imp number;
  v_imp_cen number;

  begin
    if  p_importe/100 = trunc(p_importe/100) then  -- esta bien
      v_imp_cen := p_importe;
    else
      v_imp := round(p_importe / 100);
      v_imp_cen := v_imp * 100;
      loop
        if v_imp_cen >= p_importe then
          exit;
        end if;
        v_imp_cen := v_imp_Cen + 100;
      end loop;
    End if;
    return v_imp_Cen;
  END;

BEGIN

  FOR k IN c_prestamos LOOP
    v_cod_ent_segvida := NULL;
    v_cod_ent_segince := NULL;

    v_mto_car_incendio := 0;
    v_mto_car_vida     := 0;

    v_tot_car_vida     := 0;
    v_tot_car_incendio := 0;
    BEGIN
      SELECT a.cod_ent_seguro
        into v_cod_ent_segvida
        from pr_sol_cargos a
       where a.nro_solicitud = k.nro_solicitud
         and a.cod_transaccion = 1521
         and exists (select 1 from pr_cta_gastos b
                      where b.nro_cuenta = k.nro_cuenta
                        and b.cod_transaccion = 1521);
    exception
      when others then
      null;
    end;
    ---
    begin
      select a.cod_ent_seguro
        into v_cod_ent_segince
        from pr_sol_cargos a
       where a.nro_solicitud = k.nro_solicitud
         and a.cod_transaccion = 1520
         and exists (select 1 from pr_cta_gastos b
                      where b.nro_cuenta = k.nro_cuenta
                        and b.cod_transaccion = 1520);
    exception
      when others then
      null;
    end;
    v_redondeo             := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', k.cod_modulo, k.cod_modalidad, k.cod_moneda, k.cod_oficina);

    if v_cod_ent_segvida is not null then
      v_cod_tas_pri_vida     := fug_obt_parentes(v_cod_ent_segvida, 'COD_TAS_PRI_ASE_VIDA');     -- 494
      v_cod_tas_vida         := fug_obt_parentes(v_cod_ent_segvida, 'COD_TAS_SEG_VIDA');         -- 90
    else
      v_cod_tas_pri_vida     := null;
      v_cod_tas_vida         := null;
    end if;
    if v_cod_ent_segince is not null then
      v_cod_tas_pri_incendio := fug_obt_parentes(v_cod_ent_segince, 'COD_TAS_PRI_ASE_INCENDIO'); -- 495
      v_cod_tas_incendio     := fug_obt_parentes(v_cod_ent_segince, 'COD_TAS_SEG_INCENDIO');     -- 91
    else
      v_cod_tas_pri_incendio := null;
      v_cod_tas_incendio     := null;
    end if;

    if v_cod_tas_pri_vida is not null then
      -- Obtiene valor de tasa prima Vida
      PAG_GEN.PR_OBT_VAL_TASA(k.cod_modulo,
                              k.cod_modalidad,
                              k.cod_oficina,
                              k.nro_cuenta,
                              k.cod_moneda,
                              0,
                              'N',
                              v_cod_tas_pri_vida,
                              NULL,
                              k.fec_inicio,
                              v_val_tas_pri_vida,
                              v_fec_vigencia,
                              v_tip_valor,
                              v_tipo);
      if v_val_tas_pri_vida is null then
        raise_application_error(-20000,'No encuentra valor de la tasa Prima vida.');
      end if;
    end if;

    if v_cod_tas_pri_incendio is not null then
      -- Obtiene valor de tasa prima Incendio
      PAG_GEN.PR_OBT_VAL_TASA(k.cod_modulo,
                              k.cod_modalidad,
                              k.cod_oficina,
                              k.nro_cuenta,
                              k.cod_moneda,
                              0,
                              'N',
                              v_cod_tas_pri_incendio,
                              NULL,
                              k.fec_inicio,
                              v_val_tas_pri_incendio,
                              v_fec_vigencia,
                              v_tip_valor,
                              v_tipo);
      if v_val_tas_pri_incendio is null then
        raise_application_error(-20000,'No encuentra valor de la tasa Prima Incendio.');
      end if;
    end if;

    if v_cod_tas_vida is not null then
      -- Obtiene valor de tasa Vida
      PAG_GEN.PR_OBT_VAL_TASA(k.cod_modulo,
                              k.cod_modalidad,
                              k.cod_oficina,
                              k.nro_cuenta,
                              k.cod_moneda,
                              0,
                              'N',
                              v_cod_tas_vida,
                              NULL,
                              k.fec_inicio,
                              v_val_tas_vida,
                              v_fec_vigencia,
                              v_tip_valor,
                              v_tipo);
      if v_val_tas_vida is null then
        raise_application_error(-20000,'No encuentra valor de la tasa vida.');
      end if;
    end if;

    if v_cod_tas_incendio is not null then
      -- Obtiene valor de tasa Incendio
      PAG_GEN.PR_OBT_VAL_TASA(k.cod_modulo,
                              k.cod_modalidad,
                              k.cod_oficina,
                              k.nro_cuenta,
                              k.cod_moneda,
                              0,
                              'N',
                              v_cod_tas_incendio,
                              NULL,
                              k.fec_inicio,
                              v_val_tas_incendio,
                              v_fec_vigencia,
                              v_tip_valor,
                              v_tipo);
      if v_val_tas_incendio is null then
        raise_application_error(-20000,'No encuentra valor de la tasa Incendio.');
      end if;
    end if;

    for x in c_detalles(k.nro_cuenta) loop
      if x.cod_transaccion = 1520 then
        v_tot_car_incendio := x.monto;
        v_tot_car_vida     := 0;
      elsif x.cod_transaccion = 1521 then
        v_tot_car_vida     := x.monto;
        v_tot_car_incendio := 0;
      end if;

      if v_val_tas_pri_vida < v_val_tas_vida then
        v_val_tas_vida_global := v_val_tas_pri_vida * 100 / v_val_tas_vida;
        v_mto_car_vida        := (round((v_tot_car_vida * (v_val_tas_vida_global) / 100),v_redondeo));

        --ITGF - Diferencias en Saldos de Inventario y Saldos Contables en el Rubro Seguro de Vida por Cobrar -SC 13187
        /*if x.cod_moneda = v_cod_mon_local then
          v_mto_car_vida     := Fu_red_centena(v_mto_car_vida);
        end if;*/
        v_mto_car_vida := v_tot_car_vida - v_mto_car_vida;
      else
        v_mto_car_vida := 0;
      end if;

      if v_val_tas_pri_incendio < v_val_tas_incendio then
        v_val_tas_ince_global := v_val_tas_pri_incendio * 100 / v_val_tas_incendio;
        v_mto_car_incendio := (round((v_tot_car_incendio * (v_val_tas_ince_global) / 100),v_redondeo));
        v_mto_car_incendio := v_tot_car_incendio - v_mto_car_incendio;
      else
        v_mto_car_incendio := 0;
      end if;


    /*INSERTA INVENTARIO*/
    BEGIN
      SELECT a.cod_sec_contable, a.cod_tip_deudor, a.residente, to_number(nvl(a.cat_riesgo, 1))
        INTO v_cod_sec_contable, v_cod_tip_deudor, v_residente, v_cat_riesgo
        FROM ge_clientes a, ge_cta_clientes b
       WHERE a.cod_persona = b.cod_persona
         AND b.nro_cuenta = k.nro_cuenta
         AND b.relacion = 'P';
    END;
    --
    BEGIN
      SELECT a.cod_plazo
        INTO v_cod_plazo
        FROM ge_plz_contables a
       WHERE a.can_dias = (SELECT MIN(b.can_dias)
                             FROM ge_plz_contables b
                            WHERE b.can_dias >= k.fec_vencimiento - k.fec_inicio);
    END;
    v_tip_saldo       := 'U'; -- Seguros de vida e incendio Transitorios
    v_tip_movimiento  := 'C';
    if x.cod_transaccion = 1520 then
      v_saldo         := v_mto_car_incendio;
      v_cod_tra_rubro := 1630;
    else
      v_saldo := v_mto_car_vida;
      v_cod_tra_rubro := 1634;
    end if;

    --
    fu_obt_cod_rubro(k.cod_modulo, k.cod_modalidad, v_cod_tra_rubro, k.cod_moneda,
                     v_cod_sec_contable, v_cod_tip_deudor, v_residente, to_char(v_cod_plazo),
                     v_tip_movimiento, v_cod_rubro, k.est_batch, k.tip_renovacion, v_cat_riesgo,
                     k.tip_interes, k.tipo, k.cod_sec_credito);
    BEGIN
      SELECT nro_referencia
        INTO v_nro_referencia
        FROM cb_sal_inventarios
       WHERE cod_modulo = k.cod_modulo
         AND cod_modalidad = k.cod_modalidad
         AND cod_oficina = k.cod_oficina
         AND cod_moneda = k.cod_moneda
         AND cod_sec_contable = v_cod_sec_contable
         AND cod_tip_deudor = v_cod_tip_deudor
         AND residente = v_residente
         AND situacion = k.est_batch
         AND cod_plazo = to_char(v_cod_plazo)
         AND tip_operacion = k.tipo
         AND tip_renovacion = k.tip_renovacion
         AND tip_interes = k.tip_interes
         AND cat_automatica = v_cat_riesgo
         AND cod_sit_contable = k.cod_sec_credito
         AND cod_rubro = v_cod_rubro;

      UPDATE cb_sal_inventarios
         SET sal_total = nvl(sal_total, 0) + v_saldo
       WHERE nro_referencia = v_nro_referencia;

      UPDATE cb_sal_inventarios_det
         SET sal_actual = nvl(sal_actual, 0) + v_saldo
       WHERE nro_referencia = v_nro_referencia
         AND nro_cuenta = k.nro_cuenta;

      IF SQL%NOTFOUND THEN
         INSERT INTO cb_sal_inventarios_det
            (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
         VALUES
            (v_nro_referencia, k.nro_cuenta, v_saldo, 0);
      END IF;

      ------------------------------------------------------------------------------------------------------------------

   EXCEPTION
      WHEN no_data_found THEN


      IF nvl(v_saldo, 0) <> 0 THEN

        SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

        INSERT INTO cb_sal_inventarios
             (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
              residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
              tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
              cat_automatica, cod_sit_contable)
        VALUES
             (k.cod_modulo, k.cod_modalidad, k.cod_oficina, v_cod_sec_contable, v_cod_tip_deudor,
              v_residente, k.cod_moneda, k.est_batch, v_tip_saldo, v_cod_plazo, k.tipo,
              k.tip_interes, v_saldo, v_cod_rubro, v_nro_referencia, k.tip_renovacion,
              v_cat_riesgo, k.cod_sec_credito);

        IF nvl(v_saldo, 0) <> 0 THEN
          INSERT INTO cb_sal_inventarios_det
                (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
          VALUES
                (v_nro_referencia, k.nro_cuenta, v_saldo, 0);
        END IF;
      END IF;
    END;

    end loop;
  end loop;
  EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_COM_SEGUROS: ' || SQLERRM);
end;

 -- Datos de Inventario Inventario Custodia de Cheques - LCabrera (Agosto/2014)
 /*
   CRO-JM-09/2014 Se agreagaron cambios para que inserte en Saldos de Inventarios Contables
 */
 PROCEDURE pr_inv_cus_cheq IS
   v_cod_transaccion   ge_transacciones.cod_transaccion%TYPE := 59;
   v_tip_saldo         cb_sal_inventarios.tip_saldo%TYPE := 'Q';
   v_cod_plazo         NUMBER(03) := 1;
   v_cod_rubro         cb_sal_inventarios.cod_rubro%TYPE;
   v_rowid             VARCHAR2(30);
   v_nro_referencia    cb_sal_inventarios.nro_referencia%TYPE;
   v_nro_ref_anterior  cb_sal_inventarios.nro_referencia%TYPE;
   v_can_referencia    number := 0;
   v_cod_rubro_2       cb_sal_inventarios.cod_rubro%TYPE;
   v_rowid_2           VARCHAR2(30);
   v_nro_referencia_2  cb_sal_inventarios.nro_referencia%TYPE;
   v_val_nominal       number;

   ---cursor por el alta de las custodias:
   CURSOR custodia IS
     select gcc.cod_modulo,
            ged.nro_documento,
            gcc.cod_modalidad,
            gem.cod_oficina cod_oficina,
            gem.cod_che_custodia,
            gec.cod_sec_contable,
            gec.cod_tip_deudor,
            gec.residente,
            fup_obt_categoria(gec.cat_automatica, gec.cat_subjetiva) cat_riesgo,
            gem.fec_apertura,
            cte.cod_moneda,
            cte.est_batch,
            ged.val_nominal
       from ge_cuentas           ge,
            ge_cta_clientes      gcc,
            cc_cta_corrientes    cte,
            ge_clientes          gec,
            cc_che_custodias     gem,
            cc_che_custodias_det ged


      where ge.nro_cuenta        = gcc.nro_cuenta
        and gcc.cod_persona      = gec.cod_persona
        and gem.nro_cta_credito  = ge.nro_cuenta
        and gem.cod_che_custodia = ged.cod_che_custodia
        and cte.nro_cuenta       = gcc.nro_cuenta
        and gem.estado           = 'N' -- Normal en la cabecera
        and ged.estado           = 'C' -- En Custodia en cuenta en el detallee. CRO-JM-10/2014: Se descomentó esta línea para que retorne solamente los que aún están en custodia
        and gcc.relacion         = 'P'
        and cte.est_batch        != 'C' --cancelado
     union
     select gcc.cod_modulo,
            ged.nro_documento,
            gcc.cod_modalidad,
            gem.cod_oficina cod_oficina,
            gem.cod_che_custodia,
            gec.cod_sec_contable,
            gec.cod_tip_deudor,
            gec.residente,
            fup_obt_categoria(gec.cat_automatica, gec.cat_subjetiva) cat_riesgo,
            gem.fec_apertura,
            avi.cod_moneda,
            avi.est_batch,
            ged.val_nominal
       from ge_cuentas           ge,
            ge_cta_clientes      gcc,
            ah_cta_vistas        avi,
            ge_clientes          gec,
            cc_che_custodias     gem,
            cc_che_custodias_det ged
      where ge.nro_cuenta        = gcc.nro_cuenta
        and gcc.cod_persona      = gec.cod_persona
        and gem.nro_cta_credito  = ge.nro_cuenta
        and gem.cod_che_custodia = ged.cod_che_custodia
        and avi.nro_cuenta       = gcc.nro_cuenta
        and gem.estado           = 'N' -- Normal en la cabecera
        and ged.estado           = 'C' -- En Custodia en cuenta en el detallee. CRO-JM-10/2014: Se descomentó esta línea para que retorne solamente los que aún están en custodia
        and gcc.relacion         = 'P'
        and avi.est_batch        != 'C'; --cancelado


 BEGIN
  FOR i IN custodia LOOP
     fu_obt_cod_rubro(i.cod_modulo,
                      i.cod_modalidad,
                      v_cod_transaccion,
                      i.cod_moneda,
                      i.cod_sec_contable,
                      i.cod_tip_deudor,
                      i.residente,
                      1,
                      'C',
                      v_cod_rubro,
                      i.est_batch,
                      NULL,
                      i.cat_riesgo,
                      NULL,
                      NULL,
                      NULL);

     BEGIN
       v_val_nominal := i.val_nominal * -1; --> Según Contabilidad, la 52 siempre debe ir en Negativo
       SELECT nro_referencia, ROWID
         INTO v_nro_referencia, v_rowid
         FROM cb_sal_inventarios
        WHERE cod_modulo       = i.cod_modulo
          AND cod_modalidad    = i.cod_modalidad
          AND cod_plazo        = v_cod_plazo
          AND tip_saldo        = v_tip_saldo
          AND cod_oficina      = i.cod_oficina
          AND cod_moneda       = i.cod_moneda
          AND cod_sec_contable = i.cod_sec_contable
          AND cod_tip_deudor   = i.cod_tip_deudor
          AND situacion        = i.est_batch
          AND cat_automatica   = i.cat_riesgo
          AND residente        = i.residente
          AND cod_rubro        = v_cod_rubro;


       UPDATE cb_sal_inventarios
          SET sal_total = nvl(sal_total, 0) + v_val_nominal
        WHERE nro_referencia = v_nro_referencia;


       UPDATE cb_sal_inventarios_det
          SET sal_actual = nvl(sal_actual, 0) + v_val_nominal
        WHERE nro_referencia = v_nro_referencia
          AND nro_cuenta     = i.nro_documento;


       IF SQL%NOTFOUND THEN
         INSERT INTO cb_sal_inventarios_det
           (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
         VALUES
           (v_nro_referencia, i.nro_documento, v_val_nominal, 0); --i.cod_che_custodia, v_val_nominal, 0); (DYDMR-1493 - 19/01/2015)

       END IF;


     EXCEPTION
       WHEN no_data_found THEN

         SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
        /* v_can_referencia := v_can_referencia + 1;
         If v_nro_ref_anterior is null then
            v_nro_ref_anterior := v_nro_referencia;
         End If;*/


         INSERT INTO cb_sal_inventarios
           (cod_modulo,
            cod_modalidad,
            cod_oficina,
            cod_sec_contable,
            cod_tip_deudor,
            residente,
            cod_moneda,
            situacion,
            tip_saldo,
            cod_plazo,
            tip_operacion,
            tip_interes,
            sal_total,
            cod_rubro,
            nro_referencia,
            tip_renovacion,
            cat_automatica,
            cod_sit_contable)
         VALUES
           (i.cod_modulo,
            i.cod_modalidad,
            i.cod_oficina,
            i.cod_sec_contable,
            i.cod_tip_deudor,
            i.residente,
            i.cod_moneda,
            i.est_batch,
            v_tip_saldo,
            v_cod_plazo,
            NULL,
            NULL,
            v_val_nominal,
            v_cod_rubro,
            v_nro_referencia,
            NULL,
            i.cat_riesgo,
            NULL);


         INSERT INTO cb_sal_inventarios_det
           (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
         VALUES
           (v_nro_referencia, i.nro_documento, v_val_nominal, 0); --i.cod_che_custodia,v_val_nominal, 0); (DYDMR-1493 - 19/01/2015)


     END;

   END LOOP;

   FOR i IN custodia LOOP
     fu_obt_cod_rubro(i.cod_modulo,
                      i.cod_modalidad,
                      v_cod_transaccion,
                      i.cod_moneda,
                      i.cod_sec_contable,
                      i.cod_tip_deudor,
                      i.residente,
                      1,
                      'D',
                      v_cod_rubro_2,
                      i.est_batch,
                      NULL,
                      i.cat_riesgo,
                      NULL,
                      NULL,
                      NULL);

     BEGIN

       SELECT nro_referencia, ROWID
         INTO v_nro_referencia_2, v_rowid_2
         FROM cb_sal_inventarios
        WHERE cod_modulo       = i.cod_modulo
          AND cod_modalidad    = i.cod_modalidad
          AND cod_plazo        = v_cod_plazo
          AND tip_saldo        = v_tip_saldo
          AND cod_oficina      = i.cod_oficina
          AND cod_moneda       = i.cod_moneda
          AND cod_sec_contable = i.cod_sec_contable
          AND cod_tip_deudor   = i.cod_tip_deudor
          AND situacion        = i.est_batch
          AND cat_automatica   = i.cat_riesgo
          AND residente        = i.residente
          AND cod_rubro        = v_cod_rubro_2;


       UPDATE cb_sal_inventarios
          SET sal_total = nvl(sal_total, 0) + i.val_nominal
        WHERE nro_referencia = v_nro_referencia_2;


       UPDATE cb_sal_inventarios_det
          SET sal_actual = nvl(sal_actual, 0) + i.val_nominal
        WHERE nro_referencia = v_nro_referencia_2
          AND nro_cuenta = i.nro_documento;


       IF SQL%NOTFOUND THEN
         INSERT INTO cb_sal_inventarios_det
           (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
         VALUES
           (v_nro_referencia_2, i.nro_documento, i.val_nominal, 0); -- i.cod_che_custodia, i.val_nominal, 0); (DYDMR-1493 - 19/01/2015)

       END IF;


     EXCEPTION
       WHEN no_data_found THEN

         SELECT s_nro_referencia.nextval INTO v_nro_referencia_2 FROM dual;


         INSERT INTO cb_sal_inventarios
           (cod_modulo,
            cod_modalidad,
            cod_oficina,
            cod_sec_contable,
            cod_tip_deudor,
            residente,
            cod_moneda,
            situacion,
            tip_saldo,
            cod_plazo,
            tip_operacion,
            tip_interes,
            sal_total,
            cod_rubro,
            nro_referencia,
            tip_renovacion,
            cat_automatica,
            cod_sit_contable)
         VALUES
           (i.cod_modulo,
            i.cod_modalidad,
            i.cod_oficina,
            i.cod_sec_contable,
            i.cod_tip_deudor,
            i.residente,
            i.cod_moneda,
            i.est_batch,
            v_tip_saldo,
            v_cod_plazo,
            NULL,
            NULL,
            i.val_nominal,
            v_cod_rubro_2,
            v_nro_referencia_2,
            NULL,
            i.cat_riesgo,
            NULL);


         INSERT INTO cb_sal_inventarios_det
           (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
         VALUES
           (v_nro_referencia_2, i.nro_documento, i.val_nominal, 0); -- i.cod_che_custodia, i.val_nominal, 0); (DYDMR-1493 - 19/01/2015)


     END;


   END LOOP;

 EXCEPTION
   WHEN OTHERS THEN
        raise_application_error(-20000,'ERROR EN PR_INV_CUS_CHEQUES:' || SQLERRM);

 END;
   -- Fin de Inventario de Custodia de Cheques alta
      -------------------------------------------------------------
   -- Inventario de cheques horario extendido  --
   PROCEDURE pr_inv_hor_extendido IS
      v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
      v_residente        cb_sal_inventarios.residente%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_sit_saldo        VARCHAR2(01);
      v_tip_credito      VARCHAR2(01);
      v_categoria        cb_sal_inventarios.cat_automatica%TYPE;
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes      cb_sal_inventarios.tip_interes%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_fila             VARCHAR2(30);
      v_cod_persona      ba_personas.cod_persona%TYPE;
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
      v_cod_plazo        NUMBER(2);
      v_cod_tip_deudor   cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_sal_tot_batch    NUMBER(22, 2);
      v_sal_interes      NUMBER(22, 2);
      v_tot_interes      NUMBER(16, 2);
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_sal_ret_batch    NUMBER(22, 2);
      v_sal_blo_batch    NUMBER(22, 2);
      v_sal_disponible   NUMBER(22, 2);
      v_sal_contable     NUMBER(22, 2);
      v_cod_retencion    NUMBER(3);
      v_monto_retencion  NUMBER(22, 2);
      v_cod_transaccion  NUMBER(05);
    -- Cuentas de cheques horario extendido
    -- 510306690600305  PARA DEPOSITOS EN USD-HORARIO EXTENDIDO
    --520306620600305  VAL.M.E.REC.P/DEP.USD-HORARIO EXTENDIDO
      ------------------------- DEFINE MOVIMIENTOS -----------------------------
      CURSOR movimien IS
      select  m.cod_modulo,
                   m.cod_modalidad,
                   m.cod_oficina,
                   (Select c.cod_sec_contable from ge_clientes c where c.cod_persona = fug_obt_cli_principal(m.nro_cuenta) ) cod_sec_contable,
                   (Select c.cod_tip_deudor from ge_clientes c where c.cod_persona = fug_obt_cli_principal(m.nro_cuenta) ) cod_tip_deudor,
                   (Select c.residente from ge_clientes c where c.cod_persona = fug_obt_cli_principal(m.nro_cuenta) ) residente,
                   m.cod_moneda,
                   'N',
                   1,
                   decode(m.cod_transaccion,'935',m.monto*-1,'906',m.monto*-1,m.monto) ,
                   nvl(m.nro_cuenta,m.nro_documento) as nro_cuenta,
                   fug_obt_cli_principal(m.nro_cuenta) cod_persona,
                  '520306620600305' cod_rubro
  from ge_movimientos m
 where m.cod_moneda = 'USD'
   and m.reversado = 'N'
   and exists
 (select 1  from ge_transacciones a, ge_tip_asientos n
         where a.cod_modulo = m.cod_modulo
           and a.cod_modalidad = m.cod_modalidad
           and a.cod_transaccion = m.cod_transaccion
           and (a.cod_tip_asiento = n.cod_tip_asiento or
               a.cod_tip_asiento2 = n.cod_tip_asiento)
           and n.cod_rubro in ('520306620600305'))
   and m.nro_documento in
      ( select m.nro_documento
          from ge_movimientos m
         where m.COD_MONEDA = 'USD'
           and m.reversado = 'N'
           and exists
         (select 1
                  from ge_transacciones a, ge_tip_asientos n
                 where a.cod_modulo = m.cod_modulo
                   and a.cod_modalidad = m.cod_modalidad
                   and a.cod_transaccion = m.cod_transaccion
                   and (a.cod_tip_asiento = n.cod_tip_asiento or
                       a.cod_tip_asiento2 = n.cod_tip_asiento)
                   and n.cod_rubro in ('520306620600305'))
         group by nro_documento
        having count(*) < 2 and max(cod_transaccion) not in('906', '935'))
union all --DYDMR-6278 - 17/03/2017 -- se agrega el ALL para exponer las operaciones identicas
   select     m.cod_modulo,
                   m.cod_modalidad,
                   m.cod_oficina,
                   (Select c.cod_sec_contable from ge_clientes c where c.cod_persona = fug_obt_cli_principal(m.nro_cuenta) ) cod_sec_contable,
                   (Select c.cod_tip_deudor from ge_clientes c where c.cod_persona = fug_obt_cli_principal(m.nro_cuenta) ) cod_tip_deudor,
                   (Select c.residente from ge_clientes c where c.cod_persona = fug_obt_cli_principal(m.nro_cuenta) ) residente,
                   m.cod_moneda,
                   'N',
                   1,
                    decode(m.cod_transaccion,'935',abs(m.monto),'906',abs(m.monto),m.monto*-1),
                   nvl(m.nro_cuenta,m.nro_documento) as nro_cuenta,
                   fug_obt_cli_principal(m.nro_cuenta) cod_persona,
                  '510306690600305' cod_rubro
  from ge_movimientos m
 where m.cod_moneda = 'USD'
   and m.reversado = 'N'
   and exists
 (select 1  from ge_transacciones a, ge_tip_asientos n
         where a.cod_modulo = m.cod_modulo
           and a.cod_modalidad = m.cod_modalidad
           and a.cod_transaccion = m.cod_transaccion
           and (a.cod_tip_asiento = n.cod_tip_asiento or
               a.cod_tip_asiento2 = n.cod_tip_asiento)
           and n.cod_rubro in ('510306690600305'))
   and m.nro_documento in
      ( select m.nro_documento
          from ge_movimientos m
         where m.COD_MONEDA = 'USD'
           and m.reversado = 'N'
           and exists
         (select 1
                  from ge_transacciones a, ge_tip_asientos n
                 where a.cod_modulo = m.cod_modulo
                   and a.cod_modalidad = m.cod_modalidad
                   and a.cod_transaccion = m.cod_transaccion
                   and (a.cod_tip_asiento = n.cod_tip_asiento or
                       a.cod_tip_asiento2 = n.cod_tip_asiento)
                   and n.cod_rubro in ('510306690600305'))
         group by nro_documento
        having count(*) < 2 and max(cod_transaccion) not in('906', '935'))  ;
   BEGIN
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;
      ------------------------- LEER MOVIMIEN ------------------------------
      OPEN movimien;
      LOOP
         FETCH movimien
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_sec_contable,
                 v_cod_tip_deudor,
                 v_residente,
                 v_cod_moneda,
                 v_sit_saldo,
                 v_cod_plazo,
                 v_sal_tot_batch,
                 v_nro_cuenta,
                 v_cod_persona,
                 v_cod_rubro;
         EXIT WHEN movimien%NOTFOUND;
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) ---
         --------------------------------------------------------------
         v_tip_saldo := 'B';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
         --------------------------------------------------------------
         v_tip_interes := 'X';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
         --------------------------------------------------------------
         v_tip_credito := 'X';
         --------------------------------------------------------------
         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_fila
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_sit_saldo
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_credito
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            ---
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + decode(v_cod_rubro, '520306620600305',v_sal_tot_batch*-1,abs(v_sal_tot_batch))
             WHERE ROWID = v_fila;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + decode(v_cod_rubro, '520306620600305',v_sal_tot_batch*-1,abs(v_sal_tot_batch))
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, decode(v_cod_rubro, '520306620600305',v_sal_tot_batch*-1,abs(v_sal_tot_batch)), 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               ---
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                   v_cod_plazo, v_tip_credito, v_tip_interes, decode(v_cod_rubro, '520306620600305',v_sal_tot_batch*-1,abs(v_sal_tot_batch)), v_cod_rubro,
                   v_nro_referencia);
               ---
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, decode(v_cod_rubro, '520306620600305',v_sal_tot_batch*-1,abs(v_sal_tot_batch)), 0);
         END;
      END LOOP;
      CLOSE movimien;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR en ACU_CTABAN_NORMAL ' || SQLERRM);
   END;
   -- Fin de Inventario de cheques horario extendido  --

   -- Inventario de Comisiones Seguros Fraude Tarjetas Debito
   PROCEDURE pr_inv_seg_fra IS
      v_fec_actual       DATE := pag_cal.fu_obt_fec_actual(4);
      v_cod_sec_contable ge_clientes.cod_sec_contable%TYPE;
      v_cod_tip_deudor   ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_cat_riesgo       NUMBER;
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_tip_movimiento   VARCHAR2(1);
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes      cb_sal_inventarios.tip_interes%TYPE;
      v_tip_cuenta       cb_sal_inventarios.tip_operacion%TYPE;
      v_tip_renovacion   cb_sal_inventarios.tip_renovacion%TYPE;
      v_cod_sec_credito  pr_cta_prestamos.cod_sec_credito%TYPE;
      v_cod_mon_local    ge_movimientos.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
      v_cod_ente         ge_entes.cod_ente%TYPE := pag_deb.fu_obt_ente;
      v_cod_tra_alta     ge_movimientos.cod_transaccion%TYPE := fug_obt_parentes(v_cod_ente,
                                                                                 'TRA_ALT_SEG_TAR_DEB');
      v_cod_tra_ganancia ge_movimientos.cod_transaccion%TYPE := fug_obt_parentes(v_cod_ente,
                                                                                 'TRA_GAN_SEG_TAR_DEB');
      c_mto_seguro       ge_movimientos.monto%TYPE := fug_obt_parentes(v_cod_ente,
                                                                       'MTO_CRE_SEG_TAR_DEB');
      c_mto_debito       ge_movimientos.monto%TYPE := fug_obt_parentes(v_cod_ente,
                                                                       'MTO_DEB_SEG_TAR_DEB');
      v_mto_seguro       ge_seg_fraude.mto_seguro%TYPE;
      v_mto_ganancia     ge_seg_fraude.mto_ganancia%TYPE;
      v_redondeo         NUMBER(5);
      v_por_ganancia     NUMBER(16, 4);
     CURSOR c_seguros IS
         SELECT a.nro_cuenta, a.fec_activacion, a.cod_moneda,
                (a.mto_seguro - (SELECT nvl(SUM(t.mto_ganancia), 0)
                                   FROM ge_seg_fraude_det t
                                  WHERE t.ano = a.ano
                                    AND t.nro_cuenta = a.nro_cuenta
                                    AND t.cobrado = 'S')) mto_seguro,--DYD-SDSL-2878
                (a.mto_ganancia - a.mto_acumulado) mto_ganancia,
                a.fec_alta, a.cotizacion, a.cod_oficina
           FROM ge_seg_fraude a
          WHERE /*((*/a.estado = 'A'/*) OR*/
          UNION --- DYDMR-2076
         SELECT a.nro_cuenta, a.fec_activacion, a.cod_moneda,
                (a.mto_seguro - (SELECT nvl(SUM(t.mto_ganancia), 0)
                                   FROM ge_seg_fraude_det t
                                  WHERE t.ano = a.ano
                                    AND t.nro_cuenta = a.nro_cuenta
                                    AND t.cobrado = 'S')) mto_seguro,--DYD-SDSL-2878
                (a.mto_ganancia - a.mto_acumulado) mto_ganancia,
                a.fec_alta, a.cotizacion, a.cod_oficina
           FROM ge_seg_fraude a
          WHERE a.estado = 'P'
            AND a.ano = to_number(to_char(v_fec_actual, 'yyyy'));

   BEGIN
      v_tip_saldo      := 'U'; -- Seguros de vida e incendio Transitorios
      --------------------------------------------------------------
      -- OBTIENE EL TIPO DE RENOVACION (X = NO IMPORTA)           --
      --------------------------------------------------------------
      v_tip_renovacion := 'X';
      --------------------------------------------------------------
      -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
      --------------------------------------------------------------
      v_tip_interes := 'X';
      --------------------------------------------------------------
      -- OBTIENE EL TIPO DE CUENTA (X = NO IMPORTA)               --
      --------------------------------------------------------------
      v_tip_cuenta := 'X';
      --------------------------------------------------------------
      -- OBTIENE EL SECTOR DEL CREDITO (X = NO IMPORTA)           --
      --------------------------------------------------------------
      v_cod_sec_credito := null;
      --------------------------------------------------------------
      v_por_ganancia := (c_mto_seguro * 100) / c_mto_debito;
      FOR i IN c_seguros LOOP
         IF i.cod_oficina IS NULL THEN
            i.cod_oficina := nvl(fug_obt_ofi_usuario(USER),fug_obt_ofi_matriz);
         END IF;
         pag_cta.pr_obt_cuenta(i.nro_cuenta);
         /*INSERTA INVENTARIO*/
         BEGIN
            SELECT a.cod_sec_contable, a.cod_tip_deudor, a.residente,
                   to_number(nvl(a.cat_riesgo, 1))
              INTO v_cod_sec_contable, v_cod_tip_deudor, v_residente, v_cat_riesgo
              FROM ge_clientes a, ge_cta_clientes b
             WHERE a.cod_persona = b.cod_persona
               AND b.nro_cuenta = i.nro_cuenta
               AND b.relacion = 'P';
         EXCEPTION
            WHEN OTHERS THEN
               v_cod_sec_contable := null;
               v_cod_tip_deudor   := null;
               v_residente        := null;
               v_cat_riesgo       := null;
         END;
         --
         BEGIN
            SELECT a.cod_plazo
              INTO v_cod_plazo
              FROM ge_plz_contables a
             WHERE a.can_dias =
                   (SELECT MIN(b.can_dias)
                      FROM ge_plz_contables b
                     WHERE b.can_dias >= add_months(i.fec_alta, 12) - i.fec_alta);
         EXCEPTION
            WHEN OTHERS THEN
               v_cod_plazo := null;
         END;
         /*
         || DYDMR-1899 ITGF - Resumen cuadre total del balance 12/05/2015 - SC 16587
         */
         --if v_cod_mon_local = pag_cta.g_ctas.cod_moneda then
            v_mto_seguro   := i.mto_seguro;
            v_mto_ganancia := i.mto_ganancia;
         --- DYDMR-2076: Dejar en 0 si es la cuota 12
         IF nvl(v_mto_seguro,0) < 0 THEN
            v_mto_seguro := 0;
         END IF;
         /*else
            v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                               pag_cta.g_ctas.cod_modulo,
                                               pag_cta.g_ctas.cod_modalidad,
                                               pag_cta.g_ctas.cod_moneda);
            v_mto_seguro   := round((nvl(i.mto_seguro, 0) / nvl(i.cotizacion, 1)), v_redondeo);
            v_mto_ganancia := round((nvl(i.mto_ganancia, 0) / nvl(i.cotizacion, 1)), v_redondeo);
         end if;*/
         /*
         || Por el ALTA
         */
         v_tip_movimiento := 'D';
         fu_obt_cod_rubro(pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad, v_cod_tra_alta,
                          v_cod_mon_local /*pag_cta.g_ctas.cod_moneda*/,
                          v_cod_sec_contable, v_cod_tip_deudor, v_residente,
                          to_char(v_cod_plazo), v_tip_movimiento, v_cod_rubro,
                          pag_cta.g_ctas.est_batch, v_tip_renovacion, v_cat_riesgo, v_tip_interes,
                          v_tip_cuenta, v_cod_sec_credito);

            BEGIN
               SELECT nro_referencia
                 INTO v_nro_referencia
                 FROM cb_sal_inventarios
                WHERE cod_modulo = pag_cta.g_ctas.cod_modulo
                  AND cod_modalidad = pag_cta.g_ctas.cod_modalidad
                  AND cod_oficina = i.cod_oficina /*pag_cta.g_ctas.cod_oficina*/
                  AND cod_moneda = v_cod_mon_local /*pag_cta.g_ctas.cod_moneda*/
                  AND cod_sec_contable = v_cod_sec_contable
                  AND cod_tip_deudor = v_cod_tip_deudor
                  AND residente = v_residente
                  AND situacion = pag_cta.g_ctas.est_batch
                  AND cod_plazo = to_char(v_cod_plazo)
                  AND tip_operacion = v_tip_movimiento
                  AND tip_renovacion = v_tip_renovacion
                  AND tip_interes = v_tip_interes
                  AND cat_automatica = v_cat_riesgo
                  AND cod_sit_contable = v_cod_sec_credito
                  AND cod_rubro = v_cod_rubro;

               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + v_mto_seguro
                WHERE nro_referencia = v_nro_referencia;

               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + v_mto_seguro
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = i.nro_cuenta;

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, i.nro_cuenta, v_mto_seguro, 0);
               END IF;

               ------------------------------------------------------------------------------------------------------------------

            EXCEPTION
               WHEN no_data_found THEN

                  IF nvl(v_mto_seguro, 0) <> 0 THEN

                     SELECT s_nro_referencia.nextval
                       INTO v_nro_referencia
                       FROM dual;

                     INSERT INTO cb_sal_inventarios
                        (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                         residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                         tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                         cat_automatica, cod_sit_contable)
                     VALUES
                        (pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                         i.cod_oficina /*pag_cta.g_ctas.cod_oficina*/, v_cod_sec_contable,
                         v_cod_tip_deudor, v_residente, v_cod_mon_local /*pag_cta.g_ctas.cod_moneda*/,
                         pag_cta.g_ctas.est_batch, v_tip_saldo,
                         v_cod_plazo, v_tip_movimiento, v_tip_interes, v_mto_seguro, v_cod_rubro,
                         v_nro_referencia, v_tip_renovacion, v_cat_riesgo, v_cod_sec_credito);

                     IF nvl(v_mto_seguro, 0) <> 0 THEN
                        INSERT INTO cb_sal_inventarios_det
                           (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                        VALUES
                           (v_nro_referencia, i.nro_cuenta, v_mto_seguro, 0);
                     END IF;
                  END IF;
            END;
         /*
         || Por la ganancia
         */
         v_tip_movimiento := 'C';
         fu_obt_cod_rubro(pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad, v_cod_tra_ganancia,
                          v_cod_mon_local /*pag_cta.g_ctas.cod_moneda*/,
                          v_cod_sec_contable, v_cod_tip_deudor, v_residente,
                          to_char(v_cod_plazo), v_tip_movimiento, v_cod_rubro,
                          pag_cta.g_ctas.est_batch, v_tip_renovacion, v_cat_riesgo, v_tip_interes,
                          v_tip_cuenta, v_cod_sec_credito);

            BEGIN
               SELECT nro_referencia
                 INTO v_nro_referencia
                 FROM cb_sal_inventarios
                WHERE cod_modulo = pag_cta.g_ctas.cod_modulo
                  AND cod_modalidad = pag_cta.g_ctas.cod_modalidad
                  AND cod_oficina = i.cod_oficina /*pag_cta.g_ctas.cod_oficina*/
                  AND cod_moneda = v_cod_mon_local /*pag_cta.g_ctas.cod_moneda*/
                  AND cod_sec_contable = v_cod_sec_contable
                  AND cod_tip_deudor = v_cod_tip_deudor
                  AND residente = v_residente
                  AND situacion = pag_cta.g_ctas.est_batch
                  AND cod_plazo = to_char(v_cod_plazo)
                  AND tip_operacion = v_tip_movimiento
                  AND tip_renovacion = v_tip_renovacion
                  AND tip_interes = v_tip_interes
                  AND cat_automatica = v_cat_riesgo
                  AND cod_sit_contable = v_cod_sec_credito
                  AND cod_rubro = v_cod_rubro;

               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + v_mto_ganancia
                WHERE nro_referencia = v_nro_referencia;

               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + v_mto_ganancia
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = i.nro_cuenta;

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, i.nro_cuenta, v_mto_ganancia, 0);
               END IF;

               ------------------------------------------------------------------------------------------------------------------

            EXCEPTION
               WHEN no_data_found THEN

                  IF nvl(v_mto_ganancia, 0) <> 0 THEN

                     SELECT s_nro_referencia.nextval
                       INTO v_nro_referencia
                       FROM dual;

                     INSERT INTO cb_sal_inventarios
                        (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                         residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                         tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                         cat_automatica, cod_sit_contable)
                     VALUES
                        (pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                         i.cod_oficina /*pag_cta.g_ctas.cod_oficina*/, v_cod_sec_contable,
                         v_cod_tip_deudor, v_residente, v_cod_mon_local /*pag_cta.g_ctas.cod_moneda*/,
                         pag_cta.g_ctas.est_batch, v_tip_saldo,
                         v_cod_plazo, v_tip_movimiento, v_tip_interes, v_mto_ganancia, v_cod_rubro,
                         v_nro_referencia, v_tip_renovacion, v_cat_riesgo, v_cod_sec_credito);

                     IF nvl(v_mto_ganancia, 0) <> 0 THEN
                        INSERT INTO cb_sal_inventarios_det
                           (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                        VALUES
                           (v_nro_referencia, i.nro_cuenta, v_mto_ganancia, 0);
                     END IF;
                  END IF;
            END;

      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_SEG_FRA: ' || SQLERRM);
   END;

   PROCEDURE pr_inv_vta_cartera IS
      v_cod_sec_contable ge_clientes.cod_sec_contable%TYPE;
      v_cod_tip_deudor   ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_cat_riesgo       NUMBER;
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_tip_movimiento   VARCHAR2(1);
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes      cb_sal_inventarios.tip_interes%TYPE;
      v_tip_cuenta       cb_sal_inventarios.tip_operacion%TYPE;
      v_tip_renovacion   cb_sal_inventarios.tip_renovacion%TYPE;
      v_cod_sec_credito  pr_cta_prestamos.cod_sec_credito%TYPE;
      v_cod_moneda       ge_cuentas.cod_moneda%type;
      v_cod_transaccion  ge_transacciones.cod_transaccion%type;
      v_cod_modulo       ge_cuentas.cod_modulo%type;
      rg_pcpre           pr_cta_prestamos%rowtype;
      v_cod_modalidad    ge_modalidades.cod_modalidad%type;
      v_est_batch        pr_cta_prestamos.est_batch%type;

    CURSOR c_vta_cartera IS
     select a.fecha, a.cod_persona, a.nom_completo, a.nro_documento,
            a.cli_nomina, a.fec_ult_acreditacion, a.cod_oficina, a.nro_cuenta,
            a.tip_producto, a.nro_tarjeta, a.afinidad, a.cod_per_codeudor,
            a.gestor, a.mto_deuda, a.mto_previsiones, a.dia_atrasos, a.cat_cliente,
            a.tot_riesgo, a.fec_ult_cat_sistema,  a.cat_sistema, a.tot_deu_sistema,
            a.tot_deu_con_sistema, a.tot_deu_cod_sistema, a.tot_cuotas,
            a.tot_cuo_vencidas, a.tel_particular, a.dir_particular, a.tel_laboral,
            a.dir_laboral, a.gar_cliente, a.gar_ven_cliente, a.gar_codeudor,
            a.gar_ven_codeudor, a.tip_bloqueo, a.tip_inhibicion, a.estado,
            a.cod_modulo, a.cod_modalidad, a.mot_exclucion, a.usu_exclucion,
            a.observacion, a.ruc_comprador, a.nom_comprador, a.ref_lote,
            a.hor_cancelacion, a.fec_venta, a.ope_recaptados, a.mot_reingreso,
            a.usu_reingreso, a.obs_reingreso,
            nvl(a.sal_deu_cta_actual,a.mto_deu_mon_cuenta) mto_deu_mon_cuenta -- DYDMR-10819 iguala logica con vista bv_cua_contable
       from ge_sal_inv_vta_cartera_his a
      where a.estado in ('V','C')--DYDMR-9157 - También deben ser consideradas las 'Confirmadas'.-
        and a.ope_recaptados = 'N';

   BEGIN
      v_tip_saldo        := 'X'; --X = Nuevo tip_saldo para Vta. de Cartera.
      v_cod_plazo        := 1;
      v_cod_transaccion  := 8846;
      --------------------------------------------------------------
      -- OBTIENE EL TIPO DE RENOVACION (X = NO IMPORTA)           --
      --------------------------------------------------------------
      v_tip_renovacion := 'X';
      --------------------------------------------------------------
      -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
      --------------------------------------------------------------
      v_tip_interes := 'X';
      --------------------------------------------------------------
      -- OBTIENE EL TIPO DE CUENTA (X = NO IMPORTA)               --
      --------------------------------------------------------------
      v_tip_cuenta := 'X';
      --------------------------------------------------------------
      -- OBTIENE EL SECTOR DEL CREDITO (X = NO IMPORTA)           --
      --------------------------------------------------------------
      v_cod_sec_credito := null;
      --------------------------------------------------------------
      FOR i IN c_vta_cartera LOOP
         IF i.cod_oficina IS NULL THEN
            i.cod_oficina := nvl(fug_obt_ofi_usuario(USER),fug_obt_ofi_matriz);
         END IF;

         v_cod_moneda := fug_obt_mon_cta(i.nro_cuenta);

         BEGIN
           select a.cod_modulo, a.cod_modalidad
             into v_cod_modulo, v_cod_modalidad
             from ge_cuentas a
            where a.nro_cuenta = i.nro_cuenta;
         END;
         IF v_cod_modulo = 6 then
           pap_pre.pr_obt_dat_prestamo(i.nro_cuenta,rg_pcpre);
           v_cod_modalidad := rg_pcpre.cod_modalidad;
           v_est_batch     := rg_pcpre.est_batch;
         ELSIF v_cod_modulo != 15 then
           pag_cta.pr_obt_cuenta(i.nro_cuenta);
           v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
           v_est_batch     := pag_cta.g_ctas.est_batch;
         ELSE
           BEGIN
             select a.est_batch
               into v_est_batch
               from ov_cta_vencidas a
              where a.nro_cuenta = i.nro_cuenta;
           END;
         END IF;

         /*INSERTA INVENTARIO*/
         BEGIN
            SELECT a.cod_sec_contable, a.cod_tip_deudor, a.residente,
                   to_number(nvl(a.cat_riesgo, 1))
              INTO v_cod_sec_contable, v_cod_tip_deudor, v_residente, v_cat_riesgo
              FROM ge_clientes a, ge_cta_clientes b
             WHERE a.cod_persona = b.cod_persona
               AND b.nro_cuenta = i.nro_cuenta
               AND b.relacion = 'P';
         EXCEPTION
            WHEN OTHERS THEN
               v_cod_sec_contable := null;
               v_cod_tip_deudor   := null;
               v_residente        := null;
               v_cat_riesgo       := null;
         END;
         --

         v_tip_movimiento := 'D';
         fu_obt_cod_rubro(v_cod_modulo, v_cod_modalidad,
                          v_cod_transaccion, v_cod_moneda,
                          v_cod_sec_contable, v_cod_tip_deudor, v_residente,
                          to_char(v_cod_plazo), v_tip_movimiento, v_cod_rubro,
                          v_est_batch, v_tip_renovacion, v_cat_riesgo, v_tip_interes,
                          v_tip_cuenta, v_cod_sec_credito);

            BEGIN
               SELECT nro_referencia
                 INTO v_nro_referencia
                 FROM cb_sal_inventarios
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_oficina = i.cod_oficina /*pag_cta.g_ctas.cod_oficina*/
                  AND cod_moneda = v_cod_moneda /*pag_cta.g_ctas.cod_moneda*/
                  AND cod_sec_contable = v_cod_sec_contable
                  AND cod_tip_deudor = v_cod_tip_deudor
                  AND residente = v_residente
                  AND situacion = v_est_batch
                  AND cod_plazo = to_char(v_cod_plazo)
                  AND tip_operacion = v_tip_movimiento
                  AND tip_renovacion = v_tip_renovacion
                  AND tip_interes = v_tip_interes
                  AND cat_automatica = v_cat_riesgo
                  AND cod_sit_contable = v_cod_sec_credito
                  AND cod_rubro = v_cod_rubro;

               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + i.mto_deu_mon_cuenta
                WHERE nro_referencia = v_nro_referencia;

               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + i.mto_deu_mon_cuenta
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = i.nro_cuenta;

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, i.nro_cuenta, i.mto_deu_mon_cuenta, 0);
               END IF;

               ------------------------------------------------------------------------------------------------------------------

            EXCEPTION
               WHEN no_data_found THEN

                  IF nvl(i.mto_deu_mon_cuenta, 0) <> 0 THEN

                     SELECT s_nro_referencia.nextval
                       INTO v_nro_referencia
                       FROM dual;

                     INSERT INTO cb_sal_inventarios
                        (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                         residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                         tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                         cat_automatica, cod_sit_contable)
                     VALUES
                        (v_cod_modulo, v_cod_modalidad,
                         i.cod_oficina, v_cod_sec_contable,
                         v_cod_tip_deudor, v_residente, v_cod_moneda,
                         v_est_batch, v_tip_saldo,
                         v_cod_plazo, v_tip_movimiento, v_tip_interes, i.mto_deu_mon_cuenta, v_cod_rubro,
                         v_nro_referencia, v_tip_renovacion, v_cat_riesgo, v_cod_sec_credito);

                     IF nvl(i.mto_deu_mon_cuenta, 0) <> 0 THEN
                        INSERT INTO cb_sal_inventarios_det
                           (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                        VALUES
                           (v_nro_referencia, i.nro_cuenta, i.mto_deu_mon_cuenta, 0);
                     END IF;
                  END IF;
            END;
           -- Crédito
           v_tip_movimiento := 'C';
           fu_obt_cod_rubro(v_cod_modulo, v_cod_modalidad,
                            v_cod_transaccion, v_cod_moneda,
                            v_cod_sec_contable, v_cod_tip_deudor, v_residente,
                            to_char(v_cod_plazo), v_tip_movimiento, v_cod_rubro,
                            v_est_batch, v_tip_renovacion, v_cat_riesgo, v_tip_interes,
                            v_tip_cuenta, v_cod_sec_credito);

              BEGIN
                 SELECT nro_referencia
                   INTO v_nro_referencia
                   FROM cb_sal_inventarios
                  WHERE cod_modulo = v_cod_modulo
                    AND cod_modalidad = v_cod_modalidad
                    AND cod_oficina = i.cod_oficina
                    AND cod_moneda = v_cod_moneda
                    AND cod_sec_contable = v_cod_sec_contable
                    AND cod_tip_deudor = v_cod_tip_deudor
                    AND residente = v_residente
                    AND situacion = v_est_batch
                    AND cod_plazo = to_char(v_cod_plazo)
                    AND tip_operacion = v_tip_movimiento
                    AND tip_renovacion = v_tip_renovacion
                    AND tip_interes = v_tip_interes
                    AND cat_automatica = v_cat_riesgo
                    AND cod_sit_contable = v_cod_sec_credito
                    AND cod_rubro = v_cod_rubro;

                 UPDATE cb_sal_inventarios
                    SET sal_total = nvl(sal_total, 0) + i.mto_deu_mon_cuenta
                  WHERE nro_referencia = v_nro_referencia;

                 UPDATE cb_sal_inventarios_det
                    SET sal_actual = nvl(sal_actual, 0) + i.mto_deu_mon_cuenta
                  WHERE nro_referencia = v_nro_referencia
                    AND nro_cuenta = i.nro_cuenta;

                 IF SQL%NOTFOUND THEN
                    INSERT INTO cb_sal_inventarios_det
                       (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                    VALUES
                       (v_nro_referencia, i.nro_cuenta, i.mto_deu_mon_cuenta, 0);
                 END IF;

                 ------------------------------------------------------------------------------------------------------------------

              EXCEPTION
                 WHEN no_data_found THEN

                    IF nvl(i.mto_deu_mon_cuenta, 0) <> 0 THEN

                       SELECT s_nro_referencia.nextval
                         INTO v_nro_referencia
                         FROM dual;

                       INSERT INTO cb_sal_inventarios
                          (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                           residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                           tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                           cat_automatica, cod_sit_contable)
                       VALUES
                          (v_cod_modulo, v_cod_modalidad,
                           i.cod_oficina, v_cod_sec_contable,
                           v_cod_tip_deudor, v_residente, v_cod_moneda,
                           v_est_batch, v_tip_saldo,
                           v_cod_plazo, v_tip_movimiento, v_tip_interes, i.mto_deu_mon_cuenta, v_cod_rubro,
                           v_nro_referencia, v_tip_renovacion, v_cat_riesgo, v_cod_sec_credito);

                       IF nvl(i.mto_deu_mon_cuenta, 0) <> 0 THEN
                          INSERT INTO cb_sal_inventarios_det
                             (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                          VALUES
                             (v_nro_referencia, i.nro_cuenta, i.mto_deu_mon_cuenta, 0);
                       END IF;
                    END IF;
              END;
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_INV_VTA_CARTERA: '|| SQLERRM);
   END;
-- Transferencias Recibidas Cuentas de Orden en la 52
   PROCEDURE pr_tra_rec_ord_par IS
      v_cod_oficina     cb_sal_inventarios.cod_oficina%TYPE;
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_refe_tip        VARCHAR2(15);
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento  VARCHAR2(01);
      v_cod_plazo       NUMBER(03);
      v_cod_modulo      cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad   cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_rub         VARCHAR(02);

      ---cursor
      CURSOR orden IS
         SELECT nro_referencia,
                cod_tip_referencia,
                cod_modulo,
                cod_modalidad,
                cod_moneda,
                cod_oficina,
                fec_valor,
                cod_per_beneficiario,
                estado,
                (saldo*-1) saldo,
                l.nom_beneficiario
           FROM lc_transferencias l
          WHERE cod_modalidad = 75
            AND estado = 'PE'
            AND nvl(fec_valor, fec_operacion) > fue_obt_fec_calendar(7)
          ORDER BY cod_moneda;

   BEGIN
      v_cod_plazo       := 1;
      v_tip_saldo       := 'C'; --capital - efectivo.
      v_cod_oficina     := 31;
      v_tip_movimiento  := 'D';
      v_cod_modulo      := 4;
      v_cod_modalidad   := 45;
      v_cod_transaccion := 1503;
      v_cod_rub         := 2;

      FOR i IN orden LOOP
         ----se obtiene el rubro contable que le corresponde
         fu_obt_tra_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, i.cod_moneda, NULL,
                              /*i.cod_sec_contable*/ NULL, /*i.cod_tip_deudor*/ NULL,
                              /*i.residente*/ v_cod_plazo, v_tip_movimiento, v_cod_rubro, NULL,
                              /*i.estado*/ v_cod_rub, NULL, /*v_tip_renovacion*/ NULL,
                              /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL, /*v_tip_operacion*/
                              NULL /*v_cod_sit_contable*/);

         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia;

            v_refe_tip := to_char(i.nro_referencia) || to_char(i.cod_tip_referencia);

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_refe_tip;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_refe_tip, i.saldo, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.saldo, 0) <> 0 THEN

                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, v_cod_oficina, NULL, NULL, NULL, i.cod_moneda,
                      NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, i.saldo, v_cod_rubro,
                      v_nro_referencia, NULL, NULL, NULL);

                  v_refe_tip := to_char(i.nro_referencia) || to_char(i.cod_tip_referencia);
                  IF nvl(i.saldo, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, v_refe_tip, i.saldo, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN PR_TRA_REC_CTA_ORDEN:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Transferencias Recibidas Cuentas de Orden

END PAB_INV;
/
