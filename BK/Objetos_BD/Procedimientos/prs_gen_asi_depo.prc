CREATE OR REPLACE PROCEDURE IT.prs_gen_asi_depo IS

   v_cod_mon_local  ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
   v_fec_actual     ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(1);
   v_fec_anterior   ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_anterior(1);
   r_baade          cb_asi_automaticos_det%ROWTYPE;
   v_error          VARCHAR2(250);
   v_inc_interes    VARCHAR2(3);
   v_dia_plazo      NUMBER;
   v_dia_interes    NUMBER;
   v_tasadiv        NUMBER;
   xx_immovml       NUMBER;
   xx_immovex       NUMBER;
   xx_vltasci       NUMBER;
   v_monto          NUMBER;
   v_rub_debito     cb_rubros.cod_rubro%TYPE;
   v_rub_credito    cb_rubros.cod_rubro%TYPE;
   v_rub_interes    cb_rubros.cod_rubro%TYPE;
   v_mto_interes    cb_asi_automaticos_det.mto_mon_rubro%TYPE;
   v_rub_ganancia   cb_rubros.cod_rubro%TYPE;
   v_nro_linea      NUMBER;
   v_mto_cotizacion ge_cotizaciones.val_conversion%TYPE;
   v_redondeo       NUMBER(5);

   CURSOR depo IS
      SELECT *
        FROM ge_snp_transferencias s
       WHERE s.cod_msj_swift = 541
         AND fec_valor = v_fec_actual 
         AND estado = 'A'
         AND situacion = 'L';
   CURSOR repo IS
      SELECT *
        FROM ge_snp_transferencias ge
       WHERE ge.estado = 'A'
         AND ge.situacion = 'L'
         AND ge.fec_valor = v_fec_anterior
         AND ge.cod_msj_swift = '541';

   /* Insertar asientos automaticos detalles. */
   PROCEDURE lp_ins_asi_aut_det(rp_baade IN cb_asi_automaticos_det%ROWTYPE) IS
   
   BEGIN
      INSERT INTO cb_asi_automaticos_det
         (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_rubro,
          mto_mon_local, descripcion, referencia, protegido, actualizado, val_cotizacion,
          distribuido, ref_movimiento, cod_modulo, cod_modalidad, cod_tra_padre, cod_ofi_origen,
          fec_valor)
      VALUES
         (rp_baade.fecha, rp_baade.cod_oficina, rp_baade.nro_asiento, rp_baade.nro_linea,
          rp_baade.cod_rubro, rp_baade.tip_movimiento, rp_baade.mto_mon_rubro,
          rp_baade.mto_mon_local, rp_baade.descripcion, rp_baade.referencia, rp_baade.protegido,
          rp_baade.actualizado, rp_baade.val_cotizacion, rp_baade.distribuido,
          rp_baade.ref_movimiento, rp_baade.cod_modulo, rp_baade.cod_modalidad,
          rp_baade.cod_tra_padre, rp_baade.cod_ofi_origen, rp_baade.fec_valor);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Ins.Cb_asi_automaticos_det ' || rp_baade.nro_asiento || '-' ||
                                  rp_baade.referencia || '-' || SQLERRM);
   END;
   /* Cabecera Asiento */
   PROCEDURE lp_cab_asiento IS
   
      v_nro_linea       ge_tip_asientos.nro_linea%TYPE;
      v_cod_oficina     ba_oficinas.cod_oficina%TYPE;
      v_cod_modalidad   ge_modalidades.cod_modalidad%TYPE;
      v_cod_modulo      ba_modulos.cod_modulo%TYPE;
      v_cod_gru_asiento cb_gru_asientos.cod_gru_asiento%TYPE;
      ---Reactivar FK
      v_nro_asiento    NUMBER;
      wk_imtotct       NUMBER;
      v_tot_debito     NUMBER;
      v_tot_credito    NUMBER;
      v_tip_movimiento cb_asi_automaticos_det.tip_movimiento%TYPE;
   
      v_msj VARCHAR2(1000);
      CURSOR cur_01 IS
         SELECT DISTINCT d.cod_modulo, d.cod_modalidad, d.cod_oficina, a.cod_gru_asiento
           FROM cb_asi_automaticos_det d, cb_gru_asientos_det a
          WHERE d.fecha = v_fec_actual
            AND d.cod_modulo = a.cod_modulo
            AND d.cod_modalidad = a.cod_modalidad
            AND d.cod_tra_padre = a.cod_transaccion
            AND d.referencia IN ('REPO', 'DEPOX')
         UNION ALL
         SELECT DISTINCT d.cod_modulo, d.cod_modalidad, d.cod_oficina, -1
           FROM cb_asi_automaticos_det d
          WHERE d.fecha = v_fec_actual
            AND d.referencia IN ('REPO', 'DEPOX')
            AND NOT EXISTS (SELECT 1
                   FROM cb_gru_asientos_det a
                  WHERE d.cod_modulo = a.cod_modulo
                    AND d.cod_modalidad = a.cod_modalidad
                    AND d.cod_tra_padre = a.cod_transaccion);
      r_02 cb_asi_automaticos_det%ROWTYPE;
   
      CURSOR cur_02 IS
         SELECT d.*
           FROM cb_asi_automaticos_det d
          WHERE d.cod_oficina = v_cod_oficina
            AND d.fecha = v_fec_actual
            AND d.cod_modulo = v_cod_modulo
            AND d.cod_modalidad = v_cod_modalidad
            AND d.referencia IN ('REPO', 'DEPOX')
            AND ((v_cod_gru_asiento = -1 AND NOT EXISTS
                 (SELECT 1
                     FROM cb_gru_asientos_det a
                    WHERE d.cod_modulo = a.cod_modulo
                      AND d.cod_modalidad = a.cod_modalidad
                      AND d.cod_tra_padre = a.cod_transaccion)) OR EXISTS
                 (SELECT 1
                    FROM cb_gru_asientos_det a
                   WHERE d.cod_modulo = a.cod_modulo
                     AND d.cod_modalidad = a.cod_modalidad
                     AND d.cod_tra_padre = a.cod_transaccion
                     AND a.cod_gru_asiento = v_cod_gru_asiento))
            FOR UPDATE OF nro_asiento, nro_linea;
   BEGIN
      v_msj := 'Generando cabecera de asientos';
      OPEN cur_01;
      LOOP
         FETCH cur_01
            INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_gru_asiento;
         EXIT WHEN cur_01%NOTFOUND;
         ----- lee parametros de contabilidad ------
         v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASI_AUTOM');
         prg_act_par_dinamico('SIG_NRO_ASI_AUTOM', NULL, NULL, NULL, NULL, (v_nro_asiento + 1));
         v_msj := 'Generando cabecera asiento ' || to_char(v_cod_oficina) || '-' ||
                  to_char(v_nro_asiento);
         ----- fin leer parametros
         IF cur_02%ISOPEN THEN
            CLOSE cur_02;
         END IF;
         OPEN cur_02;
         v_nro_linea   := 0;
         wk_imtotct    := 0;
         v_tot_debito  := 0;
         v_tot_credito := 0;
         LOOP
            FETCH cur_02
               INTO r_02;
            EXIT WHEN cur_02%NOTFOUND;
            v_nro_linea := v_nro_linea + 1;
            IF v_nro_linea = 9999 THEN
               v_msj := 'CUIDADO: Se debe agrandar el campo de nro. de linea';
            END IF;
         
            wk_imtotct := wk_imtotct + nvl(r_02.mto_mon_local, 0);
            IF r_02.tip_movimiento = 'D' THEN
               v_tot_debito := nvl(v_tot_debito, 0) + r_02.mto_mon_local;
            ELSE
               v_tot_credito := nvl(v_tot_credito, 0) + r_02.mto_mon_local;
            END IF;
            v_msj := 'Generando ' || to_char(v_nro_asiento) || '-' || to_char(v_nro_linea) || '-' ||
                     to_char(v_cod_oficina) || '-' || to_char(v_nro_asiento);
            UPDATE cb_asi_automaticos_det
               SET nro_asiento = nvl(v_nro_asiento, 999),
                   nro_linea   = nvl(v_nro_linea, 9999)
             WHERE CURRENT OF cur_02;
         END LOOP;
         --- Verificar diferencia por redondeo
         IF v_tot_debito <> v_tot_credito THEN
            --- Verificar si esta parametrizado el redondeo
            IF fug_obt_pardinamico('ASI_REDONDEAR') = 'S' AND
               abs(v_tot_credito - v_tot_debito) <= fug_obt_pardinamico('ASI_MTO_REDONDEO') THEN
               --- Insertar linea de ajuste de la diferencia
               v_nro_linea := v_nro_linea + 1;
               IF v_tot_debito > v_tot_credito THEN
                  v_tip_movimiento  := 'C';
                  r_baade.cod_rubro := fug_obt_pardinamico('ASI_RUB_RED_GAN');
               ELSE
                  v_tip_movimiento  := 'D';
                  r_baade.cod_rubro := fug_obt_pardinamico('ASI_RUB_RED_PER');
               END IF;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := v_cod_oficina;
               r_baade.nro_asiento    := v_nro_asiento;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := 0;
               r_baade.mto_mon_local  := abs(v_tot_credito - v_tot_debito);
               r_baade.descripcion    := 'DIFERENCIA DE CAMBIO';
               r_baade.referencia     := NULL;
               r_baade.protegido      := 'N';
               r_baade.actualizado    := 'N';
               r_baade.val_cotizacion := NULL;
               r_baade.distribuido    := 'N';
               r_baade.ref_movimiento := NULL;
               r_baade.cod_modulo     := v_cod_modulo;
               r_baade.cod_modalidad  := v_cod_modalidad;
               r_baade.cod_ofi_origen := v_cod_oficina;
               r_baade.cod_tra_padre  := NULL;
               r_baade.fec_valor      := v_fec_actual;
               lp_ins_asi_aut_det(r_baade);
               wk_imtotct := wk_imtotct + abs(v_tot_credito - v_tot_debito);
            END IF;
         END IF;
         -----------------------
         -- graba la cabecera --
         -----------------------
         v_cod_oficina := nvl(v_cod_oficina, 0);
         INSERT INTO cb_asi_automaticos
            (cod_oficina, nro_asiento, cod_usuario, fecha, cod_modulo, cod_modalidad, tot_control,
             actualizado, reversado, cod_ofi_origen, ofi_integrada, confirmado, cod_gru_asiento,
             fec_valor)
         VALUES
            (v_cod_oficina, v_nro_asiento, USER, v_fec_actual, v_cod_modulo, v_cod_modalidad,
             wk_imtotct, 'N', 'N', v_cod_oficina, 'N', 'S', v_cod_gru_asiento, v_fec_actual);
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, v_msj || ' ' || SQLERRM);
   END;
BEGIN
   IF nvl(fug_obt_pardinamico('SIB_SNP_UTI_ASIENTO'), 'N') = 'S' THEN
      -- Desactivar el PK de los detalles de asientos
      sql_util.ejecute_dml('alter table CB_ASI_AUTOMATICOS_DET disable constraint PK_CB_ASI_AUTOMATICOS_DET',
                           v_error);
      IF v_error IS NOT NULL THEN
         raise_application_error(-20000, 'Disable PK ' || v_error);
      END IF;
      v_rub_debito   := fug_obt_pardinamico('SIB_SNP_RUB_DEB_DEPO');
      v_rub_credito  := fug_obt_pardinamico('SIB_SNP_RUB_CRE_DEPO');
      v_rub_interes  := fug_obt_pardinamico('SIB_SNP_RUB_INT_DEPO');
      v_rub_ganancia := fug_obt_pardinamico('SIB_SNP_RUB_GAN_DEPO');
      v_inc_interes  := nvl(fug_obt_pardinamico('SIB_SNP_INC_INT_DEPO'), 'N');
      v_redondeo     := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 4, 455, v_cod_mon_local);
      v_nro_linea    := 0;
      xx_immovml     := 0;
      xx_immovex     := 0;
      xx_vltasci     := 0;
      v_dia_plazo    := 0;
      v_tasadiv      := 0;
      v_dia_interes  := 0;
      v_mto_interes  := 0;
      FOR i IN depo LOOP
         -- si el indicador de repo está en N indica que es un asiento para la depo.
         IF i.cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            xx_immovml := i.monto;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(i.cod_moneda, v_fec_actual);
            xx_immovml       := round(i.monto * v_mto_cotizacion, v_redondeo);
            xx_immovex       := i.monto;
            xx_vltasci       := v_mto_cotizacion;
         END IF;
      
         -- DEBITO
         v_nro_linea := v_nro_linea + 1;
         --- Cargar registro de asientos detalles
         r_baade.fecha          := v_fec_actual;
         r_baade.cod_oficina    := i.cod_oficina;
         r_baade.nro_asiento    := 0;
         r_baade.nro_linea      := v_nro_linea;
         r_baade.cod_rubro      := v_rub_debito;
         r_baade.tip_movimiento := 'D';
         r_baade.mto_mon_rubro  := xx_immovex;
         r_baade.mto_mon_local  := xx_immovml;
         r_baade.descripcion    := 'Depositos Operaciones Monetarias';
         r_baade.referencia     := 'DEPOX';
         r_baade.protegido      := 'N';
         r_baade.actualizado    := 'N';
         r_baade.val_cotizacion := xx_vltasci;
         r_baade.distribuido    := 'N';
         r_baade.ref_movimiento := 541;
         r_baade.cod_modulo     := i.cod_modulo;
         r_baade.cod_modalidad  := i.cod_modalidad;
         r_baade.cod_tra_padre  := 4711;
         r_baade.cod_ofi_origen := i.cod_oficina;
         r_baade.fec_valor      := v_fec_actual;
         lp_ins_asi_aut_det(r_baade);
         --CREDITO
         v_nro_linea := v_nro_linea + 1;
         --- Cargar registro de asientos detalles
         r_baade.fecha          := v_fec_actual;
         r_baade.cod_oficina    := i.cod_oficina;
         r_baade.nro_asiento    := 0;
         r_baade.nro_linea      := v_nro_linea;
         r_baade.cod_rubro      := v_rub_credito;
         r_baade.tip_movimiento := 'C';
         r_baade.mto_mon_rubro  := xx_immovex;
         r_baade.mto_mon_local  := xx_immovml;
         r_baade.descripcion    := 'Operaciones Monetarias';
         r_baade.referencia     := 'DEPOX';
         r_baade.protegido      := 'N';
         r_baade.actualizado    := 'N';
         r_baade.val_cotizacion := xx_vltasci;
         r_baade.distribuido    := 'N';
         r_baade.ref_movimiento := 541;
         r_baade.cod_modulo     := i.cod_modulo;
         r_baade.cod_modalidad  := i.cod_modalidad;
         r_baade.cod_tra_padre  := 4711;
         r_baade.cod_ofi_origen := i.cod_oficina;
         r_baade.fec_valor      := v_fec_actual;
         lp_ins_asi_aut_det(r_baade);
         IF v_inc_interes = 'S' THEN
            -- Indicador si debe incluirse el asiento de interés ya en la DEPO.
            v_dia_plazo   := pag_cal.fu_obt_fec_sig_hab(i.fec_valor, 1) - i.fec_valor;
            v_tasadiv     := to_number(i.ref_oid) / (365 * 100);
            v_dia_interes := (i.fec_valor + nvl(v_dia_plazo, 0)) - i.fec_valor;
            v_mto_interes := round((i.monto * v_tasadiv * v_dia_interes), v_redondeo);
            v_nro_linea   := v_nro_linea + 1;
            IF i.cod_moneda = v_cod_mon_local THEN
               -- es moneda nacional --
               xx_immovml := v_mto_interes;
               xx_immovex := 0;
               xx_vltasci := 0;
            ELSE
               -- se obtiene la cotizacion de cierre
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(i.cod_moneda, v_fec_actual);
               xx_immovml       := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
               xx_immovex       := v_mto_interes;
               xx_vltasci       := v_mto_cotizacion;
            END IF;
            v_nro_linea := v_nro_linea + 1;
            --- Cargar registro de asientos detalles
            r_baade.fecha          := v_fec_actual;
            r_baade.cod_oficina    := i.cod_oficina;
            r_baade.nro_asiento    := 0;
            r_baade.nro_linea      := v_nro_linea;
            r_baade.cod_rubro      := v_rub_interes;
            r_baade.tip_movimiento := 'D';
            r_baade.mto_mon_rubro  := xx_immovex;
            r_baade.mto_mon_local  := xx_immovml;
            r_baade.descripcion    := 'Intereses Bancos del Pais';
            r_baade.referencia     := 'DEPOX';
            r_baade.protegido      := 'N';
            r_baade.actualizado    := 'N';
            r_baade.val_cotizacion := xx_vltasci;
            r_baade.distribuido    := 'N';
            r_baade.ref_movimiento := 541;
            r_baade.cod_modulo     := i.cod_modulo;
            r_baade.cod_modalidad  := i.cod_modalidad;
            r_baade.cod_tra_padre  := 4711;
            r_baade.cod_ofi_origen := i.cod_oficina;
            r_baade.fec_valor      := v_fec_actual;
            lp_ins_asi_aut_det(r_baade);
            -- ganancia------------------------------------------------------------
            v_nro_linea := v_nro_linea + 1;
            --- Cargar registro de asientos detalles
            r_baade.fecha          := v_fec_actual;
            r_baade.cod_oficina    := i.cod_oficina;
            r_baade.nro_asiento    := 0;
            r_baade.nro_linea      := v_nro_linea;
            r_baade.cod_rubro      := v_rub_ganancia; --'61'
            r_baade.tip_movimiento := 'C';
            r_baade.mto_mon_rubro  := xx_immovex;
            r_baade.mto_mon_local  := xx_immovml;
            r_baade.descripcion    := 'Intereses Bancos del Pais';
            r_baade.referencia     := 'DEPOX';
            r_baade.protegido      := 'N';
            r_baade.actualizado    := 'N';
            r_baade.val_cotizacion := xx_vltasci;
            r_baade.distribuido    := 'N';
            r_baade.ref_movimiento := 541;
            r_baade.cod_modulo     := i.cod_modulo;
            r_baade.cod_modalidad  := i.cod_modalidad;
            r_baade.cod_tra_padre  := 4711;
            r_baade.cod_ofi_origen := i.cod_oficina;
            r_baade.fec_valor      := v_fec_actual;
            lp_ins_asi_aut_det(r_baade);
         END IF;
      END LOOP;
      -- REPO.
      FOR i IN repo LOOP
         --CANCELACION 
         v_nro_linea := 0;
         IF v_inc_interes = 'S' THEN
            v_dia_plazo   := pag_cal.fu_obt_fec_sig_hab(i.fec_valor, 1) - i.fec_valor;
            v_tasadiv     := to_number(i.ref_oid) / (365 * 100);
            v_dia_interes := (i.fec_valor + nvl(v_dia_plazo, 0)) - i.fec_valor;
            v_mto_interes := round((i.monto * v_tasadiv * v_dia_interes), v_redondeo);           
            v_monto := i.monto + v_mto_interes;
         ELSE
            v_monto := i.monto;
         END IF;
      
         IF i.cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            xx_immovml := v_monto;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(i.cod_moneda, v_fec_actual);
            xx_immovml       := round(v_monto * v_mto_cotizacion, v_redondeo);
            xx_immovex       := v_monto;
            xx_vltasci       := v_mto_cotizacion;
         END IF;
      
         -- DEBITO
         v_nro_linea := v_nro_linea + 1;
         --- Cargar registro de asientos detalles
         r_baade.fecha          := v_fec_actual;
         r_baade.cod_oficina    := i.cod_oficina;
         r_baade.nro_asiento    := 0;
         r_baade.nro_linea      := v_nro_linea;
         r_baade.cod_rubro      := v_rub_credito;
         r_baade.tip_movimiento := 'D';
         r_baade.mto_mon_rubro  := xx_immovex;
         r_baade.mto_mon_local  := xx_immovml;
         r_baade.descripcion    := 'Depositos Operaciones Monetarias';
         r_baade.referencia     := 'REPO';
         r_baade.protegido      := 'N';
         r_baade.actualizado    := 'N';
         r_baade.val_cotizacion := xx_vltasci;
         r_baade.distribuido    := 'N';
         r_baade.ref_movimiento := 541;
         r_baade.cod_modulo     := i.cod_modulo;
         r_baade.cod_modalidad  := i.cod_modalidad;
         r_baade.cod_tra_padre  := 4711;
         r_baade.cod_ofi_origen := i.cod_oficina;
         r_baade.fec_valor      := v_fec_actual;
         lp_ins_asi_aut_det(r_baade);
         IF i.cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            xx_immovml := i.monto;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(i.cod_moneda, v_fec_actual);
            xx_immovml       := round(i.monto * v_mto_cotizacion, v_redondeo);
            xx_immovex       := i.monto;
            xx_vltasci       := v_mto_cotizacion;
         END IF;
         --CREDITO
         v_nro_linea := v_nro_linea + 1;
         --- Cargar registro de asientos detalles
         r_baade.fecha          := v_fec_actual;
         r_baade.cod_oficina    := i.cod_oficina;
         r_baade.nro_asiento    := 0;
         r_baade.nro_linea      := v_nro_linea;
         r_baade.cod_rubro      := v_rub_debito;
         r_baade.tip_movimiento := 'C';
         r_baade.mto_mon_rubro  := xx_immovex;
         r_baade.mto_mon_local  := xx_immovml;
         r_baade.descripcion    := 'Operaciones Monetarias';
         r_baade.referencia     := 'REPO';
         r_baade.protegido      := 'N';
         r_baade.actualizado    := 'N';
         r_baade.val_cotizacion := xx_vltasci;
         r_baade.distribuido    := 'N';
         r_baade.ref_movimiento := 541;
         r_baade.cod_modulo     := i.cod_modulo;
         r_baade.cod_modalidad  := i.cod_modalidad;
         r_baade.cod_tra_padre  := 4711;
         r_baade.cod_ofi_origen := i.cod_oficina;
         r_baade.fec_valor      := v_fec_actual;
         lp_ins_asi_aut_det(r_baade);
         IF i.cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            xx_immovml := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(i.cod_moneda, v_fec_actual);
            xx_immovml       := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
            xx_immovex       := v_mto_interes;
            xx_vltasci       := v_mto_cotizacion;
         END IF;
         v_nro_linea := v_nro_linea + 1;
         IF v_inc_interes = 'N' THEN
            -- Si no se incluyo al momento de la DEPO.
            -- ganancia-- 
            r_baade.fecha          := v_fec_actual;
            r_baade.cod_oficina    := i.cod_oficina;
            r_baade.nro_asiento    := 0;
            r_baade.nro_linea      := v_nro_linea;
            r_baade.cod_rubro      := v_rub_ganancia; --'61'
            r_baade.tip_movimiento := 'C';
            r_baade.mto_mon_rubro  := xx_immovex;
            r_baade.mto_mon_local  := xx_immovml;
            r_baade.descripcion    := 'Intereses Bancos del Pais';
            r_baade.referencia     := 'REPO';
            r_baade.protegido      := 'N';
            r_baade.actualizado    := 'N';
            r_baade.val_cotizacion := xx_vltasci;
            r_baade.distribuido    := 'N';
            r_baade.ref_movimiento := 541;
            r_baade.cod_modulo     := i.cod_modulo;
            r_baade.cod_modalidad  := i.cod_modalidad;
            r_baade.cod_tra_padre  := 4711;
            r_baade.cod_ofi_origen := i.cod_oficina;
            r_baade.fec_valor      := v_fec_actual;
            lp_ins_asi_aut_det(r_baade);
         ELSE
            --- Cargar registro de asientos detalles
            r_baade.fecha          := v_fec_actual;
            r_baade.cod_oficina    := i.cod_oficina;
            r_baade.nro_asiento    := 0;
            r_baade.nro_linea      := v_nro_linea;
            r_baade.cod_rubro      := v_rub_interes;
            r_baade.tip_movimiento := 'C';
            r_baade.mto_mon_rubro  := xx_immovex;
            r_baade.mto_mon_local  := xx_immovml;
            r_baade.descripcion    := 'Intereses Bancos del Pais';
            r_baade.referencia     := 'REPO';
            r_baade.protegido      := 'N';
            r_baade.actualizado    := 'N';
            r_baade.val_cotizacion := xx_vltasci;
            r_baade.distribuido    := 'N';
            r_baade.ref_movimiento := 541;
            r_baade.cod_modulo     := i.cod_modulo;
            r_baade.cod_modalidad  := i.cod_modalidad;
            r_baade.cod_tra_padre  := 4711;
            r_baade.cod_ofi_origen := i.cod_oficina;
            r_baade.fec_valor      := v_fec_actual;
            lp_ins_asi_aut_det(r_baade);
         END IF;
      END LOOP;
      -----------------------------------------------------------
      -- genera la cabecera a partir de los detalles generados --
      -----------------------------------------------------------
      lp_cab_asiento;
   
      ---borrar asientos nro 0---
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
      END;
      DELETE FROM cb_asi_automaticos_det t WHERE t.nro_asiento = 0;
      -- Activar el PK de los detalles de asientos
      sql_util.ejecute_dml('alter table CB_ASI_AUTOMATICOS_DET enable constraint PK_CB_ASI_AUTOMATICOS_DET',
                           v_error);
   
      IF v_error IS NOT NULL THEN
         raise_application_error(-20000, 'Enable PK ' || v_error);
      END IF;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Asientos DEPOX ' || SQLERRM);
END;
/

