CREATE OR REPLACE PROCEDURE IT.PRC_GEN_SOBREGIROS IS
   rv_gcale  ge_calendarios%ROWTYPE;
   v_fcdehoy DATE;
   v_msj     VARCHAR2(200);
   v_hora    ge_movimientos.hora%TYPE;
   v_fcanter ge_calendarios.fec_anterior%TYPE;
   v_lugar   varchar2(200);

   v_can_dia_exceso   cc_sobregiros.can_dias%TYPE;
   v_can_dia_sobregiro cc_sobregiros.can_dia_sobregiro%TYPE;

   -- EP - N.AN. 2014-10-23 SC 9468 - ITGF - Dias de Mora de Cuenta Corriente
   v_tie_sob_fec_anterior   varchar2(1);
   v_act_sobregiro          varchar2(1);
   v_can_dia_exc_original   cc_sobregiros.can_dias%TYPE;
   v_can_dia_sob_original   cc_sobregiros.can_dia_sobregiro%TYPE;

   v_aux_saldo              cc_sobregiros.saldo%TYPE;
   v_aux_sal_total          cc_sobregiros.sal_total%TYPE;
   v_aux_sal_retenido       cc_sobregiros.sal_retenido%TYPE;
   v_aux_liquidado          cc_sobregiros.liquidado%TYPE;
   v_aux_mto_linea          cc_sobregiros.mto_linea%TYPE;
   v_hor_inicio             varchar2(8);
   v_hor_fin                varchar2(8);
   v_cod_programa           ge_log_procesos.cod_programa%type;
   v_usu_mig_excluir        varchar2(30);
   
   -- CIE - 576 
   ---------------FECHAS----------------
   v_fuldiha      date;
   v_fuldime      date;
   v_fprdime      date;
   v_fprdiha      date;
   v_difdias      NUMBER(6) := 0;
   v_fecinic      date;
   v_fec_aux       DATE := NULL;

   -- Procedimiento que actualiza las líneas de sobregiro
   PROCEDURE lp_act_lin_sobregiro(p_nro_cuenta IN VARCHAR2, p_estado IN VARCHAR2) IS
      CURSOR cu_lineas IS
         SELECT b.nro_secuencia, b.nro_sec_padre
           FROM cc_lin_sobregiros b
          WHERE b.nro_cuenta = p_nro_cuenta;
   BEGIN
      FOR ccu_lineas IN cu_lineas LOOP
         UPDATE cc_lin_sobregiros clsob
            SET clsob.estado = p_estado
          WHERE clsob.nro_secuencia IN (ccu_lineas.nro_secuencia, ccu_lineas.nro_sec_padre);
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            RAISE_APPLICATION_ERROR(-20010, 'lp_act_lin_sobregiros. ' || SQLERRM);
         END IF;
   END;
   PROCEDURE lp_cal_sob_diario IS
      v1_nrcuent ge_cuentas.nro_cuenta%TYPE;
      v_ttdiasg  NUMBER(06);
      v_sitsald  VARCHAR2(01);
      v_dia_cargos NUMBER(4);
      v_can_hist_fec_ant PLS_INTEGER;
      v_etapa VARCHAR2(100) := 'inicio';
      -- Vía rápida: solo es válida cuando la fecha actual es consecutiva.
      v_via_rap PLS_INTEGER := 0;

      CURSOR cc_cta_corrientes IS
         SELECT cod_modulo,
                cod_modalidad,
                cod_oficina,
                nro_cuenta,
                nvl(sal_total, 0) - nvl(sal_retenido, 0) - nvl(sal_bloqueado, 0)
           FROM cc_cta_corrientes
          WHERE cod_modulo = 4
            AND cod_modalidad = 41
            and (v_usu_mig_excluir is null or usu_insercion <> v_usu_mig_excluir)
            AND nvl(sal_total, 0) - nvl(sal_retenido, 0) - nvl(sal_bloqueado, 0) < 0
            AND estado <> 'C'
          ORDER BY nro_cuenta;
      
      TYPE typ_reg_cta IS RECORD (
         cod_modulo    ba_modulos.cod_modulo%type,
         cod_modalidad ge_modalidades.cod_modalidad%TYPE,
         cod_oficina   ba_oficinas.cod_oficina%TYPE,
         nro_cuenta    ge_cuentas.nro_cuenta%TYPE,
         saldoac       cc_cta_bancarias.sal_minimo%type
      );
      
      TYPE typ_tab_cta IS TABLE OF typ_reg_cta;
      v_tab_cta typ_tab_cta;
      v_lote_cta SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();

      TYPE typ_reg_hist IS RECORD
      (
         id_reg            ROWID,
         nro_cuenta        cc_sobregiros.nro_cuenta%TYPE,
         fecha             cc_sobregiros.fecha%TYPE,
         saldo             cc_sobregiros.saldo%TYPE,
         mto_linea         cc_sobregiros.mto_linea%TYPE,
         liquidado         cc_sobregiros.liquidado%TYPE,
         can_dias          cc_sobregiros.can_dias%TYPE,
         can_dia_sobregiro cc_sobregiros.can_dia_sobregiro%TYPE
      );

      TYPE typ_tab_hist IS TABLE OF typ_reg_hist;
      v_tab_hist typ_tab_hist := typ_tab_hist();

      -- Registros del día actual para cuentas con acumulado anterior válido.
      TYPE typ_reg_hist_act IS RECORD
      (
         id_reg                  ROWID,
         nro_cuenta              cc_sobregiros.nro_cuenta%TYPE,
         fecha                   cc_sobregiros.fecha%TYPE,
         saldo                   cc_sobregiros.saldo%TYPE,
         mto_linea               cc_sobregiros.mto_linea%TYPE,
         liquidado               cc_sobregiros.liquidado%TYPE,
         can_dias                cc_sobregiros.can_dias%TYPE,
         can_dia_sobregiro       cc_sobregiros.can_dia_sobregiro%TYPE,
         can_dias_ini           cc_sobregiros.can_dias%TYPE,
         can_dia_sob_ini  cc_sobregiros.can_dia_sobregiro%TYPE
      );

      TYPE typ_tab_hist_act IS TABLE OF typ_reg_hist_act;
      v_tab_hist_act typ_tab_hist_act := typ_tab_hist_act();

      -- Cuentas sin acumulado anterior: conservan el recorrido histórico completo.
      TYPE typ_reg_hist_alt IS RECORD
      (
         id_reg                  ROWID,
         nro_cuenta              cc_sobregiros.nro_cuenta%TYPE,
         fecha                   cc_sobregiros.fecha%TYPE,
         saldo                   cc_sobregiros.saldo%TYPE,
         mto_linea               cc_sobregiros.mto_linea%TYPE,
         liquidado               cc_sobregiros.liquidado%TYPE,
         can_dias                cc_sobregiros.can_dias%TYPE,
         can_dia_sobregiro       cc_sobregiros.can_dia_sobregiro%TYPE,
         can_dias_ini           cc_sobregiros.can_dias%TYPE,
         can_dia_sob_ini  cc_sobregiros.can_dia_sobregiro%TYPE
      );

      TYPE typ_tab_hist_alt IS TABLE OF typ_reg_hist_alt;
      v_tab_hist_alt typ_tab_hist_alt := typ_tab_hist_alt();

      TYPE typ_map_pos IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(15);
      v_pos_ini_cta typ_map_pos;
      v_pos_fin_cta   typ_map_pos;
      v_pos_ini_act           typ_map_pos;
      v_pos_fin_act           typ_map_pos;
      v_pos_ini_alt       typ_map_pos;
      v_pos_fin_alt       typ_map_pos;

      TYPE typ_map_can_dias IS TABLE OF cc_sobregiros.can_dias%TYPE
         INDEX BY VARCHAR2(15);
      TYPE typ_map_can_dia_sob IS TABLE OF cc_sobregiros.can_dia_sobregiro%TYPE
         INDEX BY VARCHAR2(15);
      -- Acumulados de CAN_DIAS y CAN_DIA_SOBREGIRO del día anterior.
      v_can_dias_ini       typ_map_can_dias;
      v_can_dia_sob_ini    typ_map_can_dia_sob;

      TYPE typ_tab_act_id_reg IS TABLE OF ROWID;
      TYPE typ_tab_act_nro_cta IS TABLE OF cc_sobregiros.nro_cuenta%TYPE;
      TYPE typ_tab_act_fec IS TABLE OF cc_sobregiros.fecha%TYPE;
      TYPE typ_tab_act_liq_orig IS TABLE OF cc_sobregiros.liquidado%TYPE;
      TYPE typ_tab_act_can_dias IS TABLE OF cc_sobregiros.can_dias%TYPE;
      TYPE typ_tab_act_can_dia_sob IS TABLE OF cc_sobregiros.can_dia_sobregiro%TYPE;
      TYPE typ_tab_act_liq IS TABLE OF cc_sobregiros.liquidado%TYPE;
      TYPE typ_tab_act_mto_lin IS TABLE OF cc_sobregiros.mto_linea%TYPE;

      v_act_id_reg         typ_tab_act_id_reg := typ_tab_act_id_reg();
      v_act_nro_cta     typ_tab_act_nro_cta := typ_tab_act_nro_cta();
      v_act_fec          typ_tab_act_fec := typ_tab_act_fec();
      v_act_liq_orig   typ_tab_act_liq_orig := typ_tab_act_liq_orig();
      v_act_can_dias       typ_tab_act_can_dias := typ_tab_act_can_dias();
      v_act_can_dia_sob    typ_tab_act_can_dia_sob := typ_tab_act_can_dia_sob();
      v_act_liq      typ_tab_act_liq := typ_tab_act_liq();
      v_act_mto_lin      typ_tab_act_mto_lin := typ_tab_act_mto_lin();
      v_idx_act  PLS_INTEGER;

      TYPE typ_tab_res_nro_cta IS TABLE OF cc_sobregiros_res.nro_cuenta%TYPE;
      TYPE typ_tab_res_can_dias IS TABLE OF cc_sobregiros_res.can_dias%TYPE;
      TYPE typ_tab_res_sit_deuda IS TABLE OF cc_sobregiros_res.sit_deuda%TYPE;
      TYPE typ_tab_res_can_dia_sob IS TABLE OF cc_sobregiros_res.can_dia_sobregiro%TYPE;

      v_res_nro_cta     typ_tab_res_nro_cta := typ_tab_res_nro_cta();
      v_res_can_dias       typ_tab_res_can_dias := typ_tab_res_can_dias();
      v_res_sit_deuda      typ_tab_res_sit_deuda := typ_tab_res_sit_deuda();
      v_res_can_dia_sob    typ_tab_res_can_dia_sob := typ_tab_res_can_dia_sob();
      v_idx_res        PLS_INTEGER;

      PROCEDURE pr_cal_hist_cta
      (  p_nro_cuenta            IN  cc_sobregiros.nro_cuenta%TYPE,
         -- Racha condicionada por fecha consecutiva y cobertura de la linea.
         p_can_dias_hist         OUT NUMBER,
         -- Racha de registros consecutivos de sobregiro.
         p_can_dia_sob           OUT cc_sobregiros.can_dia_sobregiro%TYPE,
         -- Racha consecutiva donde el saldo supera la linea.
         p_can_dia_exc           OUT cc_sobregiros.can_dias%TYPE,
         -- Cantidad de registros encontrados en la fecha anterior.
         p_can_hist_ant          OUT PLS_INTEGER
      ) IS
         v_comfech ba_oficinas.fec_insercion%type;
         v_pos_fila_act PLS_INTEGER;
      BEGIN
         p_can_dias_hist := 0;
         p_can_dia_sob := 0;
         p_can_dia_exc := 0;
         p_can_hist_ant := 0;
         v_pos_fila_act := NULL;

         -- En un día consecutivo se continúa desde los contadores del día anterior.
         -- La vía rápida solo se usa si la cuenta tiene historia y acumulados válidos.
         IF v_via_rap = 1 AND
            v_can_dias_ini.EXISTS(p_nro_cuenta) AND
            v_can_dia_sob_ini.EXISTS(p_nro_cuenta) AND
            v_pos_ini_cta.EXISTS(p_nro_cuenta) THEN
            FOR j IN v_pos_ini_cta(p_nro_cuenta) ..
                      v_pos_fin_cta(p_nro_cuenta) LOOP
               IF v_tab_hist(j).fecha = v_fcdehoy THEN
                  v_pos_fila_act := j;
                  EXIT;
               END IF;
            END LOOP;

            IF v_pos_fila_act IS NOT NULL THEN
               -- La línea cubre el saldo: el exceso y los días de mora empiezan en cero.
               p_can_dias_hist :=
                  CASE
                     WHEN v_tab_hist(v_pos_fila_act).saldo <=
                          v_tab_hist(v_pos_fila_act).mto_linea THEN 0
                      WHEN NVL(v_can_dias_ini(p_nro_cuenta), 0) = 0 THEN 1
                      ELSE v_can_dias_ini(p_nro_cuenta) + 1
                  END;
               p_can_dia_exc :=
                  CASE
                     WHEN v_tab_hist(v_pos_fila_act).saldo <=
                          v_tab_hist(v_pos_fila_act).mto_linea THEN 0
                     WHEN NVL(v_can_dias_ini(p_nro_cuenta), 0) = 0 THEN 1
                     ELSE v_can_dias_ini(p_nro_cuenta) + 1
                  END;
               p_can_dia_sob :=
                  CASE
                     WHEN NVL(v_can_dia_sob_ini(p_nro_cuenta), 0) = 0 THEN 1
                     ELSE v_can_dia_sob_ini(p_nro_cuenta) + 1
                  END;
               p_can_hist_ant := 1;
               RETURN;
            END IF;
         END IF;

         -- Fallback: reproduce el cálculo histórico cuando no existe una base confiable.
         -- Cada contador tiene una regla de corte distinta y por eso se recorre por separado.
         IF v_pos_ini_cta.EXISTS(p_nro_cuenta) THEN
            -- V_TTDIASG: se detiene por salto de fecha o cuando la línea cubre el saldo.
            v_comfech := v_fcdehoy;
            FOR j IN v_pos_ini_cta(p_nro_cuenta) ..
                      v_pos_fin_cta(p_nro_cuenta) LOOP
               IF (v_comfech - v_tab_hist(j).fecha > 1) OR
                  (v_tab_hist(j).mto_linea >= v_tab_hist(j).saldo) THEN
                  EXIT;
               END IF;
               v_comfech := v_tab_hist(j).fecha;
               p_can_dias_hist := nvl(p_can_dias_hist, 0) + 1;
            END LOOP;

            -- CAN_DIA_SOBREGIRO: cuenta fechas consecutivas, sin evaluar cobertura de línea.
            v_comfech := v_fcdehoy;
            FOR j IN v_pos_ini_cta(p_nro_cuenta) ..
                      v_pos_fin_cta(p_nro_cuenta) LOOP
               IF v_comfech - v_tab_hist(j).fecha > 1 THEN
                  EXIT;
               END IF;
               v_comfech := v_tab_hist(j).fecha;
               p_can_dia_sob := nvl(p_can_dia_sob, 0) + 1;
            END LOOP;

            -- CAN_DIA_EXCESO: cuenta fechas consecutivas cuyo saldo supera la línea.
            v_comfech := v_fcdehoy;
            -- Se cuenta la fecha anterior para decidir si continúa el período no hábil.
            FOR j IN v_pos_ini_cta(p_nro_cuenta) ..
                      v_pos_fin_cta(p_nro_cuenta) LOOP
               IF v_comfech - v_tab_hist(j).fecha > 1 THEN
                  EXIT;
               END IF;
               IF v_tab_hist(j).saldo > v_tab_hist(j).mto_linea THEN
                  v_comfech := v_tab_hist(j).fecha;
                  p_can_dia_exc := nvl(p_can_dia_exc, 0) + 1;
               END IF;
            END LOOP;

            FOR j IN v_pos_ini_cta(p_nro_cuenta) ..
                      v_pos_fin_cta(p_nro_cuenta) LOOP
               IF v_tab_hist(j).fecha = v_fcanter THEN
                  p_can_hist_ant := p_can_hist_ant + 1;
               ELSIF v_tab_hist(j).fecha < v_fcanter THEN
                  EXIT;
               END IF;
            END LOOP;
         END IF;
      END pr_cal_hist_cta;
   BEGIN
      v_fcdehoy := rv_gcale.fec_actual;
      v_fcanter := rv_gcale.fec_anterior;
      v_fuldiha := rv_gcale.ult_dia_mes_habil;
      v_fuldime := rv_gcale.ult_dia_mes;
      v_fprdime := rv_gcale.pri_dia_mes;
      v_fprdiha := rv_gcale.pri_dia_mes_habil;
      v_dia_cargos := nvl(fug_obt_pardinamico('DIA_INA_CAR_SOBREGIROS', 4, 41), 9999);

      if v_fcdehoy = v_fuldiha then
         v_difdias := round(v_fuldime - v_fcanter , 0) - 1;
         v_fecinic := v_fcanter;
      elsif v_fcdehoy = v_fprdiha then
         v_difdias := round(v_fprdiha - v_fprdime, 0);
         v_fecinic := v_fprdime - 1;
      else
         v_difdias := round(v_fcdehoy - v_fcanter , 0) - 1;
         v_fecinic := v_fcanter;
      end if;

      -- Los saltos de calendario desactivan la vía rápida para conservar la lógica de no hábiles.
      IF TRUNC(v_fcdehoy) = TRUNC(v_fcanter) + 1 AND v_difdias = 0 THEN
         v_via_rap := 1;
      END IF;

      IF cc_cta_corrientes%ISOPEN THEN
         CLOSE cc_cta_corrientes;
      END IF;
      OPEN cc_cta_corrientes;
      LOOP
         FETCH cc_cta_corrientes BULK COLLECT INTO v_tab_cta LIMIT 5000;
         EXIT WHEN v_tab_cta.COUNT = 0;

         v_act_id_reg.DELETE;
         v_act_nro_cta.DELETE;
         v_act_fec.DELETE;
         v_act_liq_orig.DELETE;
         v_act_can_dias.DELETE;
         v_act_can_dia_sob.DELETE;
         v_act_liq.DELETE;
         v_act_mto_lin.DELETE;
         v_res_nro_cta.DELETE;
         v_res_can_dias.DELETE;
         v_res_sit_deuda.DELETE;
         v_res_can_dia_sob.DELETE;
         v_pos_ini_cta.DELETE;
         v_pos_fin_cta.DELETE;
         v_pos_ini_act.DELETE;
         v_pos_fin_act.DELETE;
         v_pos_ini_alt.DELETE;
         v_pos_fin_alt.DELETE;
         v_can_dias_ini.DELETE;
         v_can_dia_sob_ini.DELETE;
         v_tab_hist.DELETE;
         v_tab_hist_act.DELETE;
         v_tab_hist_alt.DELETE;

         v_lote_cta.DELETE;
         FOR i IN 1 .. v_tab_cta.COUNT LOOP
            v_lote_cta.EXTEND;
            v_lote_cta(v_lote_cta.COUNT) := v_tab_cta(i).nro_cuenta;
         END LOOP;

         IF v_via_rap = 1 THEN
            -- Primera lectura: cuentas con acumulado anterior; normalmente solo trae la fecha nueva.
            WITH cuentas_lote AS
            (
               SELECT c.nro_cuenta
                 FROM cc_cta_corrientes c
                WHERE c.cod_modulo = 4
                  AND c.cod_modalidad = 41
                  AND (v_usu_mig_excluir IS NULL OR c.usu_insercion <> v_usu_mig_excluir)
                  AND nvl(c.sal_total, 0) - nvl(c.sal_retenido, 0) - nvl(c.sal_bloqueado, 0) < 0
                  AND c.estado <> 'C'
                    AND c.nro_cuenta IN
                       (SELECT COLUMN_VALUE FROM TABLE(v_lote_cta))
            ),
            hist_ant AS
            (
               SELECT seed.nro_cuenta,
                      MAX(seed.can_dias) can_dias_ini,
                      MAX(seed.can_dia_sobregiro) can_dia_sob_ini
                 FROM cc_sobregiros seed
                 JOIN cuentas_lote lote
                   ON lote.nro_cuenta = seed.nro_cuenta
                WHERE seed.fecha = v_fcanter
                GROUP BY seed.nro_cuenta
               HAVING MAX(seed.can_dias) IS NOT NULL
                  AND MAX(seed.can_dia_sobregiro) IS NOT NULL
                  AND MAX(seed.can_dias) >= 0
                  AND MAX(seed.can_dia_sobregiro) >= 0
            )
            SELECT sob.ROWID,
                   sob.nro_cuenta,
                   sob.fecha,
                   sob.saldo,
                   sob.mto_linea,
                   sob.liquidado,
                   sob.can_dias,
                   sob.can_dia_sobregiro,
                      hist_ant.can_dias_ini,
                      hist_ant.can_dia_sob_ini
                   BULK COLLECT INTO v_tab_hist_act
              FROM cuentas_lote lote
                     JOIN hist_ant
                        ON hist_ant.nro_cuenta = lote.nro_cuenta
              JOIN cc_sobregiros sob
                ON sob.nro_cuenta = lote.nro_cuenta
             WHERE sob.fecha > v_fcanter
               AND sob.fecha <= v_fuldime
             ORDER BY sob.nro_cuenta, sob.fecha DESC, sob.saldo ASC;

            -- Segunda lectura: cuentas sin acumulado; estas requieren toda la historia disponible.
            WITH cuentas_lote AS
            (
               SELECT c.nro_cuenta
                 FROM cc_cta_corrientes c
                WHERE c.cod_modulo = 4
                  AND c.cod_modalidad = 41
                  AND (v_usu_mig_excluir IS NULL OR c.usu_insercion <> v_usu_mig_excluir)
                  AND nvl(c.sal_total, 0) - nvl(c.sal_retenido, 0) - nvl(c.sal_bloqueado, 0) < 0
                  AND c.estado <> 'C'
                    AND c.nro_cuenta IN
                       (SELECT COLUMN_VALUE FROM TABLE(v_lote_cta))
            ),
            hist_ant AS
            (
               SELECT seed.nro_cuenta,
                      MAX(seed.can_dias) can_dias_ini,
                      MAX(seed.can_dia_sobregiro) can_dia_sob_ini
                 FROM cc_sobregiros seed
                 JOIN cuentas_lote lote
                   ON lote.nro_cuenta = seed.nro_cuenta
                WHERE seed.fecha = v_fcanter
                GROUP BY seed.nro_cuenta
               HAVING MAX(seed.can_dias) IS NOT NULL
                  AND MAX(seed.can_dia_sobregiro) IS NOT NULL
                  AND MAX(seed.can_dias) >= 0
                  AND MAX(seed.can_dia_sobregiro) >= 0
            )
            SELECT sob.ROWID,
                   sob.nro_cuenta,
                   sob.fecha,
                   sob.saldo,
                   sob.mto_linea,
                   sob.liquidado,
                   sob.can_dias,
                   sob.can_dia_sobregiro,
                   hist_ant.can_dias_ini,
                   hist_ant.can_dia_sob_ini
              BULK COLLECT INTO v_tab_hist_alt
              FROM cuentas_lote lote
                     LEFT JOIN hist_ant
                        ON hist_ant.nro_cuenta = lote.nro_cuenta
              JOIN cc_sobregiros sob
                ON sob.nro_cuenta = lote.nro_cuenta
             WHERE hist_ant.nro_cuenta IS NULL
               AND sob.fecha <= v_fuldime
             ORDER BY sob.nro_cuenta, sob.fecha DESC, sob.saldo ASC;

            IF v_tab_hist_act.COUNT > 0 THEN
               FOR j IN 1 .. v_tab_hist_act.COUNT LOOP
                  IF NOT v_pos_ini_act.EXISTS(v_tab_hist_act(j).nro_cuenta) THEN
                     v_pos_ini_act(v_tab_hist_act(j).nro_cuenta) := j;
                  END IF;
                  v_pos_fin_act(v_tab_hist_act(j).nro_cuenta) := j;
               END LOOP;
            END IF;

            IF v_tab_hist_alt.COUNT > 0 THEN
               FOR j IN 1 .. v_tab_hist_alt.COUNT LOOP
                  IF NOT v_pos_ini_alt.EXISTS(v_tab_hist_alt(j).nro_cuenta) THEN
                     v_pos_ini_alt(v_tab_hist_alt(j).nro_cuenta) := j;
                  END IF;
                  v_pos_fin_alt(v_tab_hist_alt(j).nro_cuenta) := j;
               END LOOP;
            END IF;

            FOR i IN 1 .. v_tab_cta.COUNT LOOP
               v1_nrcuent := v_tab_cta(i).nro_cuenta;

               -- Se reagrupan ambas lecturas en el orden original de las cuentas del lote.
               IF v_pos_ini_act.EXISTS(v1_nrcuent) THEN
                  v_can_dias_ini(v1_nrcuent) :=
                     v_tab_hist_act(v_pos_ini_act(v1_nrcuent)).can_dias_ini;
                  v_can_dia_sob_ini(v1_nrcuent) :=
                     v_tab_hist_act(v_pos_ini_act(v1_nrcuent)).can_dia_sob_ini;

                  FOR j IN v_pos_ini_act(v1_nrcuent) .. v_pos_fin_act(v1_nrcuent) LOOP
                     v_tab_hist.EXTEND;
                     v_tab_hist(v_tab_hist.COUNT).id_reg := v_tab_hist_act(j).id_reg;
                     v_tab_hist(v_tab_hist.COUNT).nro_cuenta := v_tab_hist_act(j).nro_cuenta;
                     v_tab_hist(v_tab_hist.COUNT).fecha := v_tab_hist_act(j).fecha;
                     v_tab_hist(v_tab_hist.COUNT).saldo := v_tab_hist_act(j).saldo;
                     v_tab_hist(v_tab_hist.COUNT).mto_linea := v_tab_hist_act(j).mto_linea;
                     v_tab_hist(v_tab_hist.COUNT).liquidado := v_tab_hist_act(j).liquidado;
                     v_tab_hist(v_tab_hist.COUNT).can_dias := v_tab_hist_act(j).can_dias;
                     v_tab_hist(v_tab_hist.COUNT).can_dia_sobregiro :=
                        v_tab_hist_act(j).can_dia_sobregiro;
                  END LOOP;
               ELSIF v_pos_ini_alt.EXISTS(v1_nrcuent) THEN
                  FOR j IN v_pos_ini_alt(v1_nrcuent) .. v_pos_fin_alt(v1_nrcuent) LOOP
                     v_tab_hist.EXTEND;
                     v_tab_hist(v_tab_hist.COUNT).id_reg := v_tab_hist_alt(j).id_reg;
                     v_tab_hist(v_tab_hist.COUNT).nro_cuenta := v_tab_hist_alt(j).nro_cuenta;
                     v_tab_hist(v_tab_hist.COUNT).fecha := v_tab_hist_alt(j).fecha;
                     v_tab_hist(v_tab_hist.COUNT).saldo := v_tab_hist_alt(j).saldo;
                     v_tab_hist(v_tab_hist.COUNT).mto_linea := v_tab_hist_alt(j).mto_linea;
                     v_tab_hist(v_tab_hist.COUNT).liquidado := v_tab_hist_alt(j).liquidado;
                     v_tab_hist(v_tab_hist.COUNT).can_dias := v_tab_hist_alt(j).can_dias;
                     v_tab_hist(v_tab_hist.COUNT).can_dia_sobregiro :=
                        v_tab_hist_alt(j).can_dia_sobregiro;
                  END LOOP;
               END IF;
            END LOOP;
         ELSE
             SELECT sob.ROWID,
                        sob.nro_cuenta,
                        sob.fecha,
                        sob.saldo,
                        sob.mto_linea,
                        sob.liquidado,
                        sob.can_dias,
                        sob.can_dia_sobregiro
                BULK COLLECT INTO v_tab_hist
                FROM cc_sobregiros sob
                  WHERE sob.nro_cuenta IN
                     (SELECT COLUMN_VALUE FROM TABLE(v_lote_cta))
                  AND sob.fecha <= v_fuldime
               ORDER BY sob.nro_cuenta, sob.fecha DESC, sob.saldo ASC;
         END IF;

         IF v_tab_hist.COUNT > 0 THEN
            FOR j IN 1 .. v_tab_hist.COUNT LOOP
               IF NOT v_pos_ini_cta.EXISTS(v_tab_hist(j).nro_cuenta) THEN
                  v_pos_ini_cta(v_tab_hist(j).nro_cuenta) := j;
               END IF;
               v_pos_fin_cta(v_tab_hist(j).nro_cuenta) := j;
            END LOOP;
         END IF;

         FOR i IN 1 .. v_tab_cta.COUNT LOOP
            v1_nrcuent := v_tab_cta(i).nro_cuenta;
            v_etapa := 'calculo historico';

            pr_cal_hist_cta
            (
               p_nro_cuenta            => v1_nrcuent,
               p_can_dias_hist               => v_ttdiasg,
               p_can_dia_sob     => v_can_dia_sobregiro,
               p_can_dia_exc        => v_can_dia_exceso,
               p_can_hist_ant => v_can_hist_fec_ant
            );

         -- EP - N.AN. 2014-10-23 SC 9468 - ITGF - Dias de Mora de Cuenta Corriente
         -- cuando el sobregiro inicia un dia habil despues de fin de semana o feriado
         -- solo se actualiza el registro una vez y por logica se inicia en 0
         v_can_dia_sob_original := v_can_dia_sobregiro;
         v_can_dia_exc_original := v_can_dia_exceso;

          ------Determinacion de Situacion del sobregiro--------
               --campo cc_lin_sobregiros.sit_deuda
               IF nvl(v_ttdiasg, 0) < 61 THEN
                  v_sitsald := 'S';
               ELSIF v_ttdiasg < 91 THEN
                  v_sitsald := 'V';
               ELSIF v_ttdiasg < 181 THEN
                  v_sitsald := 'G';
               ELSIF v_ttdiasg < 361 THEN
                  v_sitsald := 'M';
               ELSE
                  v_sitsald := 'I';
               END IF;

            -- calcula por cuantos dias tiene que agregar --
            if v_fcdehoy = v_fuldiha then
               v_difdias := round(v_fuldime - v_fcanter , 0) - 1;
               v_fecinic := v_fcanter;
            elsif v_fcdehoy = v_fprdiha then
               v_difdias := round(v_fprdiha - v_fprdime, 0);
               v_fecinic := v_fprdime - 1;
            else
               v_difdias := round(v_fcdehoy - v_fcanter , 0) - 1;
               v_fecinic := v_fcanter;
            end if;

            -- Como la función que nos devuelve los días de sobregiro calcula sobre la fecha de hoy
            -- verificamos que si es mas de un día(fines de semana) lo que tenemos que insertar,
            -- restamos a los sobregiros la cantidad de días para que el cursor vaya de menor a mayor.
            if v_difdias > 0 then
               if v_can_dia_exceso > 0 and v_can_dia_exceso >= v_difdias then
                  v_can_dia_exceso := v_can_dia_exceso - v_difdias;
               else
                  v_can_dia_exceso := 0; -- para que no quede negativo
               end if;
               ---
               if v_can_dia_sobregiro > 0 and v_can_dia_sobregiro >= v_difdias then
                  v_can_dia_sobregiro := v_can_dia_sobregiro - v_difdias;
               else
                  v_can_dia_sobregiro := 0;  -- para que no quede negativo
               end if;
            end if;

            FOR k IN 0 .. v_difdias LOOP
               v_etapa := 'actualizacion historica';
               v_fec_aux := (v_fecinic + 1) + k;
               IF v_pos_ini_cta.EXISTS(v1_nrcuent) THEN
                  FOR j IN v_pos_ini_cta(v1_nrcuent) ..
                            v_pos_fin_cta(v1_nrcuent) LOOP
                     IF v_tab_hist(j).fecha = v_fec_aux THEN
                        v_tie_sob_fec_anterior := 'N';
                        if v_difdias > 0 then
                           IF v_can_hist_fec_ant > 1 THEN
                              RAISE TOO_MANY_ROWS;
                           ELSIF v_can_hist_fec_ant = 1 THEN
                              v_tie_sob_fec_anterior := 'S';
                           ELSE
                              v_can_dia_sobregiro := v_can_dia_sob_original;
                              v_can_dia_exceso := v_can_dia_exc_original;
                           END IF;
                        end if;

                        IF v_tab_hist(j).saldo <= v_tab_hist(j).mto_linea THEN
                           v_can_dia_exceso := 0;
                        END IF;

                        v_idx_act := v_act_id_reg.COUNT + 1;
                        v_act_id_reg.EXTEND;
                        v_act_nro_cta.EXTEND;
                        v_act_fec.EXTEND;
                        v_act_liq_orig.EXTEND;
                        v_act_can_dias.EXTEND;
                        v_act_can_dia_sob.EXTEND;
                        v_act_liq.EXTEND;
                        v_act_mto_lin.EXTEND;

                        v_act_id_reg(v_idx_act) := v_tab_hist(j).id_reg;
                        v_act_nro_cta(v_idx_act) := v_tab_hist(j).nro_cuenta;
                        v_act_fec(v_idx_act) := v_tab_hist(j).fecha;
                        v_act_liq_orig(v_idx_act) := v_tab_hist(j).liquidado;
                        v_act_can_dias(v_idx_act) := v_can_dia_exceso;
                        v_act_can_dia_sob(v_idx_act) := v_can_dia_sobregiro;
                        v_act_liq(v_idx_act) :=
                           CASE
                              WHEN v_can_dia_exceso >= v_dia_cargos THEN 'S'
                              ELSE 'N'
                           END;
                        v_act_mto_lin(v_idx_act) :=
                           CASE
                              WHEN v_tab_hist(j).saldo > v_tab_hist(j).mto_linea THEN 0
                              ELSE v_tab_hist(j).mto_linea
                           END;

                        IF (nvl(v_tab_hist(j).mto_linea, 0) > 0 AND
                            nvl(v_tab_hist(j).saldo, 0) >= 0) OR
                           v_can_dia_sobregiro > 0 THEN
                           v_can_dia_sobregiro := nvl(v_can_dia_sobregiro, 0) + 1;
                        END IF;
                        v_can_dia_exceso := v_can_dia_exceso + 1;
                     END IF;
                  END LOOP;
               END IF;
            END LOOP;

            --  si la cantidad de sobregiro es mayor a cero restar 1 porque al salir del loop
            --anterior suma un día demas
            IF v_can_dia_sobregiro > 0 THEN
               v_can_dia_sobregiro := v_can_dia_sobregiro - 1;
            END IF;
            IF v_can_dia_exceso > 0 then
               v_can_dia_exceso := v_can_dia_exceso - 1;
            END IF;
            v_idx_res := v_res_nro_cta.COUNT + 1;
            v_res_nro_cta.EXTEND;
            v_res_can_dias.EXTEND;
            v_res_sit_deuda.EXTEND;
            v_res_can_dia_sob.EXTEND;

            v_res_nro_cta(v_idx_res) := v1_nrcuent;
            v_res_can_dias(v_idx_res) := v_ttdiasg;
            v_res_sit_deuda(v_idx_res) := v_sitsald;
            v_res_can_dia_sob(v_idx_res) := nvl(v_can_dia_sobregiro, 0);
         END LOOP;

         IF v_act_id_reg.COUNT > 0 THEN
            v_etapa := 'FORALL UPDATE CC_SOBREGIROS';
            -- Un solo UPDATE masivo por lote reemplaza las actualizaciones fila por fila.
            FORALL i IN 1 .. v_act_id_reg.COUNT
               UPDATE cc_sobregiros
                  SET can_dias = v_act_can_dias(i),
                      can_dia_sobregiro = v_act_can_dia_sob(i),
                      liquidado = v_act_liq(i),
                      mto_linea = v_act_mto_lin(i)
                WHERE rowid = v_act_id_reg(i)
                  AND nro_cuenta = v_act_nro_cta(i)
                  AND fecha = v_act_fec(i)
                  AND liquidado = v_act_liq_orig(i);
         END IF;

         IF v_res_nro_cta.COUNT > 0 THEN
            v_etapa := 'FORALL INSERT CC_SOBREGIROS_RES';
            -- Un solo INSERT masivo por lote genera los resúmenes diarios.
            FORALL i IN 1 .. v_res_nro_cta.COUNT
               INSERT INTO cc_sobregiros_res
                      (nro_cuenta, can_dias, sit_deuda, can_dia_sobregiro)
               VALUES
                      (v_res_nro_cta(i),
                       v_res_can_dias(i),
                       v_res_sit_deuda(i),
                       v_res_can_dia_sob(i));
         END IF;
      END LOOP;
      IF cc_cta_corrientes%ISOPEN THEN
         CLOSE cc_cta_corrientes;
      END IF;
   EXCEPTION
      WHEN TOO_MANY_ROWS THEN
         raise_application_error(
            -20014,
            'TOO_MANY_ROWS en LP_CAL_SOB_DIARIO. Cuenta=' ||
            NVL(v1_nrcuent, '<NULL>') || ', etapa=' || v_etapa || ': ' || SQLERRM
         );
      WHEN OTHERS THEN
         raise_application_error(
            -20000,
            'ERROR. Calcular_dias. Cuenta=' || NVL(v1_nrcuent, '<NULL>') ||
            ', etapa=' || v_etapa || ': ' || SQLERRM
         );
   END;
   PROCEDURE lp_can_sob_anterior IS
      CURSOR mov IS
         SELECT DISTINCT hora
           FROM cc_movimientos_his
          WHERE fecha = v_fcanter
            AND cod_modulo = 4
            AND cod_modalidad = 41
            AND cod_transaccion IN (902, 909, 900, 912,
                                    -- sobregiro sin acuerdo,
                                    942, 949, 940, 952) -- sobregiro con acuerdo
            AND monto > 0
          ORDER BY hora;
   BEGIN
      --- inserto en ge_movimientos mov. inversos a los sobreg. del dia ant.--
      FOR reg IN mov LOOP
         INSERT INTO ge_movimientos
            (cod_modulo, cod_modalidad, cod_oficina, cod_moneda, cod_tra_padre, cod_transaccion,
             fecha, fec_valor, monto, estado, concepto, reversado, cod_mod_padre, cod_mad_padre,
             cod_usuario, hora, nro_secuencia, nro_cuenta, cod_ofi_origen)
            SELECT cod_modulo,
                   cod_modalidad,
                   cod_oficina,
                   cod_moneda,
                   cod_tra_padre,
                   cod_transaccion,
                   v_fcdehoy,
                   v_fcdehoy,
                   monto * -1,
                   estado,
                   'Cancelación Sobregiros',
                   reversado,
                   cod_mod_padre,
                   cod_mad_padre,
                   USER,
                   v_hora,
                   nro_secuencia,
                   nro_cuenta,
                   cod_ofi_origen
              FROM cc_movimientos_his
             WHERE fecha = v_fcanter
               AND hora = reg.hora
               AND cod_modulo = 4
               AND cod_modalidad = 41
               AND cod_transaccion IN (902, 909, 900, 912,
                                       -- sobregiro sin acuerdo,
                                       942, 949, 940, 952) -- sobregiro con acuerdo
               AND monto > 0
             ORDER BY nro_secuencia;
         --obtener sig segundo para el prox ciclo
         v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      END LOOP;
      --------------------------------------------------------------------
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR. Sobregiro_Cancelacion ' || SQLERRM);
   END;
   PROCEDURE lp_gen_cc_sobregiros IS
      v_fecauxi      DATE;
      v_fcanter      DATE;
      v_fcdehoy      date;
      v_fuldiha      date;
      v_fuldime      date;
      v_fecinic      date;
      v_fprdime      date;
      v_fprdiha      date;
      v_difdias      NUMBER(6);
      v_sal_total    cc_cta_corrientes.sal_total%TYPE;
      v_sal_retenido cc_cta_corrientes.sal_retenido%TYPE;
      v_exi_sobregiro varchar2(1);
      CURSOR cuentas IS
         SELECT nro_cuenta,
                v_fecauxi,
                abs(nvl(sal_total, 0) - nvl(sal_retenido, 0) - nvl(sal_bloqueado, 0)) saldo,
                sal_total,
                sal_retenido,
                cod_moneda
           FROM cc_cta_corrientes
          WHERE cod_modalidad = 41
            AND estado <> 'C'
            AND (v_usu_mig_excluir is null or usu_insercion <> v_usu_mig_excluir)
            AND nvl(sal_total, 0) - nvl(sal_retenido, 0) - nvl(sal_bloqueado, 0) < 0;
   BEGIN
      v_fcdehoy := rv_gcale.fec_actual;
      v_fcanter := rv_gcale.fec_anterior;
      v_fuldiha := rv_gcale.ult_dia_mes_habil;
      v_fuldime := rv_gcale.ult_dia_mes;
      v_fprdime := rv_gcale.pri_dia_mes;
      v_fprdiha := rv_gcale.pri_dia_mes_habil;
      -- calcula por cuantos dias tiene que agregar --
      if v_fcdehoy = v_fuldiha then
         v_difdias := round(v_fuldime - v_fcanter , 0) - 1;
         v_fecinic := v_fcanter;
      elsif v_fcdehoy = v_fprdiha then
         v_difdias := round(v_fprdiha - v_fprdime, 0);
         v_fecinic := v_fprdime - 1;
      else
         v_difdias := round(v_fcdehoy - v_fcanter , 0) - 1;
         v_fecinic := v_fcanter;

      end if;

      FOR i IN 0 .. v_difdias LOOP
         v_fecauxi := (v_fecinic + 1)  + i;
         FOR j IN cuentas LOOP
            IF j.sal_total < 0 THEN
               v_sal_total := abs(j.sal_total);
            ELSE
               v_sal_total := 0;
            END IF;
            v_sal_retenido := nvl(j.saldo, 0) - nvl(v_sal_total, 0);

            -- EP - N.AN. 2014-10-23 SC 9468 - ITGF - Dias de Mora de Cuenta Corriente
            -- controla si la cuenta ya tenia sobregiro en fecha anterior
            -- si no es asi, no corresponde insertar sabado, domingo o feriado
            if v_difdias > 0 then
              -- Se verifica si la cuenta tienen sobregiro el dia habil anterior
              v_tie_sob_fec_anterior := 'N';
              v_act_sobregiro := 'N';

              --DYDMR-DYDMR-1951 ITGF - Calculo de Sobregiro Mayo 2015 - EL CORRAL S.A. - SC 17012
              begin
                 -- select a cc_sobregiros para la cuenta al dia habil anterior
                select 'S', a.saldo, a.sal_total, a.sal_retenido, a.liquidado, a.mto_linea
                  into v_tie_sob_fec_anterior , v_aux_saldo, v_aux_sal_total, v_aux_sal_retenido, v_aux_liquidado, v_aux_mto_linea
                  from cc_sobregiros a
                 where a.nro_cuenta = j.nro_cuenta
                   and a.fecha = v_fecauxi -1;
              exception
                when no_data_found then
                     v_tie_sob_fec_anterior := 'N';
              end;

              -- el sobregiro de la cuenta inicia hoy (no tiene sobregiro dia anterior) insertar solo para hoy
              if v_tie_sob_fec_anterior = 'N' then
                if v_fecauxi = v_fcdehoy then
                  -- es fecha de hoy, se inserta
                   v_act_sobregiro := 'S';
                else
                   -- es fecha anterior, no corresponde insertar
                   v_act_sobregiro := 'N';
                end if;
              else
                -- la cuenta ya tenia sobregiro en fecha habil anterior
                -- se insertan para sabado, domingo y feriados
                v_act_sobregiro := 'S';
              end if;
         else
           v_act_sobregiro := 'S';
         end if;

         if  v_act_sobregiro = 'S' then
            ----------------------------------------
            --Validacion si ya existe algun registro
            ----------------------------------------
            v_exi_sobregiro := 'N';
            select decode(nvl(count(*),0),0,'N','S')
              into v_exi_sobregiro
              from cc_sobregiros x
             where nro_cuenta = j.nro_cuenta
               and fecha = v_fecauxi
               and liquidado = 'N';

            if v_exi_sobregiro = 'N' then
              if v_fecauxi <> v_fcdehoy then
                 if v_tie_sob_fec_anterior = 'S' then
                   BEGIN 
                     INSERT INTO cc_sobregiros
                         (nro_cuenta, fecha, saldo, sal_total, sal_retenido, liquidado, mto_linea)
                     VALUES
                         (j.nro_cuenta, v_fecauxi, v_aux_saldo, v_aux_sal_total, v_aux_sal_retenido, v_aux_liquidado, v_aux_mto_linea);
                   EXCEPTION 
                     WHEN DUP_VAL_ON_INDEX THEN--Por duplicacion de PK
                       prg_act_log_procesos(v_cod_programa,'LP_GEN_CC_SOBREGIROS1', v_fcdehoy, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),'Duplicacion de PK en CC_SOBREGIROS. Nro cuenta '||j.nro_cuenta||' fecha '||v_fecauxi||' liquidado ' ||v_aux_liquidado);
                   END;
                  end if;
              else
                BEGIN
                  INSERT INTO cc_sobregiros
                      (nro_cuenta, fecha, saldo, sal_total, sal_retenido, liquidado, mto_linea)
                  VALUES
                      (j.nro_cuenta, v_fecauxi, j.saldo, nvl(v_sal_total, 0), nvl(v_sal_retenido, 0), 'N',
                       nvl(pag_cta.fu_obt_lin_sobregiro(j.nro_cuenta, v_fcdehoy), 0));
                EXCEPTION
                  WHEN DUP_VAL_ON_INDEX THEN--Por duplicacion de PK
                    prg_act_log_procesos(v_cod_programa,'LP_GEN_CC_SOBREGIROS2', v_fcdehoy, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),'Duplicacion de PK en CC_SOBREGIROS. Nro cuenta '||j.nro_cuenta||' fecha '||v_fecauxi||' liquidado N');
                END;
             end if;
            else
                update cc_sobregiros x
                   set saldo = j.saldo,
                       sal_total = nvl(v_sal_total, 0),
                       sal_retenido = nvl(v_sal_retenido, 0),
                       mto_linea = nvl(pag_cta.fu_obt_lin_sobregiro(j.nro_cuenta, v_fcdehoy), 0)
                 where nro_cuenta = j.nro_cuenta
                   and fecha = v_fecauxi
                   and liquidado = 'N';
            end if;
          end if;
         END LOOP;
      END LOOP;
   END;

   --Función que habilita de vuelta la línea de sobregiro si se produjo un CLEAN-UP
   --(si el cliente pagó su exceso o pago su sobregiro)
   PROCEDURE lp_hab_lin_sobregiro IS
      CURSOR cu_cta_corrientes IS
         SELECT a.nro_cuenta,
                nvl(a.sal_total, 0) - nvl(a.sal_retenido, 0) - nvl(a.sal_bloqueado, 0) saldo,
                b.monto
           FROM cc_cta_corrientes a, cc_lin_sobregiros b
          WHERE a.nro_cuenta = b.nro_cuenta
            AND a.estado <> 'C'
            AND b.fec_vencimiento > v_fcdehoy
            AND (v_usu_mig_excluir is null or a.usu_insercion <> v_usu_mig_excluir)
            AND b.estado = 'V';

      CURSOR cu_sobregiros(p_nro_cuenta IN VARCHAR2) IS
         SELECT r.nro_cuenta, r.fecha, r.saldo, r.mto_linea
           FROM cc_sobregiros r
          WHERE r.fecha <= v_fcdehoy
            AND r.nro_cuenta = p_nro_cuenta
            AND EXISTS (SELECT 1
                          FROM cc_cta_corrientes c
                         WHERE cod_modulo = 4
                           AND cod_modalidad = 41
                           AND estado <> 'C'
                           AND c.nro_cuenta = r.nro_cuenta)
       ORDER BY 1 ASC, 2 DESC, 3 ASC;
      v_comfech    DATE;
      v_ttdiasg    NUMBER(06);
      v_cam_estado VARCHAR2(1);
   BEGIN
      v_comfech := v_fcdehoy;
      v_ttdiasg := 0;
      FOR a IN cu_cta_corrientes LOOP
         v_cam_estado := 'N';
         -- en este loop se busca la cantidad de dias en sobregiro
         FOR b IN cu_sobregiros(a.nro_cuenta) LOOP
            IF (v_comfech - b.fecha > 1) THEN
               EXIT;
            END IF;
            v_comfech := b.fecha;
            v_ttdiasg := nvl(v_ttdiasg, 0) + 1;
         END LOOP;
         IF a.saldo >= 0 THEN
            --cleanup
            v_cam_estado := 'S';
         ELSIF abs(a.saldo) <= a.monto /*AND v_ttdiasg < 31 */THEN
            --pago exceso dentro de los 30 dias
            v_cam_estado := 'S';
         END IF;
         -- habilito la linea de sobregiro
         IF v_cam_estado = 'S' THEN
            BEGIN
               lp_act_lin_sobregiro(a.nro_cuenta, 'A');
            EXCEPTION
               WHEN OTHERS THEN
                  RAISE_APPLICATION_ERROR(-20000, 'al actualizar. ' || SQLERRM);
            END;
         END IF;
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            RAISE_APPLICATION_ERROR(-20010, 'lp_hab_lin_sobregiros. ' || SQLERRM);
         END IF;
   END;

BEGIN
   v_usu_mig_excluir := fug_obt_pardinamico('COD_USU_MIG_EXCLUIR');
   v_cod_programa := 'PRC_GEN_SOBREGIROS';

   v_lugar   := 'Antes fecha rv_gcale';
   rv_gcale  := pag_cal.fu_obt_reg_cal(4);
   v_fcdehoy := rv_gcale.fec_actual;
   v_fcanter := rv_gcale.fec_anterior;
   v_fuldiha := rv_gcale.ult_dia_mes_habil;
   v_fuldime := rv_gcale.ult_dia_mes;
   v_fprdime := rv_gcale.pri_dia_mes;
   v_fprdiha := rv_gcale.pri_dia_mes_habil;

   v_lugar   := 'Truncate cc_sobregiros_res';
   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   -- Borro los datos antes de volver a generar, se hace al inicio para q no commitee nada
   sql_util.ejecute_dml('TRUNCATE TABLE CC_SOBREGIROS_RES', v_msj);
   IF v_msj IS NOT NULL THEN
      raise_application_error(-20000, v_msj);
   END IF;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(v_cod_programa,'Truncate cc_sobregiros_res', v_fcdehoy, v_hor_inicio, v_hor_fin);

   v_lugar   := 'Antes lp_hab_lin_sobregiro';
   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   -- nueva verificacion (habilita nuevamente las lineas de sobregiro)
   lp_hab_lin_sobregiro;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(v_cod_programa,'lp_hab_lin_sobregiro', v_fcdehoy, v_hor_inicio, v_hor_fin);

   v_lugar   := 'Antes lp_gen_cc_sobregiros';
   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   --genera cc_sobregiros
   lp_gen_cc_sobregiros;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(v_cod_programa,'lp_gen_cc_sobregiros', v_fcdehoy, v_hor_inicio, v_hor_fin);

   --inicializa hora para los movimientos
   v_lugar   := 'Inicializa hora para movimientos';
   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   v_hora := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(v_cod_programa,'fug_ini_hora', v_fcdehoy, v_hor_inicio, v_hor_fin);

   v_lugar   := 'Antes lp_cal_sob_diario';
   --calcula días de sobregiro y situación e inserta cc_sobregiros_res
   v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   lp_cal_sob_diario; --lp_cal_dia;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(v_cod_programa,'lp_cal_sob_diario', v_fcdehoy, v_hor_inicio, v_hor_fin);

EXCEPTION
  WHEN OTHERS THEN
      raise_application_error(-20005, v_lugar ||' - '|| sqlerrm);
END;
/
