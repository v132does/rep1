CREATE OR REPLACE PROCEDURE IT.pra_gen_asientos IS
   v_cod_oficina       ba_oficinas.cod_oficina%TYPE;
   v_cod_mon_local     ba_monedas.cod_moneda%TYPE;
   v_fec_actual        ge_calendarios.fec_actual%TYPE;
   v_ult_dia_mes_habil ge_calendarios.fec_actual%TYPE;
   v_error             VARCHAR2(250);
   v_lugar             VARCHAR2(250);
   r_baade             cb_asi_automaticos_det%ROWTYPE;
   v_hor_inicio      varchar2(8);
   v_hor_fin         varchar2(8);

   /* Intereses Devengado de Mesa de Dinero */
   PROCEDURE lp_int_dev_mesadinero;
   /* Cabecera Asiento */
   PROCEDURE lp_cab_asiento;
   /* Procedimiento Equivalente Moneda Local */
   PROCEDURE lp_equ_mon_local;
   /* Estadistico */
   PROCEDURE lp_estadistico;
   /* Movimientos Diarios */
   PROCEDURE lp_mov_diarios;
   /* Intereses Devengados */
   PROCEDURE lp_int_devengados;
   /* Intereses Devengado de Prestamos */
   PROCEDURE lp_int_dev_prestamos;
   /* Intereses Devengado de Comisiones Diferidas */
   PROCEDURE lp_int_dev_comisiones;
   -- Intereses Devengado Operaciones Futuras
   PROCEDURE lp_dev_ope_futuras;
   /* Insertar asientos automaticos detalles. */
   PROCEDURE lp_ins_asi_aut_det(rp_baade IN cb_asi_automaticos_det%ROWTYPE);
   /* Obtener la moneda del rubro del parametro. */
   PROCEDURE lp_obt_mon_rubro
   (
      p_cod_rubro  IN cb_rubros.cod_moneda%TYPE,
      p_cod_moneda IN OUT cb_rubros.cod_moneda%TYPE,
      p_encontro   IN OUT VARCHAR2
   );

   /* Cabecera Asiento */
   PROCEDURE lp_cab_asiento IS

      v_nro_linea     cb_asi_automaticos_det.nro_linea%TYPE;
      v_cod_oficina   ba_oficinas.cod_oficina%TYPE;
      v_cod_modalidad ge_modalidades.cod_modalidad%TYPE;
      v_cod_modulo    ba_modulos.cod_modulo%TYPE;
      ---Reactivar FK
      v_nro_asiento    NUMBER;
      wk_imtotct       NUMBER;
      v_tot_debito     NUMBER;
      v_tot_credito    NUMBER;
      v_tip_movimiento cb_asi_automaticos_det.tip_movimiento%TYPE;

      v_msj       VARCHAR2(1000);
      v_fec_valor DATE;
      -- Crea el cursor con los diferentes a Activo Fijo; esto es para que no
      -- reenumere los asientos de Activo Fijo.--
      CURSOR cur_01 IS
         SELECT DISTINCT cod_modulo, cod_modalidad, cod_oficina, nvl(fec_valor, fecha) fec_valor
           FROM cb_asi_automaticos_det
          WHERE fecha = v_fec_actual;
      r_02 cb_asi_automaticos_det%ROWTYPE;

      CURSOR cur_02 IS
         SELECT *
           FROM cb_asi_automaticos_det
          WHERE cod_modulo = v_cod_modulo
            AND cod_modalidad = v_cod_modalidad
            AND cod_oficina = v_cod_oficina
            AND fecha = v_fec_actual
            AND (fec_valor = v_fec_valor OR fec_valor IS NULL)
            FOR UPDATE OF nro_asiento, nro_linea;
   BEGIN
      v_msj := 'Generando cabecera de asientos';
      OPEN cur_01;
      LOOP
         FETCH cur_01
            INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_fec_valor;
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
            IF v_nro_linea = 999999 THEN
               v_msj := 'CUIDADO: Se debe agrandar el campo de nro. de linea';
            END IF;
            v_nro_linea := v_nro_linea + 1;

            wk_imtotct := wk_imtotct + nvl(r_02.mto_mon_local, 0);
            IF r_02.tip_movimiento = 'D' THEN
               v_tot_debito := nvl(v_tot_debito, 0) + r_02.mto_mon_local;
            ELSE
               v_tot_credito := nvl(v_tot_credito, 0) + r_02.mto_mon_local;
            END IF;
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
                  r_baade.cod_rubro := fug_obt_pardinamico('ASI_RUB_RED_GAN'); -- Tipo C= Ganancia; Tipo D= Perdida. CB 21/11/2013 DYDMR-11
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
               r_baade.fec_valor      := v_fec_valor;
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
             actualizado, reversado, cod_ofi_origen, ofi_integrada, confirmado, fec_valor)
         VALUES
            (v_cod_oficina, v_nro_asiento, USER, v_fec_actual, v_cod_modulo, v_cod_modalidad,
             wk_imtotct, 'N', 'N', v_cod_oficina, 'N', 'S', v_fec_valor);
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, v_msj || ' ' || SQLERRM);
   END;
   /* Procedimiento Equivalente Moneda Local */
   PROCEDURE lp_equ_mon_local IS

      v_mto_cotizacion ge_cotizaciones.val_conversion%TYPE;
      v_cod_moneda     ba_monedas.cod_moneda%TYPE;
      v_cod_modulo     ba_modulos.cod_modulo%TYPE;
      v_cod_modalidad  ge_modalidades.cod_modalidad%TYPE;
      v_redondeo       NUMBER(5);
      v_msj            VARCHAR2(200);
      CURSOR c_movimientos IS
         SELECT DISTINCT cod_moneda, cod_modulo, cod_modalidad
           FROM ge_movimientos
          WHERE cod_rubro IS NOT NULL
            AND cod_moneda <> v_cod_mon_local
               --and usu_insercion <> 'IT' -- para evitar interface
            AND mto_equ_local IS NULL;
   BEGIN
      v_msj := ' Equivalente en moneda local ';

      OPEN c_movimientos;
      LOOP
         FETCH c_movimientos
            INTO v_cod_moneda, v_cod_modulo, v_cod_modalidad;
         EXIT WHEN c_movimientos%NOTFOUND;
         v_msj := ' MONEDA : ' || v_cod_moneda;

         ---------------------------------------------------------
         -----      LEER COTIZACION
         ---------------------------------------------------------
         v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
         ----------------------------------------------------------
         -------- ACTUALIZA GE_MOVIMIENTOS CON EL IMPORTE EQUIVALENTE GS.
         ----------------------------------------------------------
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         UPDATE ge_movimientos
            SET mto_equ_local = round(nvl(monto, 0) * v_mto_cotizacion, v_redondeo)
          WHERE cod_moneda = v_cod_moneda
            AND mto_equ_local IS NULL;
      END LOOP;
      IF c_movimientos%ISOPEN THEN
         CLOSE c_movimientos;
      END IF;
   END;
   /* Estadistico */
   PROCEDURE lp_estadistico IS

      v_cod_mon_rubro    cb_rubros.cod_moneda%TYPE;
      v_nro_linea        ge_tip_asientos.nro_linea%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_nro_referencia   ge_con_transacciones.nro_referencia%TYPE;
      v_cod_plazo        ge_con_transacciones.cod_plazo%TYPE;
      v_cod_tip_deudor   ge_con_transacciones.cod_tip_deudor%TYPE;
      v_cod_sector       ge_con_transacciones.cod_sector%TYPE;
      v_residente        ge_con_transacciones.residente%TYPE;
      v_cod_mad_padre    ge_con_transacciones.cod_mad_padre%TYPE;
      v_cod_mod_padre    ge_con_transacciones.cod_mod_padre%TYPE;
      v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
      v_cod_modalidad    ge_con_transacciones.cod_modalidad%TYPE;
      v_cod_modulo       ge_con_transacciones.cod_modulo%TYPE;
      v_cod_ofi_origen   ge_con_transacciones.cod_ofi_origen%TYPE;
      v_cod_oficina      ge_con_transacciones.cod_oficina%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_moneda       ge_con_transacciones.cod_moneda%TYPE;
      v_cod_tip_asiento  ge_transacciones.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_transacciones.cod_tip_asiento2%TYPE;
      v_tot_mon_local    ge_con_transacciones.tot_mon_local%TYPE;
      v_total            ge_con_transacciones.total%TYPE;
      xx_immovml         NUMBER(18, 2);
      xx_immovex         NUMBER(18, 2);
      xx_vltasci         NUMBER(16, 2);
      v_mensaje          varchar2(200);

      wk_lgofici       CHAR(1); --Indica si se tiene que hacer un asiento interoficina
      v_tip_movimiento ge_tip_asientos.tip_movimiento%TYPE;
      x_tip_movimiento ge_tip_asientos.tip_movimiento%TYPE;
      ----
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    ge_con_transacciones.cod_oficina%TYPE;
      vh_cod_ofi_origen ge_con_transacciones.cod_ofi_origen%TYPE;
      vh_nro_asiento    NUMBER;
      vh_cod_rubro      cb_rubros.cod_rubro%TYPE;
      wh_immovml        NUMBER;
      wh_dcrefer        CHAR(11);
      wh_dcdescr        CHAR(60);
      wh_lgprote        CHAR(1);
      wh_lgdeact        CHAR(1);
      wh_lgctadi        CHAR(1);
      ----
      wk_cdctaco CHAR(15);
      v_encontro CHAR(1);
      --
      v_sigue    CHAR(1);
      ww_nrcuent CHAR(15);
      v_msj      VARCHAR2(250);
      ---
      v_est_cuenta       ge_con_transacciones.est_cuenta%TYPE;
      v_tip_cuenta       ge_con_transacciones.tip_cuenta%TYPE;
      v_tip_interes      ge_con_transacciones.tip_interes%TYPE;
      v_tip_renovacion   ge_con_transacciones.tip_renovacion%TYPE;
      v_cat_automatica   ge_con_transacciones.cat_automatica%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_redondeo         NUMBER(5);
      v_fec_valor        DATE;
      v_cod_sit_contable ge_con_transacciones.cod_sit_contable%TYPE;
      v_nro_cuenta       ge_con_transacciones.nro_cuenta%TYPE;
      v_concepto         ge_con_transacciones.concepto%TYPE;
      v_cod_sec_rubro    ge_con_transacciones.cod_sec_rubro%TYPE;
      v_registro         VARCHAR2(200);
      v_val_reg_exc_gen_asientos ge_par_dinamicos.val_parametro%type;

      CURSOR c_transacciones IS
         SELECT ct.cod_moneda,
                ct.total,
                t.cod_tip_asiento,
                t.descripcion,
                ct.cod_oficina,
                ct.cod_ofi_origen,
                ct.cod_modulo,
                ct.cod_modalidad,
                ct.cod_transaccion,
                ct.cod_mod_padre,
                ct.cod_mad_padre,
                ct.residente,
                ct.cod_sector,
                ct.cod_tip_deudor,
                ct.cod_plazo,
                ct.tot_mon_local,
                ct.est_cuenta,
                ct.tip_cuenta,
                ct.tip_interes,
                ct.tip_renovacion,
                ct.cat_automatica,
                ct.nro_referencia,
                mo.cod_pro_contable,
                t.cod_tip_asiento2,
                ct.fecha fec_valor,
                ct.cod_sit_contable,
                ct.nro_cuenta,
                ct.concepto,
                ct.cod_sec_rubro,
                ct.rowid registro
           FROM ge_transacciones t, ge_con_transacciones ct, ge_modalidades mo
          WHERE fecha = v_fec_actual
            AND t.tipo IN ('D', 'C')
            AND t.cod_modulo = ct.cod_modulo
            AND t.cod_modalidad = ct.cod_modalidad
            AND t.cod_transaccion = ct.cod_transaccion
            AND t.cod_tip_asiento IS NOT NULL
            AND t.batch = 'B'
            AND t.cod_modulo = mo.cod_modulo
            AND t.cod_modalidad = mo.cod_modalidad
            /* 28/05/2015 DYDMR-1901 EN caso de que se necesite excluir algun registro, se debe agregar
            el parámetro dinámico REG_EXC_GEN_ASIENTOS donde val_parametro = ct.rowid, estos deben ir entre comas(,).
            Al final del proceso se elimina automáticamente el parámetro dinámico creado en caso de que exista*/
            AND not exists (select 1
                              from ge_par_dinamicos x
                             where x.parametro = 'REG_EXC_GEN_ASIENTOS'
                               and instr(x.val_parametro,','||ct.rowid||',') > 0);
      ---------------------------------------------------------------------
      r_tp ge_tip_asientos%ROWTYPE;
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sector OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X')
            AND (est_cuenta = v_est_cuenta OR nvl(est_cuenta, 'X') = 'X')
            AND (tip_cuenta = v_tip_cuenta OR nvl(tip_cuenta, 'X') = 'X')
            AND (tip_interes = v_tip_interes OR nvl(tip_interes, 'X') = 'X')
            AND (tip_renovacion = v_tip_renovacion OR nvl(tip_renovacion, 'X') = 'X')
            AND (cat_automatica = v_cat_automatica OR nvl(cat_automatica, -1) = -1)
            AND (cod_sit_contable IS NULL OR cod_sit_contable = v_cod_sit_contable)

          ORDER BY nro_linea;
   BEGIN
      v_msj := '--- Estadistico ---';
      OPEN c_transacciones;
      LOOP
         --- para cada registro de estadistico ---
         FETCH c_transacciones
            INTO v_cod_moneda,
                 v_total,
                 v_cod_tip_asiento,
                 v_des_transaccion,
                 v_cod_oficina,
                 v_cod_ofi_origen,
                 v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_transaccion,
                 v_cod_mod_padre,
                 v_cod_mad_padre,
                 v_residente,
                 v_cod_sector,
                 v_cod_tip_deudor,
                 v_cod_plazo,
                 v_tot_mon_local,
                 v_est_cuenta,
                 v_tip_cuenta,
                 v_tip_interes,
                 v_tip_renovacion,
                 v_cat_automatica,
                 v_nro_referencia,
                 v_cod_pro_contable,
                 v_cod_tip_asiento2,
                 v_fec_valor,
                 v_cod_sit_contable,
                 v_nro_cuenta,
                 v_concepto,
                 v_cod_sec_rubro,
                 v_registro;

         EXIT WHEN c_transacciones%NOTFOUND;
         v_mensaje := 'Tran: '||to_char(v_cod_modulo)||'-'||to_char(v_cod_modalidad)||'-'||to_char(v_cod_transaccion)||'- Cta: '||v_nro_cuenta||'- Mon: '||v_cod_moneda||'- Mto: '|| rtrim(ltrim(to_char(v_total,'999,999,999,999.99')));

         --v_cod_mon_local es inicializado en pra_gen_asientos
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         IF v_cod_moneda = v_cod_mon_local THEN
            ---- ES MONEDA NACIONAL --
            ------------------------
            xx_immovml := round(v_total, v_redondeo);
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            -- ES MONEDA EXTRANJERA --
            --------------------------
            IF v_tot_mon_local IS NULL THEN
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
               xx_immovml       := round(v_total * v_mto_cotizacion, v_redondeo);
               xx_vltasci       := v_mto_cotizacion;
            ELSE
               xx_immovml := v_tot_mon_local;
               xx_vltasci := NULL;
            END IF;
            xx_immovex := v_total;
         END IF;
         wk_lgofici := 'N';
         ----------------------------------------
         IF v_cod_oficina <> v_cod_ofi_origen THEN
            -- ES ASIENTO INTEROFICINA
            wk_lgofici := 'S';
         END IF;
         ------- ciclo para GE_TIP_ASIENTOS (tipos de asientos relacionados a
         -------                     la transaccion leida)
         ------------------------------------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         v_sigue     := 'N';
         LOOP
            -- para cada registro de GE_TIP_ASIENTOS
            FETCH c_tip_asientos
               INTO r_tp;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            -------------------------------------------------
            IF v_sigue = 'S' THEN
               -- ya hubo otra linea interoficina
               IF (v_tip_movimiento <> r_tp.tip_movimiento AND r_tp.nro_linea = 1 AND
                  xx_immovml > 0) OR (v_tip_movimiento = r_tp.tip_movimiento AND r_tp.nro_linea = 1 AND
                  xx_immovml <= 0) THEN
                  v_sigue := 'N'; -- se apaga para que no genere interoficina
               END IF;
            ELSE
               IF wk_lgofici = 'S' AND r_tp.nro_linea = 1 THEN
                  v_tip_movimiento := r_tp.tip_movimiento;
                  x_tip_movimiento := r_tp.tip_movimiento; -- para el interoficina
                  v_sigue          := 'S'; /* se hara interoficina */
               END IF;
            END IF;
            v_encontro := 'S';
            ---Reemplaza el tipo de deudor -----------------------
            IF r_tp.ind_deudor = 'S' THEN
               ww_nrcuent := substr(r_tp.cod_rubro, 1, 8) || ltrim(to_char(v_cod_tip_deudor, '00')) ||
                             substr(r_tp.cod_rubro, 11, 5);
            ELSE
               ww_nrcuent := r_tp.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo-----------------------
            IF r_tp.ind_plazo = 'S' THEN
               ww_nrcuent := substr(ww_nrcuent, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                             substr(ww_nrcuent, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_tp.ind_producto = 'S' THEN
               ww_nrcuent := substr(ww_nrcuent, 1, 10) || ltrim(to_char(v_cod_pro_contable, '000')) ||
                             substr(r_tp.cod_rubro, 14, 2);
            END IF;
            IF substr(r_tp.cod_rubro, 11, 3) = 'SEC' THEN
               -- es solo para prestamos, para contabilizar por sector
              if nvl(v_cod_sec_rubro,'N') = 'N' then
                v_cod_sec_rubro := '000';
              end if;
              ww_nrcuent := substr(ww_nrcuent, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                             substr(r_tp.cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            --- Lee Plan de ctas. consolidado p/tomar la moneda
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(ww_nrcuent, v_cod_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Rubro no existe -Plan Ctas.Consol' || ww_nrcuent;
               --vh_cod_rubro := '999999999999999';
               IF substr(vh_cod_rubro, 14, 2) IN ('99', '98') THEN
                  v_cod_mon_rubro := v_cod_mon_local;
               END IF;
               --v_cod_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_cod_mon_rubro = v_cod_mon_local THEN
               --- ES MONEDA LOCAL
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            IF r_tp.nro_linea = 1 THEN
               vh_cod_oficina := v_cod_oficina;
            ELSE
               vh_cod_oficina := v_cod_ofi_origen;
            END IF;
            vh_nro_asiento := 0;
            vh_cod_rubro   := ww_nrcuent;
            IF xx_immovml > 0 THEN
               wh_immovml       := xx_immovml;
               v_tip_movimiento := r_tp.tip_movimiento;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_tp.tip_movimiento = 'D' THEN
                  v_tip_movimiento := 'C';
               ELSE
                  v_tip_movimiento := 'D';
               END IF;
            END IF;
            wh_dcrefer := NULL;
            IF v_cod_transaccion BETWEEN 150 AND 171 THEN
               wh_dcrefer := 'VALUAC';
            END IF;
            wh_lgprote := 'N';
            wh_lgdeact := 'N';
            wh_lgctadi := 'N'; ---r_tp.at_lgctadi;
            IF substr(v_concepto, 1, 1) = '/' THEN
               wh_dcdescr := substr(v_concepto, 1, 60);
            ELSIF v_nro_cuenta IS NOT NULL THEN
               wh_dcdescr := substr('Cli:' || fug_obt_cli_principal(v_nro_cuenta) || ' Cta:' ||
                                    v_nro_cuenta || ' ' || v_concepto, 1, 60);
            ELSIF v_concepto IS NOT NULL THEN
               wh_dcdescr := substr(v_concepto, 1, 60);

            ELSE

               wh_dcdescr := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                    to_char(v_cod_transaccion) || ' ' || v_des_transaccion, 1, 60);
            END IF;
            --------------------------------------------------
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := vh_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := 'N';
               r_baade.actualizado    := 'N';
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := v_nro_referencia;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               r_baade.fec_valor      := v_fec_valor;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP;
         ---------------------------
         IF wk_lgofici = 'S' AND v_sigue = 'S' THEN
            -- tomo el tipo de movimiento de la linea 1
            v_tip_movimiento := x_tip_movimiento;
            -- Recuperar cuenta contable interoficina
            vh_cod_rubro   := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL, v_cod_moneda,
                                                  v_cod_oficina);
            vh_cod_oficina := v_cod_oficina; -- oficina de la cuenta
            /*vh_cod_rubro   := substr(vh_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_ofi_origen, '000')) ||
                              substr(vh_cod_rubro, 14, 2);*/
            --- ve moneda de la cuenta --
            v_encontro := 'S';
            lp_obt_mon_rubro(vh_cod_rubro, v_cod_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Rubro Inexistente-Plan de Ctas.Consol' || vh_cod_rubro;
               --vh_cod_rubro := '999999999999999';
               IF substr(vh_cod_rubro, 14, 2) IN ('99', '98') THEN
                  v_cod_mon_rubro := v_cod_mon_local;
               END IF;
               --v_cod_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_cod_mon_rubro = v_cod_mon_local THEN
               -- moneda local
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -------------------------------------------------------------
            --- VER SI EL TIPO DE MOVIMIENTO ES DE DEBITO O CREDITO
            ------------------------------------------------------------
            IF v_tip_movimiento = 'D' THEN
               v_tip_movimiento := 'C';
            ELSE
               v_tip_movimiento := 'D';
            END IF;
            wh_dcdescr := substr(TRIM(wh_dcdescr) || '(Inter of)', 1, 60);
            /*
            wh_dcdescr := substr(to_char(v_cod_modulo) || ' ' ||
                          to_char(v_cod_modalidad) || ' ' ||
                          to_char(v_cod_transaccion) || ' ' ||
                          '(Inter of)'        || ' ' ||
                          v_des_transaccion,1,60);
            */
            wh_lgprote := 'N';
            wh_lgdeact := 'N';
            wh_lgctadi := 'N'; ---- r_tp.at_lgctadi;
            IF xx_immovml > 0 THEN
               wh_immovml := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF v_tip_movimiento = 'D' THEN
                  v_tip_movimiento := 'C';
               ELSE
                  v_tip_movimiento := 'D';
               END IF;
            END IF;
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := vh_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := 'N';
               r_baade.actualizado    := 'N';
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := v_nro_referencia;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               r_baade.fec_valor      := v_fec_valor;
               lp_ins_asi_aut_det(r_baade);
            END IF;
            -- Recuperar cuenta contable interoficina
            vh_cod_rubro   := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL, v_cod_moneda,
                                                  v_cod_oficina);
            vh_cod_oficina := v_cod_ofi_origen; -- oficina origen
            /*vh_cod_rubro   := substr(vh_cod_rubro, 1, 10) || ltrim(to_char(v_cod_oficina, '000')) ||
                              substr(vh_cod_rubro, 14, 2);*/

            vh_nro_asiento := 0;
            --- ve moneda de la cuenta --
            v_encontro := 'S';
            lp_obt_mon_rubro(vh_cod_rubro, v_cod_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'RUBRO INEXISTENTE EN PLAN DE CUENTAS ' || vh_cod_rubro;
               IF substr(vh_cod_rubro, 14, 2) IN ('99', '98') THEN
                  v_cod_mon_rubro := v_cod_mon_local;
               END IF;
               --vh_cod_rubro := '999999999999999';
               --v_cod_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_cod_mon_rubro = v_cod_mon_local THEN
               -- moneda local
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            v_tip_movimiento := x_tip_movimiento;
            IF xx_immovml > 0 THEN
               wh_immovml := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF v_tip_movimiento = 'D' THEN
                  v_tip_movimiento := 'C';
               ELSE
                  v_tip_movimiento := 'D';
               END IF;
            END IF;
            /*         wh_dcdescr := substr(to_char(v_cod_modulo) || ' ' ||
            to_char(v_cod_modalidad) || ' ' ||
            to_char(v_cod_transaccion) || ' ' ||
            '(Inter of)'        || ' ' ||
            v_des_transaccion,1,60);*/
            IF v_encontro = 'N' THEN
               wh_dcdescr := 'RUBRO INEXISTENTE ' || vh_cod_rubro;
               --vh_cod_rubro := '999999999999999';
            END IF;
            wh_lgprote := 'N';
            wh_lgdeact := 'N';
            wh_lgctadi := 'N'; ----r_tp.at_lgctadi;
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := vh_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := 'N';
               r_baade.actualizado    := 'N';
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := v_nro_referencia;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               r_baade.fec_valor      := v_fec_valor;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END IF;
         ---------------- FIN INTEROFICINA ------------------
      END LOOP;
      IF c_transacciones%ROWCOUNT = 0 THEN
         raise_application_error(-20000,
                                 'No se encontro registro en GE_CON_TRANSACCIONES-GE_TRANSACCIONES');
      END IF;
      --Agregar validacion para eliminar el parametro si fue cargado--
      v_val_reg_exc_gen_asientos := null;
      v_val_reg_exc_gen_asientos := fug_obt_pardinamico('REG_EXC_GEN_ASIENTOS');
      if v_val_reg_exc_gen_asientos is not null then
         delete from ge_par_dinamicos x
          where x.parametro = 'REG_EXC_GEN_ASIENTOS';
      end if;
   EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20002,'Error en el identificador rowid: '|| v_registro||'- '||v_mensaje||'. '|| sqlerrm);
   END;
   /* Movimientos Diarios */
   PROCEDURE lp_mov_diarios IS

      /* Moneda de la Cuenta Contable */
      v_cod_mon_rubro  cb_rubros.cod_moneda%TYPE;
      v_encontro       VARCHAR2(1) := 'N';
      v_fila           VARCHAR2(20);
      v_nro_documento4 ge_movimientos.nro_documento4%TYPE;
      v_nro_documento3 ge_movimientos.nro_documento3%TYPE;
      v_nro_documento2 ge_movimientos.nro_documento2%TYPE;
      v_cod_ref_cambio ge_movimientos.cod_ref_cambio%TYPE;
      v_cod_usuario    ge_movimientos.cod_usuario%TYPE;
      v_concepto       ge_movimientos.concepto%TYPE;
      v_cod_mad_padre  ge_movimientos.cod_mad_padre%TYPE;
      v_cod_mod_padre  ge_movimientos.cod_mod_padre%TYPE;
      v_mto_equ_local  ge_movimientos.mto_equ_local%TYPE;
      v_monto          ge_movimientos.monto%TYPE;
      v_tip_mov_rubro  ge_movimientos.tip_mov_rubro%TYPE;
      v_cod_oficina    ge_movimientos.cod_oficina%TYPE;
      v_cod_ofi_origen ge_movimientos.cod_ofi_origen%TYPE;
      v_cod_rubro      ge_movimientos.cod_rubro%TYPE;
      v_cod_modalidad  ge_movimientos.cod_modalidad%TYPE;
      v_cod_modulo     ge_movimientos.cod_modulo%TYPE;
      ---
      vh_tip_mov_rubro ge_movimientos.tip_mov_rubro%TYPE;
      vh_cod_rubro     cb_rubros.cod_rubro%TYPE;
      wh_dcrefer       CHAR(11);
      wh_dcdescr       CHAR(60);
      vh_nro_asiento   NUMBER;
      wh_lgprote       CHAR(1);
      wh_lgdeact       CHAR(1);
      wh_lgctadi       CHAR(1);
      ---
      wh_immovml        NUMBER;
      xx_immovml        NUMBER;
      wh_immovex        NUMBER;
      xx_immovex        NUMBER;
      wh_vltasci        NUMBER;
      xx_vltasci        NUMBER;
      vh_cod_oficina    ge_movimientos.cod_oficina%TYPE;
      vh_cod_ofi_origen ge_movimientos.cod_ofi_origen%TYPE;
      vh_cod_modulo     ge_movimientos.cod_modulo%TYPE;
      vh_cod_modalidad  ge_movimientos.cod_modalidad%TYPE;
      v_fecha           ge_movimientos.fecha%TYPE;
      wk_cdctaco        cb_rubros.cod_rubro%TYPE;
      wk_lgofici        CHAR(1);
      wk_sgnrref        NUMBER(7);
      v_msj             VARCHAR2(200);
      v_nro_linea       NUMBER;
      v_hora            ge_movimientos.hora%TYPE;
      v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE;
      v_cotizacion      ge_movimientos.cotizacion%TYPE;
      v_fec_valor       DATE;

      --Declaracion del  Cursor
      CURSOR c_movimientos IS
         SELECT cod_modulo,
                cod_modalidad,
                cod_oficina,
                cod_rubro,
                fecha,
                tip_mov_rubro,
                nvl(monto, 0),
                nvl(mto_equ_local, 0),
                cod_ofi_origen,
                cod_mod_padre,
                cod_mad_padre,
                substr(concepto, 1, 35),
                cod_usuario,
                cod_ref_cambio,
                nro_documento2,
                nro_documento3,
                nro_documento4,
                hora,
                nro_secuencia,
                ROWID,
                cotizacion,
                fecha fec_valor
           FROM ge_movimientos
          WHERE cod_rubro IS NOT NULL
               --AND usu_insercion <> 'IT' -- para evitar interface
            AND estado IN ('N', 'H') --original
         /*AND (REVERSADO = 'N' OR
         (REVERSADO = 'S' AND FECHA <> FEC_VALOR))*/
          ORDER BY cod_modulo,
                   cod_modalidad,
                   cod_oficina,
                   cod_rubro,
                   tip_mov_rubro,
                   cod_ofi_origen,
                   cod_mod_padre,
                   cod_mad_padre;
   BEGIN
      --- Leo el sgte. nro. de referencia del GE_PAR_DINAMICOS -- Es el mismo que utiliza act. de saldos de ahorros
      wk_sgnrref  := fug_obt_pardinamico('SIG_NRO_REFERENCIA');
      v_msj       := ' Movimientos c_movimientos ';
      v_nro_linea := 0;
      -----------
      OPEN c_movimientos;
      LOOP
         FETCH c_movimientos
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_rubro,
                 v_fecha,
                 v_tip_mov_rubro,
                 v_monto,
                 v_mto_equ_local,
                 v_cod_ofi_origen,
                 v_cod_mod_padre,
                 v_cod_mad_padre,
                 v_concepto,
                 v_cod_usuario,
                 v_cod_ref_cambio,
                 v_nro_documento2,
                 v_nro_documento3,
                 v_nro_documento4,
                 v_hora,
                 v_nro_secuencia,
                 v_fila,
                 v_cotizacion,
                 v_fec_valor;
         EXIT WHEN c_movimientos%NOTFOUND;
         v_encontro := 'S';
         lp_obt_mon_rubro(v_cod_rubro, v_cod_mon_rubro, v_encontro);
         IF v_encontro = 'N' THEN
            --vh_cod_rubro := '999999999999';
            v_cod_mon_rubro := v_cod_mon_local;
         END IF;
         IF v_cod_mon_rubro = v_cod_mon_local THEN
            xx_immovml := v_monto;
            xx_immovex := 0;
            xx_vltasci := NULL;
            wh_immovml := v_monto;
            wh_immovex := 0;
            wh_vltasci := 0;
         ELSE
            xx_immovml := v_mto_equ_local;
            xx_immovex := v_monto;
            xx_vltasci := v_cotizacion;
            wh_immovml := v_mto_equ_local;
            wh_immovex := v_monto;
            wh_vltasci := v_cotizacion;
         END IF;
         wk_lgofici := 'N';
         IF v_cod_oficina <> v_cod_ofi_origen THEN
            wk_lgofici := 'S';
         END IF;
         IF xx_immovml > 0 THEN
            wh_immovml       := xx_immovml;
            vh_tip_mov_rubro := v_tip_mov_rubro;
         ELSE
            wh_immovml := xx_immovml * -1;
            wh_immovex := wh_immovex * -1;
            IF v_tip_mov_rubro = 'D' THEN
               vh_tip_mov_rubro := 'C';
            ELSE
               vh_tip_mov_rubro := 'D';
            END IF;
         END IF;
         vh_cod_oficina   := v_cod_oficina;
         vh_cod_modulo    := v_cod_modulo;
         vh_cod_modalidad := v_cod_modalidad;
         vh_cod_rubro     := v_cod_rubro;
         IF v_concepto IS NULL THEN
            wh_dcdescr := substr(fub_obt_referencia(v_fila), 1, 60);
         ELSE
            wh_dcdescr := substr(nvl(fub_obt_referencia(v_fila), v_concepto), 1, 60);
         END IF;
         IF v_cod_mod_padre = 7 THEN
            wh_dcrefer := substr(rtrim(v_cod_ref_cambio) || '/' || ltrim(to_char(v_nro_documento2)),
                                 1, 11);
         ELSE
            wh_dcrefer := v_cod_usuario;
         END IF;
         IF v_cod_mod_padre IN (7, 9) THEN
            IF v_nro_documento3 IS NOT NULL THEN
               wh_dcdescr := substr(ltrim(to_char(v_nro_documento3, '999999999999999')) || ' ' ||
                                    wh_dcdescr, 1, 60);
            ELSE
               wh_dcdescr := substr(wh_dcdescr, 1, 60);
            END IF;
         END IF;
         wh_lgprote := 'N';
         wh_lgdeact := 'N';
         wh_lgctadi := 'N';
         IF wh_immovml <> 0 THEN
            v_nro_linea := v_nro_linea + 1;
            --- Cargar registro de asientos detalles
            r_baade.fecha          := v_fecha;
            r_baade.cod_oficina    := vh_cod_oficina;
            r_baade.nro_asiento    := 0;
            r_baade.nro_linea      := v_nro_linea;
            r_baade.cod_rubro      := vh_cod_rubro;
            r_baade.tip_movimiento := vh_tip_mov_rubro;
            r_baade.mto_mon_rubro  := wh_immovex;
            r_baade.mto_mon_local  := wh_immovml;
            r_baade.descripcion    := wh_dcdescr;
            r_baade.referencia     := wh_dcrefer;
            r_baade.protegido      := wh_lgprote;
            r_baade.actualizado    := wh_lgdeact;
            r_baade.val_cotizacion := wh_vltasci;
            r_baade.distribuido    := wh_lgctadi;
            r_baade.ref_movimiento := nvl(v_nro_documento4, wk_sgnrref);
            r_baade.cod_modulo     := v_cod_mod_padre;
            r_baade.cod_modalidad  := v_cod_mad_padre;
            r_baade.cod_ofi_origen := v_cod_ofi_origen;
            r_baade.fec_valor      := v_fec_valor;
            lp_ins_asi_aut_det(r_baade);
         END IF;
         ------------------ INTEROFICINA --------------------
         ---------------------------
         IF wk_lgofici = 'S' THEN
            -- Recuperar cuenta contable interoficina
            wk_cdctaco     := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,
                                                  v_cod_mon_rubro, v_cod_oficina);
            vh_cod_oficina := v_cod_oficina;
            /*wk_cdctaco     := substr(wk_cdctaco, 1, 10) || ltrim(to_char(v_cod_ofi_origen, '000')) ||
                              substr(wk_cdctaco, 14, 2);*/

            vh_nro_asiento := 0;
            vh_cod_rubro   := wk_cdctaco;
            --- ve moneda de la cuenta --
            v_encontro := 'S';
            lp_obt_mon_rubro(vh_cod_rubro, v_cod_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'RUBRO INEXISTENTE EN PLAN DE CUENTAS ' || vh_cod_rubro;
               --vh_cod_rubro := '999999999999';
               IF substr(vh_cod_rubro, 14, 2) IN ('99', '98') THEN
                  v_cod_mon_rubro := v_cod_mon_local;
               END IF;
            END IF;
            IF v_cod_mon_rubro = v_cod_mon_local THEN
               -- moneda local
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            IF v_tip_mov_rubro = 'D' THEN
               vh_tip_mov_rubro := 'C';
            ELSE
               vh_tip_mov_rubro := 'D';
            END IF;
            /*         wh_dcdescr := substr(to_char(v_cod_modulo) || ' ' ||
            to_char(v_cod_modalidad) || ' ' ||
            ' (Inter of) '||v_concepto,1,60);*/
            wh_dcdescr := substr(TRIM(wh_dcdescr) || '(Inter of)', 1, 60);
            wh_lgprote := 'N';
            wh_lgdeact := 'N';
            IF xx_immovml > 0 THEN
               wh_immovml := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF vh_tip_mov_rubro = 'D' THEN
                  vh_tip_mov_rubro := 'C';
               ELSE
                  vh_tip_mov_rubro := 'D';
               END IF;
            END IF;
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fecha;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := vh_cod_rubro;
               r_baade.tip_movimiento := vh_tip_mov_rubro;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := 'N';
               r_baade.actualizado    := wh_lgctadi;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := 'N';
               r_baade.ref_movimiento := nvl(v_nro_documento4, wk_sgnrref);
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               r_baade.fec_valor      := v_fec_valor;
               lp_ins_asi_aut_det(r_baade);
            END IF;
            -----------------------
            -- Recuperar cuenta contable interoficina para oficina origen
            wk_cdctaco     := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,
                                                  v_cod_mon_rubro, v_cod_ofi_origen);
            vh_cod_oficina := v_cod_ofi_origen;
            /*vh_cod_rubro   := substr(wk_cdctaco, 1, 10) || ltrim(to_char(v_cod_oficina, '000')) ||
                              substr(wk_cdctaco, 14, 2);*/
            vh_cod_rubro   := wk_cdctaco;

            --- ve moneda de la cuenta --
            v_encontro := 'S';
            lp_obt_mon_rubro(vh_cod_rubro, v_cod_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'RUBRO INEXISTENTE EN PLAN DE CUENTAS ' || vh_cod_rubro;
               --vh_cod_rubro := '999999999999';
               IF substr(vh_cod_rubro, 14, 2) IN ('99', '98') THEN
                  v_cod_mon_rubro := v_cod_mon_local;
               END IF;
            END IF;
            IF v_cod_mon_rubro = v_cod_mon_local THEN
               -- moneda local
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            --wh_dcdescr := to_char(vh_cod_modulo) || ' ' ||
            --              to_char(vh_cod_modalidad) || ' ' ||
            --              ' (Inter of)';
            IF v_encontro = 'N' THEN
               wh_dcdescr := 'RUBRO INEXISTENTE ' || vh_cod_rubro;
               --vh_cod_rubro := '999999999999';
            END IF;
            wh_lgprote := 'N';
            wh_lgdeact := 'N';
            IF xx_immovml > 0 THEN
               wh_immovml       := xx_immovml;
               vh_tip_mov_rubro := v_tip_mov_rubro;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF v_tip_mov_rubro = 'D' THEN
                  vh_tip_mov_rubro := 'C';
               ELSE
                  vh_tip_mov_rubro := 'D';
               END IF;
            END IF;
            IF wh_immovml <> 0 THEN
               BEGIN
                  v_nro_linea := v_nro_linea + 1;
                  --- Cargar registro de asientos detalles
                  r_baade.fecha          := v_fecha;
                  r_baade.cod_oficina    := vh_cod_oficina;
                  r_baade.nro_asiento    := 0;
                  r_baade.nro_linea      := v_nro_linea;
                  r_baade.cod_rubro      := vh_cod_rubro;
                  r_baade.tip_movimiento := vh_tip_mov_rubro;
                  r_baade.mto_mon_rubro  := wh_immovex;
                  r_baade.mto_mon_local  := wh_immovml;
                  r_baade.descripcion    := wh_dcdescr;
                  r_baade.referencia     := wh_dcrefer;
                  r_baade.protegido      := 'N';
                  r_baade.actualizado    := wh_lgctadi;
                  r_baade.val_cotizacion := wh_vltasci;
                  r_baade.distribuido    := 'N';
                  r_baade.ref_movimiento := nvl(v_nro_documento4, wk_sgnrref);
                  r_baade.cod_modulo     := v_cod_mod_padre;
                  r_baade.cod_modalidad  := v_cod_mad_padre;
                  r_baade.cod_ofi_origen := v_cod_ofi_origen;
                  r_baade.fec_valor      := v_fec_valor;
                  lp_ins_asi_aut_det(r_baade);
               EXCEPTION
                  WHEN OTHERS THEN
                     raise_application_error(-20001,
                                             'Error LP_MOV_DIARIOS, Nro.Linea ' || v_nro_linea || ' ' ||
                                              SQLERRM);
               END;
            END IF;
         END IF;
         ---------------- FIN INTEROFICINA ------------------
         IF v_nro_documento4 IS NULL THEN
            UPDATE ge_movimientos SET nro_documento4 = wk_sgnrref WHERE ROWID = v_fila;
         ---DESOPIMI-21 - Optimización del proceso PRA_GEN_ASIENTOS - GENERACION DE ASIENTOS - DYD-SDSL-3368
         ---Se excluye actualización de movimientos históricos, se modifica el orden de ejecución del proceso
         ---PRG_TRA_HISTORICO a ejecutarse luego de la generación del Asientos (PRA_GEN_ASIENTOS)

            /*IF v_cod_modulo = 3 THEN
               UPDATE ah_movimientos_his
                  SET nro_documento4 = wk_sgnrref
                WHERE cod_usuario = v_cod_usuario
                  AND fecha = v_fecha
                  AND hora = v_hora
                  AND nro_secuencia = v_nro_secuencia;
            ELSIF v_cod_modulo = 4 THEN
               UPDATE cc_movimientos_his
                  SET nro_documento4 = wk_sgnrref
                WHERE cod_usuario = v_cod_usuario
                  AND fecha = v_fecha
                  AND hora = v_hora
                  AND nro_secuencia = v_nro_secuencia;
            ELSIF v_cod_modulo = 5 THEN
               UPDATE ta_movimientos_his
                  SET nro_documento4 = wk_sgnrref
                WHERE cod_usuario = v_cod_usuario
                  AND fecha = v_fecha
                  AND hora = v_hora
                  AND nro_secuencia = v_nro_secuencia;
            ELSIF v_cod_modulo = 6 THEN
               UPDATE pr_movimientos_his
                  SET nro_documento4 = wk_sgnrref
                WHERE cod_usuario = v_cod_usuario
                  AND fecha = v_fecha
                  AND hora = v_hora
                  AND nro_secuencia = v_nro_secuencia;
            ELSIF v_cod_modulo = 7 THEN
               UPDATE lc_movimientos_his
                  SET nro_documento4 = wk_sgnrref
                WHERE cod_usuario = v_cod_usuario
                  AND fecha = v_fecha
                  AND hora = v_hora
                  AND nro_secuencia = v_nro_secuencia;
            ELSIF v_cod_modulo = 8 THEN
               UPDATE cx_movimientos_his
                  SET nro_documento4 = wk_sgnrref
                WHERE cod_usuario = v_cod_usuario
                  AND fecha = v_fecha
                  AND hora = v_hora
                  AND nro_secuencia = v_nro_secuencia;
               \*      Elsif v_cod_modulo = 9 then
               UPDATE GE_MOVIMIENTOS_HIS
                  SET NRO_DOCUMENTO4 = wk_sgnrref
                WHERE COD_USUARIO = v_cod_usuario
                  and FECHA = v_fecha
                  and HORA = v_hora
                  and NRO_SECUENCIA = v_nro_secuencia;*\
            ELSIF v_cod_modulo = 10 THEN
               UPDATE md_movimientos_his
                  SET nro_documento4 = wk_sgnrref
                WHERE cod_usuario = v_cod_usuario
                  AND fecha = v_fecha
                  AND hora = v_hora
                  AND nro_secuencia = v_nro_secuencia;
            ELSIF v_cod_modulo = 13 THEN
               UPDATE af_movimientos_his
                  SET nro_documento4 = wk_sgnrref
                WHERE cod_usuario = v_cod_usuario
                  AND fecha = v_fecha
                  AND hora = v_hora
                  AND nro_secuencia = v_nro_secuencia;
            ELSIF v_cod_modulo = 14 THEN
               UPDATE rh_movimientos_his
                  SET nro_documento4 = wk_sgnrref
                WHERE cod_usuario = v_cod_usuario
                  AND fecha = v_fecha
                  AND hora = v_hora
                  AND nro_secuencia = v_nro_secuencia;
            ELSIF nvl(v_cod_modulo, 15) IN (15, 16, 28) THEN
               UPDATE ov_movimientos_his
                  SET nro_documento4 = wk_sgnrref
                WHERE cod_usuario = v_cod_usuario
                  AND fecha = v_fecha
                  AND hora = v_hora
                  AND nro_secuencia = v_nro_secuencia;
            ELSIF v_cod_modulo = 26 THEN
               UPDATE bu_movimientos_his
                  SET nro_documento4 = wk_sgnrref
                WHERE cod_usuario = v_cod_usuario
                  AND fecha = v_fecha
                  AND hora = v_hora
                  AND nro_secuencia = v_nro_secuencia;
            END IF;*/
            wk_sgnrref := nvl(wk_sgnrref, 0) + 1;
         END IF;
      END LOOP;
      ---- actualizo el GE_PAR_GENERALES ----------------------------------
      --- Actualizo sgte. nro. de referencia
      prg_act_par_dinamico('SIG_NRO_REFERENCIA', NULL, NULL, NULL, NULL, wk_sgnrref);
   END;
   /* Intereses Devengados */
   PROCEDURE lp_int_devengados IS

      v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro        cb_rubros.cod_moneda%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
      v_cod_ofi_origen   ba_oficinas.cod_oficina%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_mto_interes      ah_devengados.mto_interes%TYPE;
      v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
      v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
      v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      xx_immovml         NUMBER;
      xx_immovex         NUMBER;
      xx_vltasci         NUMBER;
      --
      vh_nro_asiento    NUMBER;
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    ah_cta_vistas.cod_oficina%TYPE;
      vh_cod_ofi_origen ah_cta_vistas.cod_oficina%TYPE;
      vh_cod_modulo     ah_cta_vistas.cod_modulo%TYPE;
      vh_cod_modalidad  ah_cta_vistas.cod_modalidad%TYPE;

      wh_immovml NUMBER;
      wh_dcrefer CHAR(11);
      wh_lgprote CHAR(1);
      wh_lgdeact CHAR(1);
      wh_lgctadi CHAR(1);
      wh_dcdescr CHAR(60);
      --
      v_nro_linea ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro cb_rubros.cod_rubro%TYPE; --wh_cdcuent
      v_encontro  CHAR(1);
      v_msj       VARCHAR2(250);
      --
      wk_plazoav NUMBER(02) := 1; -- esto se definio solo p/select de A.V.
      --
      CURSOR cur3 IS
         SELECT cv.cod_modulo,
                cv.cod_modalidad,
                cv.cod_oficina,
                cv.cod_moneda,
                SUM(nvl(d.mto_interes, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                wk_plazoav,
                nvl(mo.cod_pro_contable, 0) cod_pro_contable
           FROM ah_cta_vistas   cv,
                ge_clientes     c,
                ah_devengados   d,
                ge_cta_clientes cc,
                ge_modalidades  mo
          WHERE fecha = v_fec_actual
            AND d.nro_cuenta = cv.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND cv.cod_modulo = mo.cod_modulo
            AND cv.cod_modalidad = mo.cod_modalidad
          GROUP BY cv.cod_modulo,
                   cv.cod_modalidad,
                   cv.cod_oficina,
                   cv.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   9,
                   nvl(mo.cod_pro_contable, 0)
         UNION
         SELECT cp.cod_modulo,
                cp.cod_modalidad,
                cp.cod_oficina,
                cp.cod_moneda,
                SUM(nvl(d.mto_interes, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0)
           FROM ge_plz_contables pc,
                ah_devengados    d,
                ah_cta_plazos    cp,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo
          WHERE fecha = v_fec_actual
            AND d.nro_cuenta = cp.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND cc.relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND cp.cod_modulo = mo.cod_modulo
            AND cp.cod_modalidad = mo.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (cp.fec_vencimiento - cp.fec_apertura))
          GROUP BY cp.cod_modulo,
                   cp.cod_modalidad,
                   cp.cod_oficina,
                   cp.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0)
         UNION
         SELECT ct.cod_modulo,
                ct.cod_modalidad,
                ct.cod_oficina,
                ct.cod_moneda,
                SUM(nvl(d.mto_interes, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0)
           FROM ge_plz_contables    pc,
                ah_devengados       d,
                ah_cta_certificados ct,
                ge_clientes         c,
                ge_cta_clientes     cc,
                ge_modalidades      mo
          WHERE d.fecha = v_fec_actual
            AND d.nro_cuenta = ct.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND mo.cod_modulo = ct.cod_modulo
            AND mo.cod_modalidad = ct.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (ct.fec_vencimiento - ct.fec_apertura))
          GROUP BY ct.cod_modulo,
                   ct.cod_modalidad,
                   ct.cod_oficina,
                   ct.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0);
      --
      v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
      r_gtasi            ge_tip_asientos%ROWTYPE;
      v_redondeo         NUMBER(5);
      --
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X');
   BEGIN
      v_msj := ' Intereses devengados ';
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_tip_deudor,
                 v_cod_plazo,
                 v_cod_pro_contable;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = 901
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'NO TIENE ASIENTO RELAC.P/DEVENG ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad));
            WHEN OTHERS THEN
               /*EXHIBIR_ERROR;
               RAISE FORM_TRIGGER_FAILURE;*/
               raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);

         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovml := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            /*if fug_obt_tip_implementacion = 1 then
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cot_venta(v_cod_moneda, v_fec_actual);
            else*/
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --end if;
            xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(901) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := NULL;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
      END LOOP; -- fin del ciclo de intereses devengados --
   END;
   -- Insteres Devengado de Prestamos
   PROCEDURE lp_int_dev_prestamos IS
      v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro        cb_rubros.cod_moneda%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
      v_cod_ofi_origen   ba_oficinas.cod_oficina%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_mto_interes      ah_devengados.mto_interes%TYPE;
      v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
      v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
      v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_est_cuenta       ge_tip_asientos.est_cuenta%TYPE;
      v_tip_cuenta       ge_tip_asientos.tip_cuenta%TYPE;
      v_tip_interes      ge_tip_asientos.tip_interes%TYPE;
      v_tip_renovacion   ge_tip_asientos.tip_renovacion%TYPE;
      v_cat_automatica   ge_tip_asientos.cat_automatica%TYPE;
      xx_immovml         NUMBER;
      xx_immovex         NUMBER;
      xx_vltasci         NUMBER;
      --
      vh_nro_asiento    NUMBER;
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_ofi_origen pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_modulo     pr_cta_prestamos.cod_modulo%TYPE;
      vh_cod_modalidad  pr_cta_prestamos.cod_modalidad%TYPE;

      wh_immovml NUMBER;
      wh_dcrefer VARCHAR2(11);
      wh_lgprote VARCHAR2(1);
      wh_lgdeact VARCHAR2(1);
      wh_lgctadi VARCHAR2(1);
      wh_dcdescr VARCHAR2(60);
      --
      v_nro_linea ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro cb_rubros.cod_rubro%TYPE; --wh_cdcuent
      v_encontro  VARCHAR2(1);
      v_msj       VARCHAR2(250);
      --
      v_cod_sec_rubro ge_con_transacciones.cod_sec_rubro%TYPE;
      --BSEVOCORE-627 NAF 2021/06
      xx_afd_immovml     NUMBER;
      xx_afd_immovex     NUMBER;
      xx_afd_vltasci     NUMBER;
      v_cod_ori_fondo pr_cta_prestamos.cod_ori_fondo%TYPE;
      v_por_ori_fondo pr_cta_prestamos.por_ori_fondo%TYPE;
      v_par_afd_cod_ori_fondo varchar2(500) := trim(fug_obt_pardinamico('COD_ORI_FON_AFD_ASIENTOS'));

      CURSOR cur3 IS
         SELECT ct.cod_modulo,
                ct.cod_modalidad,
                ct.cod_oficina,
                ct.cod_moneda,
                SUM(nvl(d.mto_dev_actual, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0),
                d.categoria,
                ct.tipo,
                ct.tip_interes,
                nvl(ct.tip_renovacion, 'A') tip_renovacion,
                d.estado,
                fup_obt_sec_rubro(ct.cod_sec_credito),
                ct.cod_ori_fondo,
                ct.por_ori_fondo
           FROM ge_plz_contables pc,
                pr_devengados    d,
                pr_cta_prestamos ct,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo
          WHERE d.fecha = v_fec_actual
            AND d.nro_cuenta = ct.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND mo.cod_modulo = ct.cod_modulo
            AND mo.cod_modalidad = ct.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (ct.fec_vencimiento - ct.fec_inicio))
          GROUP BY ct.cod_modulo,
                   ct.cod_modalidad,
                   ct.cod_oficina,
                   ct.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   d.categoria,
                   ct.tipo,
                   ct.tip_interes,
                   nvl(ct.tip_renovacion, 'A'),
                   d.estado,
                   fup_obt_sec_rubro(ct.cod_sec_credito),
                   ct.cod_ori_fondo,
                   ct.por_ori_fondo;
      --
      v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
      r_gtasi            ge_tip_asientos%ROWTYPE;
      v_redondeo         NUMBER(5);
      --
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X')
            AND (est_cuenta = v_est_cuenta OR nvl(est_cuenta, 'X') = 'X')
            AND (tip_cuenta = v_tip_cuenta OR nvl(tip_cuenta, 'X') = 'X')
            AND (tip_interes = v_tip_interes OR nvl(tip_interes, 'X') = 'X')
            AND (tip_renovacion = v_tip_renovacion OR nvl(tip_renovacion, 'X') = 'X')
            AND (cat_automatica = v_cat_automatica OR nvl(cat_automatica, -1) = -1);
   BEGIN
      v_msj := ' Intereses devengados ';
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_tip_deudor,
                 v_cod_plazo,
                 v_cod_pro_contable,
                 v_cat_automatica,
                 v_tip_cuenta,
                 v_tip_interes,
                 v_tip_renovacion,
                 v_est_cuenta,
                 v_cod_sec_rubro,
                 v_cod_ori_fondo,
                 v_por_ori_fondo;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento por el CREDITO
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = 901
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad) ||
                                        '-901 no tiene asiento de Credito definido.');
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);
               END IF;
         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovml := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            /*if fug_obt_tip_implementacion = 1 then
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cot_venta(v_cod_moneda, v_fec_actual);
            else*/
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --end if;
            xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;
         --- si es AFD calcula el % de Interes correspondiente
         IF instr(',' || v_par_afd_cod_ori_fondo || ',', ',' || v_cod_ori_fondo || ',') > 0 THEN
            --el % de v_por_ori_fondo corresponde a AFD
            xx_afd_immovml := round(xx_immovml * v_por_ori_fondo / 100, 0);
            xx_immovml := xx_immovml - xx_afd_immovml;
            if xx_immovex > 0 then
               xx_afd_immovex := round(xx_immovml * v_por_ori_fondo / 100, v_redondeo);
               xx_immovex := xx_immovex - xx_afd_immovex;
            else
               xx_afd_immovex := 0;
            end if;
            xx_afd_vltasci := xx_vltasci;
         ELSE
           xx_afd_immovml := 0;
           xx_afd_immovex := 0;
           xx_afd_vltasci := 0;
         END IF;
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            --Reemplaza el código del sector de crédito
            IF substr(r_gtasi.cod_rubro, 11, 3) = 'SEC' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                              substr(r_gtasi.cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(901) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := NULL;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
         --- si es AFD ve el tipo de asiento por el CREDITO
         IF instr(',' || v_par_afd_cod_ori_fondo || ',', ',' || v_cod_ori_fondo || ',') > 0 THEN
           BEGIN
              SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
                INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
                FROM ge_transacciones
               WHERE cod_modulo = v_cod_modulo
                 AND cod_modalidad = v_cod_modalidad
                 AND cod_transaccion = 991
                 AND cod_tip_asiento IS NOT NULL;
           EXCEPTION
              WHEN no_data_found THEN
                 raise_application_error(-20000,
                                         'Transaccion AFD ' || to_char(v_cod_modulo) || '-' ||
                                          to_char(v_cod_modalidad) ||
                                          '-991 no tiene asiento de Credito definido.');
              WHEN OTHERS THEN
                 IF SQLCODE <= -20000 THEN
                    RAISE;
                 ELSE
                    raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);
                 END IF;
           END;
           ------------------
           ----- ciclo para GE_TIP_ASIENTOS AFD------
           -------------------------------
           IF c_tip_asientos%ISOPEN THEN
              CLOSE c_tip_asientos;
           END IF;
           OPEN c_tip_asientos;
           v_nro_linea := 0;
           LOOP
              FETCH c_tip_asientos
                 INTO r_gtasi;
              EXIT WHEN c_tip_asientos%NOTFOUND;
              ---Reemplaza el valor del tipo de deudor, si importa-
              IF r_gtasi.ind_deudor = 'S' THEN
                 v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                                substr(r_gtasi.cod_rubro, 11, 5);
              ELSE
                 v_cod_rubro := r_gtasi.cod_rubro;
              END IF;
              ---Reemplaza el codigo del plazo si es necesario -----
              IF r_gtasi.ind_plazo = 'S' THEN
                 v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                                substr(v_cod_rubro, 4, 12);
              END IF;
              ---Reemplaza el codigo del producto -----------------------
              IF r_gtasi.ind_producto = 'S' THEN
                 v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                                ltrim(to_char(v_cod_pro_contable, '000')) ||
                                substr(v_cod_rubro, 14, 2);
              END IF;
              --Reemplaza el código del sector de crédito
              IF substr(r_gtasi.cod_rubro, 11, 3) = 'SEC' THEN
                 v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                                substr(r_gtasi.cod_rubro, 14, 2);
              END IF;
              ------------------------------------------------------
              v_encontro := 'S';
              lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
              IF v_encontro = 'N' THEN
                 v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
                 --v_cod_rubro  := '999999999999999';
                 v_mon_rubro := v_cod_mon_local;
              END IF;
              IF v_mon_rubro = v_cod_mon_local THEN
                 -- moneda local --
                 wh_immovex := 0;
                 wh_vltasci := 0;
              ELSE
                 wh_immovex := xx_afd_immovex;
                 wh_vltasci := xx_afd_vltasci;
              END IF;
              -- ve el tipo de movimiento --
              ------------------------------
              v_tip_movimiento := r_gtasi.tip_movimiento;
              IF xx_afd_immovml > 0 THEN
                 v_tip_movimiento := r_gtasi.tip_movimiento;
                 wh_immovml       := xx_afd_immovml;
              ELSE
                 wh_immovml := xx_afd_immovml * -1;
                 wh_immovex := wh_immovex * -1;
                 IF r_gtasi.tip_movimiento = 'C' THEN
                    v_tip_movimiento := 'D';
                 ELSE
                    v_tip_movimiento := 'C';
                 END IF;
              END IF;
              ------------------------------------------------------
              wh_dcrefer        := 'DEVENG.';
              wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                          to_char(991) || ' ' || v_des_transaccion, 1, 60);
              vh_cod_oficina    := v_cod_oficina;
              vh_cod_modulo     := v_cod_modulo;
              vh_cod_modalidad  := v_cod_modalidad;
              vh_cod_ofi_origen := v_cod_oficina;
              wh_lgprote        := 'N';
              wh_lgdeact        := 'N';
              wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
              vh_nro_asiento    := 0;
              v_cod_mod_padre   := v_cod_modulo;
              v_cod_mad_padre   := v_cod_modalidad;
              -----
              IF wh_immovml <> 0 THEN
                 v_nro_linea := v_nro_linea + 1;
                 --- Cargar registro de asientos detalles
                 r_baade.fecha          := v_fec_actual;
                 r_baade.cod_oficina    := vh_cod_oficina;
                 r_baade.nro_asiento    := 0;
                 r_baade.nro_linea      := v_nro_linea;
                 r_baade.cod_rubro      := v_cod_rubro;
                 r_baade.tip_movimiento := v_tip_movimiento;
                 r_baade.mto_mon_rubro  := wh_immovex;
                 r_baade.mto_mon_local  := wh_immovml;
                 r_baade.descripcion    := wh_dcdescr;
                 r_baade.referencia     := wh_dcrefer;
                 r_baade.protegido      := wh_lgprote;
                 r_baade.actualizado    := wh_lgdeact;
                 r_baade.val_cotizacion := wh_vltasci;
                 r_baade.distribuido    := wh_lgctadi;
                 r_baade.ref_movimiento := NULL;
                 r_baade.cod_modulo     := v_cod_mod_padre;
                 r_baade.cod_modalidad  := v_cod_mad_padre;
                 r_baade.cod_ofi_origen := v_cod_ofi_origen;
                 lp_ins_asi_aut_det(r_baade);
              END IF;
           END LOOP; -- fin de tipo de asientos AFD--
         END IF;
         --- ve el tipo de asiento por el DEBITO
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = 903
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad) ||
                                        '-903 no tiene asiento de Debito definido.');
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20002, 'Error lp_int_devengados ' || SQLERRM);
               END IF;
         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovml := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            /*if fug_obt_tip_implementacion = 1 then
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cot_venta(v_cod_moneda, v_fec_actual);
            else*/
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --end if;
            xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            --Reemplaza el código del sector de crédito
            IF substr(r_gtasi.cod_rubro, 11, 3) = 'SEC' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                              substr(r_gtasi.cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(903) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.ref_movimiento := NULL;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
      END LOOP; -- fin del ciclo de intereses devengados --
   END;
   -- Insteres Devengado de Comisiones Diferidas
   PROCEDURE lp_int_dev_comisiones IS
      v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro        cb_rubros.cod_moneda%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
      v_cod_ofi_origen   ba_oficinas.cod_oficina%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_mto_interes      ah_devengados.mto_interes%TYPE;
      v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
      v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
      v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      xx_immovml         NUMBER;
      xx_immovex         NUMBER;
      xx_vltasci         NUMBER;
      --
      vh_nro_asiento    NUMBER;
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    ah_cta_vistas.cod_oficina%TYPE;
      vh_cod_ofi_origen ah_cta_vistas.cod_oficina%TYPE;
      vh_cod_modulo     ah_cta_vistas.cod_modulo%TYPE;
      vh_cod_modalidad  ah_cta_vistas.cod_modalidad%TYPE;

      wh_immovml NUMBER;
      wh_dcrefer CHAR(11);
      wh_lgprote CHAR(1);
      wh_lgdeact CHAR(1);
      wh_lgctadi CHAR(1);
      wh_dcdescr CHAR(60);
      --
      v_nro_linea ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro cb_rubros.cod_rubro%TYPE; --wh_cdcuent
      v_encontro  CHAR(1);
      v_msj       VARCHAR2(250);
      --
      CURSOR cur3 IS
         SELECT md.cod_modulo,
                md.cod_modalidad,
                md.cod_oficina,
                md.cod_moneda, --v_cod_mon_local,
                SUM(md.mto_dev_actual),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0) cod_pro_contable,
                md.cod_transaccion
           FROM ge_mov_diferidos md,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo,
                ge_plz_contables pc
          WHERE md.fec_ult_proceso = v_fec_actual
            AND md.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND md.cod_modulo = mo.cod_modulo
            AND md.cod_modalidad = mo.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (md.fec_vencimiento - md.fec_inicio))
          GROUP BY md.cod_modulo,
                   md.cod_modalidad,
                   md.cod_oficina,
                   md.cod_moneda, --v_cod_mon_local,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   md.cod_transaccion
         UNION
         SELECT md.cod_modulo,
                md.cod_modalidad,
                md.cod_oficina,
                md.cod_moneda, --v_cod_mon_local,
                (SUM(md.mto_dev_anterior) * -1),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0) cod_pro_contable,
                md.cod_transaccion
           FROM ge_mov_diferidos md,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo,
                ge_plz_contables pc
          WHERE md.fec_ult_proceso = v_fec_actual
            AND md.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND md.estado = 'C'
            AND c.cod_persona = cc.cod_persona
            AND md.cod_modulo = mo.cod_modulo
            AND md.cod_modalidad = mo.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (md.fec_vencimiento - md.fec_inicio))
          GROUP BY md.cod_modulo,
                   md.cod_modalidad,
                   md.cod_oficina,
                   md.cod_moneda, --v_cod_mon_local,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   md.cod_transaccion;
      --
      v_cod_tip_asiento ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      r_gtasi           ge_tip_asientos%ROWTYPE;
      v_redondeo        NUMBER(5);
      --
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento = v_cod_tip_asiento
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X');
   BEGIN
      v_msj := ' Comisiones Diferidas ';
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_tip_deudor,
                 v_cod_plazo,
                 v_cod_pro_contable,
                 v_cod_transaccion;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento
         BEGIN
            SELECT cod_tip_asi_resultado, descripcion
              INTO v_cod_tip_asiento, v_des_transaccion
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = v_cod_transaccion
               AND cod_tip_asi_resultado IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'NO TIENE ASIENTO RELAC.P/DEVENG COMISION ' ||
                                        to_char(v_cod_modulo) || '-' || to_char(v_cod_modalidad) || '-' ||
                                        to_char(v_cod_transaccion));
            WHEN OTHERS THEN
               /*EXHIBIR_ERROR;
               RAISE FORM_TRIGGER_FAILURE;*/
               raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);

         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         --IF v_cod_moneda =  v_cod_mon_local THEN
         -- Comisiones diferidas siempre --
         -- es moneda nacional --
         ------------------------
         xx_immovml := v_mto_interes;
         xx_immovex := 0;
         xx_vltasci := 0;
         --ELSE
         /*-- se obtiene la cotizacion de cierre
         v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
         xx_immovml := round(v_mto_interes * v_mto_cotizacion,v_redondeo);
         xx_immovex := v_mto_interes;
         xx_vltasci := v_mto_cotizacion;*/
         /*raise_application_error(-20000,'ASIENTOS DEV. COMISONES SOLO DEBEN SER EN MONEDA LOCAL '
                ||TO_CHAR(v_cod_modulo)||'-'||TO_CHAR(v_cod_modalidad)||'-'||TO_CHAR(v_cod_transaccion));
         END IF;*/
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(v_cod_transaccion) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := NULL;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
      END LOOP; -- fin del ciclo de intereses devengados --
      -- Actualiza estado de cuentas canceladas reversadas
      UPDATE ge_mov_diferidos
         SET estado = 'N'
       WHERE estado = 'C'
         AND fec_ult_proceso = v_fec_actual;
      ---
   END;
   -- Insteres Devengado de Mesa de Dinero
   PROCEDURE lp_int_dev_mesadinero IS
      v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro        cb_rubros.cod_moneda%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
      v_cod_ofi_origen   ba_oficinas.cod_oficina%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_mto_interes      ah_devengados.mto_interes%TYPE;
      v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
      v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
      v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
      v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_est_cuenta       ge_tip_asientos.est_cuenta%TYPE;
      v_tip_cuenta       ge_tip_asientos.tip_cuenta%TYPE;
      v_tip_interes      ge_tip_asientos.tip_interes%TYPE;
      v_tip_renovacion   ge_tip_asientos.tip_renovacion%TYPE;
      v_cat_automatica   ge_tip_asientos.cat_automatica%TYPE;
      xx_immovgs         NUMBER;
      xx_immovex         NUMBER;
      xx_vltasci         NUMBER;
      --
      vh_nro_asiento    NUMBER;
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_ofi_origen pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_modulo     pr_cta_prestamos.cod_modulo%TYPE;
      vh_cod_modalidad  pr_cta_prestamos.cod_modalidad%TYPE;

      wh_immovgs NUMBER;
      wh_dcrefer VARCHAR2(11);
      wh_lgprote VARCHAR2(1);
      wh_lgdeact VARCHAR2(1);
      wh_lgctadi VARCHAR2(1);
      wh_dcdescr VARCHAR2(60);
      --
      v_nro_linea        ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro        cb_rubros.cod_rubro%TYPE; --wh_cdcuent
      v_cod_sit_contable md_cta_documentos.cod_sit_contable%TYPE;
      v_encontro         VARCHAR2(1);
      v_msj              VARCHAR2(250);
      --
      CURSOR cur3 IS
         SELECT ct.cod_modulo,
                ct.cod_modalidad,
                ct.cod_oficina,
                ct.cod_moneda,
                SUM(nvl(d.mto_dev_actual, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0),
                d.estado,
                ct.cod_sit_contable
           FROM ge_plz_contables  pc,
                md_devengados     d,
                md_cta_documentos ct,
                ge_clientes       c,
                ge_cta_clientes   cc,
                ge_modalidades    mo
          WHERE d.fecha = v_fec_actual
            AND d.nro_cuenta = ct.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND mo.cod_modulo = ct.cod_modulo
            AND mo.cod_modalidad = ct.cod_modalidad
               -- si estado = RIPEADO, devengar en plazo del REPO
            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (decode(d.estado, 'E', (ct.fec_ven_repo - ct.fec_ini_repo),
                                            (ct.fec_vencimiento - ct.fec_inicio))))
         --AND CT.ESTADO = 'C' JCLG
          GROUP BY ct.cod_modulo,
                   ct.cod_modalidad,
                   ct.cod_oficina,
                   ct.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   d.estado,
                   ct.cod_sit_contable;
      --
      v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
      r_gtasi            ge_tip_asientos%ROWTYPE;
      --
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X')
            AND (est_cuenta = v_est_cuenta OR nvl(est_cuenta, 'X') = 'X')
            AND (tip_cuenta = v_tip_cuenta OR nvl(tip_cuenta, 'X') = 'X')
            AND (tip_interes = v_tip_interes OR nvl(tip_interes, 'X') = 'X')
            AND (tip_renovacion = v_tip_renovacion OR nvl(tip_renovacion, 'X') = 'X')
            AND (cat_automatica = v_cat_automatica OR nvl(cat_automatica, -1) = -1)
            AND (cod_sit_contable IS NULL OR cod_sit_contable = v_cod_sit_contable);
   BEGIN
      v_msj := ' Intereses devengados ';
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_tip_deudor,
                 v_cod_plazo,
                 v_cod_pro_contable,
                 v_est_cuenta,
                 v_cod_sit_contable;
         EXIT WHEN cur3%NOTFOUND;
         IF v_est_cuenta = 'E' THEN
            -- Si es una cuenta con Estado REPO carga la transacción 902
            v_cod_transaccion := 902;
         ELSE
            v_cod_transaccion := 901;
         END IF;
         --- ve el tipo de asiento por el CREDITO
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = v_cod_transaccion
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad) || '-' || v_est_cuenta ||
                                        ' no tiene asiento de Credito definido.');
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);
               END IF;
         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovgs := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            IF fug_obt_tip_implementacion = 1 THEN
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            ELSE
               -- se obtiene la cotizacion de cierre
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            END IF;
            xx_immovgs := round(v_mto_interes * v_mto_cotizacion, 0);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;

         -- REPO-CNF-12/2015: Para documentos Ripeados se cambia para tomar los rubros correctos
         If v_est_cuenta = 'R' Then
           v_cod_sit_contable := '10000003';
         End If;

         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovgs > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovgs       := xx_immovgs;
            ELSE
               wh_immovgs := xx_immovgs * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(v_est_cuenta) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovgs <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovgs;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := NULL;
               r_baade.cod_modulo     := v_cod_mod_padre;
               r_baade.cod_modalidad  := v_cod_mad_padre;
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --

         --si es call money vista,fideicomiso debe hacer solo la 901 jclg
         /*if v_cod_modalidad not in (109,110,120) then
           --- ve el tipo de asiento por el DEBITO
           BEGIN
             SELECT COD_TIP_ASIENTO, DESCRIPCION, cod_tip_asiento
               INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
               FROM GE_TRANSACCIONES
              WHERE COD_MODULO = v_cod_modulo
               AND COD_MODALIDAD = v_cod_modalidad
               AND COD_TRANSACCION = 903
               AND COD_TIP_ASIENTO IS NOT NULL;
           EXCEPTION
             WHEN NO_DATA_FOUND THEN
               raise_application_error(-20000,
               'Transaccion '||TO_CHAR(v_cod_modulo)||'-'||TO_CHAR(v_cod_modalidad)||'-903 no tiene asiento de Debito definido.');
             WHEN OTHERS THEN
               if sqlcode <= -20000 then
                 raise;
               else
                 raise_application_error(-20002,
                 'Error lp_int_devengados '||sqlerrm);
               end if;
           END;

           ------------------
           -- ve la moneda --
           ------------------
           --v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos
           IF v_cod_moneda =  v_cod_mon_local THEN
             -- es moneda nacional --
             ------------------------
             xx_immovgs := v_mto_interes;
             xx_immovex := 0;
             xx_vltasci := 0;
           ELSE
             -- se obtiene la cotizacion de cierre de bcp--
             if fug_obt_tip_implementacion = 1 then
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
             else
               -- se obtiene la cotizacion de cierre
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
             end if;
             xx_immovgs := round(v_mto_interes * v_mto_cotizacion,0);
             xx_immovex := v_mto_interes;
             xx_vltasci := v_mto_cotizacion;
           END IF;
           ----- ciclo para GE_TIP_ASIENTOS ------
           -------------------------------
           IF c_tip_asientos%isopen THEN
             CLOSE c_tip_asientos;
           END IF;
           OPEN c_tip_asientos;
           v_nro_linea := 0;
           LOOP
             FETCH c_tip_asientos INTO r_gtasi;
             EXIT WHEN  c_tip_asientos%NOTFOUND;
             ---Reemplaza el valor del tipo de deudor, si importa-
             IF r_gtasi.IND_DEUDOR = 'S' THEN
               v_cod_rubro := SUBSTR(r_gtasi.COD_RUBRO,1,8)||
                           LTRIM(TO_CHAR(v_tip_deudor,'00'))||
                           SUBSTR(r_gtasi.COD_RUBRO,11,5);
             ELSE
               v_cod_rubro := r_gtasi.COD_RUBRO;
             END IF;
             ---Reemplaza el codigo del plazo si es necesario -----
             IF r_gtasi.IND_PLAZO = 'S' THEN
               v_cod_rubro := SUBSTR(v_cod_rubro,1,2)||
                           LTRIM(TO_CHAR(v_cod_plazo))||
                           SUBSTR(v_cod_rubro,4,12);
             END IF;
             ---Reemplaza el codigo del producto -----------------------
             IF r_gtasi.IND_PRODUCTO = 'S' THEN
               v_cod_rubro := SUBSTR(v_cod_rubro,1,10)||
                           LTRIM(TO_CHAR(v_cod_pro_contable,'000'))||
                           SUBSTR(v_cod_rubro,14,2);
             END IF;
             ------------------------------------------------------
             v_encontro:= 'S';
             lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
             if v_encontro = 'N' then
               v_msj := 'Cuenta inexistente en Plan de Cuentas '||v_cod_rubro;
               v_cod_rubro  := '999999999999999';
               v_mon_rubro  := v_cod_mon_local;
             end if;
             IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
                wh_immovex := 0;
                wh_vltasci := 0;
             ELSE
                wh_immovex := xx_immovex;
                wh_vltasci := xx_vltasci;
             END IF;
             -- ve el tipo de movimiento --
             ------------------------------
             v_tip_movimiento := r_gtasi.tip_movimiento;
             IF xx_immovgs > 0 THEN
               v_tip_movimiento:= r_gtasi.TIP_MOVIMIENTO;
               wh_immovgs := xx_immovgs;
             ELSE
               wh_immovgs := xx_immovgs * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.TIP_MOVIMIENTO = 'C' THEN
                 v_tip_movimiento:= 'D';
               ELSE
                 v_tip_movimiento:= 'C';
               END IF;
             END IF;
             ------------------------------------------------------
             wh_dcrefer := 'DEVENG.';
             wh_dcdescr := substr(to_char(v_cod_modulo) || ' ' ||
                       to_char(v_cod_modalidad) || ' ' ||
                       to_char(903)        || ' ' ||
                       v_des_transaccion,1,60);
             vh_cod_oficina    := v_cod_oficina;
             vh_cod_modulo     := v_cod_modulo;
             vh_cod_modalidad  := v_cod_modalidad;
             vh_cod_ofi_origen := v_cod_oficina;
             wh_lgprote        := 'N';
             wh_lgdeact        := 'N';
             wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
             vh_nro_asiento    := 0;
             v_cod_mod_padre   := v_cod_modulo;
             v_cod_mad_padre   := v_cod_modalidad;
             -----
             IF wh_immovgs <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.FECHA          := v_fec_actual;
               r_baade.COD_OFICINA    := vh_cod_oficina;
               r_baade.NRO_ASIENTO    := 0;
               r_baade.NRO_LINEA      := v_nro_linea;
               r_baade.COD_RUBRO      := v_cod_rubro;
               r_baade.TIP_MOVIMIENTO := v_tip_movimiento;
               r_baade.MTO_MON_RUBRO  := wh_immovex;
               r_baade.MTO_MON_LOCAL  := wh_immovgs;
               r_baade.DESCRIPCION    := wh_dcdescr;
               r_baade.REFERENCIA     := wh_dcrefer;
               r_baade.PROTEGIDO      := wh_lgprote;
               r_baade.REF_MOVIMIENTO := null;
               r_baade.ACTUALIZADO    := wh_lgdeact;
               r_baade.VAL_COTIZACION := wh_vltasci;
               r_baade.DISTRIBUIDO    := wh_lgctadi;
               r_baade.COD_MODULO     := v_cod_mod_padre;
               r_baade.COD_MODALIDAD  := v_cod_mad_padre;
               r_baade.COD_OFI_ORIGEN := v_cod_ofi_origen;
               lp_ins_asi_aut_det(r_baade);
             END IF;
           END LOOP;      -- fin de tipo de asientos --
         end if;*/
      END LOOP; -- fin del ciclo de intereses devengados --
   END;
   -- Intereses Devengados Operaciones Futuras.
   PROCEDURE lp_dev_ope_futuras IS
      v_fec_actual      ge_calendarios.fec_actual%TYPE := pae_cnf.fu_obt_fec_actual(7);
      v_cod_mon_local   ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
      v_cod_mon_cta     ba_monedas.cod_moneda%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_descripcion     ge_transacciones.descripcion%TYPE;
      v_cod_tip_asiento ge_transacciones.cod_tip_asiento%TYPE;
      v_encontro        VARCHAR2(1);
      -- Variables Cursor
      v_cod_modulo          lc_devengados.cod_modulo%TYPE;
      v_cod_mad_transaccion lc_devengados.cod_mad_transaccion%TYPE;
      v_cod_ofi_origen      lc_devengados.cod_oficina%TYPE;
      v_cod_moneda          lc_devengados.cod_moneda%TYPE;
      v_mto_interes         lc_devengados.mto_interes%TYPE;
      v_cod_mad_padre       lc_devengados.cod_mad_padre%TYPE;
      v_descuento           lc_devengados.descuento%TYPE;
      v_residente           ge_clientes.residente%TYPE;
      v_cod_sec_contable    ge_clientes.cod_sec_contable%TYPE;
      v_cod_tip_deudor      ge_clientes.cod_tip_deudor%TYPE;
      v_cod_plazo           ge_plz_contables.cod_plazo%TYPE;
      --
      xx_immovgs NUMBER;
      xx_immovex NUMBER;
      xx_vltasci NUMBER;
      --
      r_baade cb_asi_automaticos_det%ROWTYPE;
      r_gtasi ge_tip_asientos%ROWTYPE;
      ----------------------------------------------------------------------
      -- Leer todas las operaciones a futuro vigentes -- MODALIDAD = 76   --
      ----------------------------------------------------------------------
      CURSOR cur3 IS
         SELECT d.cod_modulo,
                d.cod_mad_transaccion,
                d.cod_ofi_origen,
                d.cod_moneda,
                SUM(nvl(d.mto_interes, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                d.cod_mad_padre,
                d.descuento
           FROM lc_devengados  d,
                lc_ope_futuras o,
                ge_clientes    c,
                --ge_cta_clientes cc,
                ge_plz_contables pc
          WHERE d.fecha = v_fec_actual
            AND d.cod_modalidad = o.cod_modalidad
            AND d.cod_oficina = o.cod_oficina
            AND d.nro_cuenta = o.nro_cuenta
            AND d.nro_operacion = o.nro_operacion
            AND d.cod_mad_transaccion = o.cod_mad_transaccion

               --and d.nro_cuenta = cc.nro_cuenta
               --and cc.relacion = 'P'
               --and cc.cod_persona = c.cod_persona
            AND c.cod_persona = o.cod_persona

            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (o.fec_vencimiento - o.fec_operacion))
          GROUP BY d.cod_modulo,
                   d.cod_mad_transaccion,
                   d.cod_ofi_origen,
                   d.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   d.cod_mad_padre,
                   d.descuento
         HAVING SUM(nvl(d.mto_interes, 0)) > 0;
      --
      CURSOR cur5 IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento = v_cod_tip_asiento
            AND cod_moneda = v_cod_moneda
            AND cod_sec_contable = v_cod_sec_contable
            AND (ind_residente = v_residente OR ind_residente = 'X');
   BEGIN
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_mad_transaccion,
                 v_cod_ofi_origen,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_cod_tip_deudor,
                 v_cod_plazo,
                 v_cod_mad_padre,
                 v_descuento;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento ---
         IF v_cod_mad_padre = 76 THEN
            -- operaciones futuras --
            IF v_cod_mad_transaccion = 71 THEN
               -- es una compra --
               IF v_descuento = 'N' THEN
                  -- es un premio --
                  v_cod_transaccion := 1901;
               ELSE
                  v_cod_transaccion := 1902;
               END IF;
            ELSE
               -- es una venta --
               IF v_descuento = 'N' THEN
                  -- es un premio --
                  v_cod_transaccion := 1902;
               ELSE
                  v_cod_transaccion := 1901;
               END IF;
            END IF;
            /*ELSIF v_cod_mad_padre = 77 THEN -- operaciones swap --
            IF v_cod_mad_transaccion = 71 THEN -- es una compra --
               IF v_descuento = 'N' THEN  -- es un premio --
                  v_cod_transaccion := 903;
               ELSE
                  v_cod_transaccion := 904;
               END IF;
            ELSE  -- es una venta --
               IF v_descuento = 'N' THEN -- es un premio --
                  v_cod_transaccion := 904;
               ELSE
                  v_cod_transaccion := 903;
               END IF;
            END IF;*/
         ELSE
            raise_application_error(-20004,
                                    'ERROR. La modalidad ' || to_char(v_cod_mad_padre) ||
                                     ' no esta definida ');
         END IF;
         BEGIN
            SELECT cod_tip_asiento, descripcion
              INTO v_cod_tip_asiento, v_descripcion
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_mad_transaccion
               AND cod_transaccion = v_cod_transaccion
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'No tiene Asiento Relac. para Deveng.: ' ||
                                        to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_mad_transaccion) || '-' ||
                                        to_char(v_cod_transaccion));
            WHEN OTHERS THEN
               raise_application_error(-20001, SQLERRM);
         END;
         ------------------------
         xx_immovgs := v_mto_interes;
         xx_immovex := 0;
         xx_vltasci := 0;
         -------------------------------
         ----- ciclo para GE_TIP_ASIENTOS ------

         IF cur5%ISOPEN THEN
            CLOSE cur5;
         END IF;
         OPEN cur5;
         r_baade.nro_linea := 0;
         r_baade.fecha     := v_fec_actual;
         LOOP
            FETCH cur5
               INTO r_gtasi;
            EXIT WHEN cur5%NOTFOUND;
            ---Agregado por agustin para el nuevo plan de cuentas ---
            IF r_gtasi.ind_deudor = 'S' THEN
               r_baade.cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) ||
                                    ltrim(to_char(v_cod_tip_deudor, '00')) ||
                                    substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               r_baade.cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---------------------------------------------------------
            IF r_gtasi.ind_plazo = 'S' THEN
               r_baade.cod_rubro := substr(r_baade.cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                                    substr(r_baade.cod_rubro, 4, 12);
            END IF;
            --
            v_encontro := 'S';
            --
            lp_obt_mon_rubro(r_baade.cod_rubro, v_cod_mon_cta, v_encontro);
            IF v_encontro = 'N' THEN
               --r_baade.cod_rubro  := '999999999999999';
               v_cod_mon_cta := v_cod_mon_local;
            END IF;
            --
            IF v_cod_mon_cta = v_cod_mon_local THEN
               -- moneda local --
               r_baade.mto_mon_rubro  := 0;
               r_baade.val_cotizacion := 0;
            ELSE
               r_baade.mto_mon_rubro  := xx_immovex;
               r_baade.val_cotizacion := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            IF xx_immovgs > 0 THEN
               r_baade.tip_movimiento := r_gtasi.tip_movimiento;
               r_baade.mto_mon_local  := xx_immovgs;
            ELSE
               r_baade.mto_mon_local := xx_immovgs * -1;
               r_baade.mto_mon_rubro := r_baade.mto_mon_rubro * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  r_baade.tip_movimiento := 'D';
               ELSE
                  r_baade.tip_movimiento := 'C';
               END IF;
            END IF;
            IF r_baade.mto_mon_local <> 0 THEN
               --
               r_baade.referencia     := 'DEVENG.';
               r_baade.descripcion    := to_char(v_cod_modulo) || ' ' ||
                                         to_char(v_cod_mad_transaccion) || ' ' ||
                                         to_char(v_cod_transaccion) || ' ' ||
                                         substr(v_descripcion, 1, 20);
               r_baade.cod_ofi_origen := v_cod_ofi_origen;
               r_baade.cod_oficina    := v_cod_ofi_origen;
               r_baade.cod_modulo     := v_cod_modulo;
               r_baade.protegido      := 'N';
               r_baade.actualizado    := 'N';
               r_baade.distribuido    := 'N';
               r_baade.cod_modulo     := v_cod_modulo;
               r_baade.cod_modalidad  := v_cod_mad_transaccion;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := r_baade.nro_linea + 1;
               --
               lp_ins_asi_aut_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
      END LOOP; -- fin del ciclo de intereses devengados --
   END;
   /* Insertar asientos automaticos detalles. */
   PROCEDURE lp_ins_asi_aut_det(rp_baade IN cb_asi_automaticos_det%ROWTYPE) IS
   BEGIN
      INSERT INTO cb_asi_automaticos_det
         (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_rubro,
          mto_mon_local, descripcion, referencia, protegido, actualizado, val_cotizacion,
          distribuido, ref_movimiento, cod_modulo, cod_modalidad, cod_ofi_origen, fec_valor)
      VALUES
         (rp_baade.fecha, rp_baade.cod_oficina, rp_baade.nro_asiento, rp_baade.nro_linea,
          rp_baade.cod_rubro, rp_baade.tip_movimiento, rp_baade.mto_mon_rubro,
          rp_baade.mto_mon_local, rp_baade.descripcion, rp_baade.referencia, rp_baade.protegido,
          rp_baade.actualizado, rp_baade.val_cotizacion, rp_baade.distribuido,
          rp_baade.ref_movimiento, rp_baade.cod_modulo, rp_baade.cod_modalidad,
          rp_baade.cod_ofi_origen, rp_baade.fec_valor);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Ins.Cb_asi_automaticos_det ' || rp_baade.nro_asiento || '-' ||
                                  rp_baade.referencia || '-' || SQLERRM);
   END;
   /* Obtener la moneda del rubro del parametro. */
   PROCEDURE lp_obt_mon_rubro
   (
      p_cod_rubro  IN cb_rubros.cod_moneda%TYPE,
      p_cod_moneda IN OUT cb_rubros.cod_moneda%TYPE,
      p_encontro   IN OUT VARCHAR2
   ) IS
   BEGIN
      SELECT cod_moneda INTO p_cod_moneda FROM cb_rubros WHERE cod_rubro = p_cod_rubro;
   EXCEPTION
      WHEN no_data_found THEN
         -- OJO!!! solucion temporal desde aqui ---------------
         IF substr(p_cod_rubro, 14, 2) IN ('99', '00') THEN
            p_cod_moneda := pag_gen.fu_obt_mon_local;
            p_encontro   := 'S';
         ELSIF substr(p_cod_rubro, 14, 2) IN ('01', '98') THEN
            p_cod_moneda := pag_gen.fu_obt_mon_fuerte;
            p_encontro   := 'S';
         ELSE
            -- OJO!! temporal hasta aqui -------------------------
            p_encontro := 'N';
         END IF;
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Rec. Rubro ' || p_cod_rubro || '-' || SQLERRM);
   END;
BEGIN
    v_lugar := 'INICIO';
   --Obtiene las Fechas necesarias----------------------
   pag_cal.pr_obt_dat_calendar(pae_cnf.g_cod_modulo);
   v_fec_actual        := pag_cal.g_fec_actual;
   v_ult_dia_mes_habil := pag_cal.g_ult_dia_mes_habil;

   --- Desactivar FK entre cabeceras asientos y detalles
   /*   sql_util.ejecute_dml('Alter table cb_asi_automaticos_det disable constraint FK_BAADE_NRO_ASIENTO', v_error);
   if v_error is not null then
      raise_application_error(-20000,
      'Disable Fk '||v_error);
   end if;*/
   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   -- Desactivar el PK de los detalles de asientos
   sql_util.ejecute_dml('alter table CB_ASI_AUTOMATICOS_DET disable constraint PK_CB_ASI_AUTOMATICOS_DET',
                        v_error);
   IF v_error IS NOT NULL THEN
      raise_application_error(-20000, 'Disable PK ' || v_error);
   END IF;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('PRA_GEN_ASIENTOS','Desactivar PK_cb_asi_automaticos_det', v_fec_actual, v_hor_inicio, v_hor_fin);
   -----------------------------------------------------
   --Obtiene la Moneda Local
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   -----------------------------------------------------
   v_cod_oficina := 0;
   -----------------------------------
   -- limpia las tablas de asientos --
   ------------------------------------------------------------------------
   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   DELETE cb_asi_automaticos_det WHERE fecha = v_fec_actual;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('PRA_GEN_ASIENTOS','1-DELETE cb_asi_automaticos_det', v_fec_actual, v_hor_inicio, v_hor_fin);

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   DELETE cb_asi_automaticos a WHERE fecha = v_fec_actual;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('PRA_GEN_ASIENTOS','2-DELETE cb_asi_automaticos', v_fec_actual, v_hor_inicio, v_hor_fin);

   ---llama a procedimientos --
   ----------------------------
   --
   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_EQU_MON_LOCAL';
   lp_equ_mon_local;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('PRA_GEN_ASIENTOS',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_ESTADISTICO';
   lp_estadistico;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('PRA_GEN_ASIENTOS',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_MOV_DIARIOS';
   lp_mov_diarios;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('PRA_GEN_ASIENTOS',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_INT_DEVENGADOS';
   lp_int_devengados;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('PRA_GEN_ASIENTOS',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_INT_DEV_PRESTAMOS';
   lp_int_dev_prestamos;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('PRA_GEN_ASIENTOS',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_INT_DEV_COMISIONES';
   lp_int_dev_comisiones;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('PRA_GEN_ASIENTOS',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_INT_DEV_MESADINERO';
   lp_int_dev_mesadinero;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('PRA_GEN_ASIENTOS',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'PRC_AJU_SOBREGIROS';

   /*************************************************/
   --CONTABILIZACION DE CONTINGENCIA DE LINEAS BR
   prc_aju_sobregiros;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('PRA_GEN_ASIENTOS',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);


   /*************************************************/
   v_lugar := 'LP_DEV_OPE_FUTURAS';
   -----------------------------------
   ---lp_ret_sucursal; No todavia segun Agustin se deja en el CASE-reanalizar
   ------------------------------------------------------
   -- solo si es fin de mes
   ------------------------------------------------------
   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   IF v_ult_dia_mes_habil = v_fec_actual THEN
      -- Devenga Operaciones Futuras.
      lp_dev_ope_futuras;
   END IF;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('PRA_GEN_ASIENTOS',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_lugar := 'LP_CAB_ASIENTO';
   -----------------------------------------------------------
   -- genera la cabecera a partir de los detalles generados --
   -----------------------------------------------------------
   lp_cab_asiento;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('PRA_GEN_ASIENTOS',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);


   v_lugar := 'FIN LP_CAB_ASIENTO';
   ---borrar asientos nro 0---
   BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
   END;

   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   DELETE FROM cb_asi_automaticos_det t WHERE t.nro_asiento = 0;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('PRA_GEN_ASIENTOS',V_LUGAR, v_fec_actual, v_hor_inicio, v_hor_fin);

   --- Re-activar FK entre cabeceras asientos y detalles
   /*   sql_util.ejecute_dml('Alter table cb_asi_automaticos_det enable constraint FK_BAADE_NRO_ASIENTO', v_error);
   if v_error is not null then
      raise_application_error(-20000,
      'Enable Fk '||v_error);
   end if;*/
   -- Activar el PK de los detalles de asientos
   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   sql_util.ejecute_dml('alter table CB_ASI_AUTOMATICOS_DET enable constraint PK_CB_ASI_AUTOMATICOS_DET',
                        v_error);
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos('PRA_GEN_ASIENTOS','enable constraint', v_fec_actual, v_hor_inicio, v_hor_fin);

   IF v_error IS NOT NULL THEN
      raise_application_error(-20000, 'Enable PK ' || v_error);
   END IF;
exception
when others then
    raise_application_error(-20001, 'Error en proc. ' || v_lugar ||'-'|| sqlerrm);
END;
/

