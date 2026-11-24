CREATE OR REPLACE PROCEDURE IT.prx_gen_previsiones(p_nro_cuenta cx_previsiones.nro_cuenta%TYPE DEFAULT NULL) IS

   /*  Obtener garantía computable. */
   FUNCTION lf_obt_gar_computable
   (
      p_nro_cuenta IN cx_cta_importaciones.nro_cuenta%TYPE,
      p_tot_cash   OUT cx_cta_importaciones.monto%TYPE -- me indica si tiene un monto correspondiente a cash collateral para aplicar 100%.
   ) RETURN NUMBER;
   /* Obtener previsión anterior. */
   FUNCTION lf_obt_prv_ant
   (
      p_nro_cuenta IN cx_cta_importaciones.nro_cuenta%TYPE,
      p_fec_actual IN DATE,
      P_IND_PRI_SEM_CAT6  OUT cx_previsiones.ind_pri_sem_cat6%TYPE
   ) RETURN NUMBER;
   /* Obtener previsión de año anterior */
   FUNCTION lf_obt_prv_per_ant
   (
      p_nro_cuenta IN cx_cta_importaciones.nro_cuenta%TYPE,
      p_fec_actual IN DATE
   ) RETURN NUMBER;
   /* Obtener la categoría de previsión de clientes para categoría 1(Uno)*/
   FUNCTION lf_obt_cat_prevision(p_cod_persona IN ge_cla_operaciones.cod_persona%TYPE) RETURN NUMBER;
   /* Insertar registros en la tabla de previsiones de comex. */
   PROCEDURE lp_ins_prevision(rp_pprev IN cx_previsiones%ROWTYPE);
   /* Proceso de previsiones: Consideraciones a tener en cuenta con el análisis:
   - Debe tomar las operaciones que tienen algo previsionado o pueden previsionar en el sistema, es decir, desde el inicio y aun después de ser canceladas y aun tener previsión aplicada.
   - La previsión actual debe calcularse luego de la categorización, ya que se ve influido por este.
   - La previsión debe poder ajustar la previsión contable, esto afectar o desafectar previsiones de acuerdo a lo ya previsionado por la operación.
   - Debe mantenerse una tabla independiente de previsión para saber cuando se afectó o desafectó a una fecha dada.
   - Para las operaciones de Comex la previsión se realiza sólo si el cliente tiene categoría ponderada 2 en adelante.
   Secuencia de Procesos
   - Categorización
   - Previsión */
   v_fec_actual       ge_calendarios.fec_actual%TYPE;
   v_cod_mon_local    ba_monedas.cod_moneda%TYPE;
   v_riesgo1a         pr_parametros.por_riesgo_1a%TYPE;
   v_riesgo1b         pr_parametros.por_riesgo_1b%TYPE;
   v_riesgo2          pr_parametros.por_riesgo_2%TYPE;
   v_riesgo3          pr_parametros.por_riesgo_3%TYPE;
   v_riesgo4          pr_parametros.por_riesgo_4%TYPE;
   v_riesgo5          pr_parametros.por_riesgo_5%TYPE;
   v_riesgo6          pr_parametros.por_riesgo_6%TYPE;
   v_garantia         cx_cta_garantias.mto_apl_computable%TYPE;
   v_redondeo         NUMBER(2);
   v_prevision        cx_previsiones.monto%TYPE;
   v_prv_anterior     cx_previsiones.monto%TYPE;
   v_diferencia       cx_previsiones.monto%TYPE;
   v_prv_per_anterior cx_previsiones.monto%TYPE;
   v_dif_prevision    cx_previsiones.monto%TYPE;
   r_pprev            cx_previsiones%ROWTYPE;
   r_gmovi            ge_movimientos%ROWTYPE;
   v_nro_secuencia    ge_movimientos.nro_secuencia%TYPE;
   v_hora             ge_movimientos.hora%TYPE;
   v_neto             ge_cla_operaciones.tot_deu_real%TYPE;
   v_cat_prev         ge_clientes.cat_automatica%TYPE;
   v_tot_cash         cx_cta_garantias.mto_apl_computable%TYPE; -- total de garantías tipo cash collateral
   v_tot_apl          cx_cta_garantias.mto_con_computable%TYPE; -- saldo de riesgo a previsionar
   v_por_prev_clie    NUMBER(5, 2);
   v_pri_prevision    cx_previsiones.tot_pri_prevision%TYPE;
   v_dias_cat         NUMBER(10);
   v_por_prevision    NUMBER(18, 2);
   v_por_previsionado pr_previsiones.porcentaje%type;
   v_por_pri_semestre pr_previsiones.porcentaje%type;
   v_por_calculado pr_previsiones.porcentaje%type;
   v_ind_pri_sem_cat6 pr_previsiones.ind_pri_sem_cat6%type;
   v_ind_pri_sem_cat6_ant pr_previsiones.ind_pri_sem_cat6%type;


   --- Cursor de operaciones de Comercio Exterior a calcular
   CURSOR c_comex IS
      SELECT i.nro_cuenta,
             nvl(i.saldo, 0) - nvl(fux_obt_sal_mto_utilizado(i.nro_cuenta), 0) saldo,
             i.cod_moneda,
             c.cod_persona,
             c.cat_riesgo,
             c.cat_automatica,
             i.cod_modalidad,
             i.cod_oficina,
             i.fec_cancelacion,
             i.cod_modulo,
             c.cod_gru_economico,
             i.estado estado,
             i.est_batch,
             o.cat_ren_anterior,
             o.lib_prevision,
             nvl(i.monto, 0) monto,
             nvl(i.mto_utilizado, 0) mto_utilizado,
             c.fec_ult_clasif
        FROM ge_clientes c, ge_cta_clientes cc, cx_cta_importaciones i, ge_cla_operaciones o
       WHERE i.nro_cuenta = cc.nro_cuenta
         AND o.nro_cuenta(+) = i.nro_cuenta
         AND cc.relacion = 'P'
         AND cc.cod_persona = c.cod_persona
         AND (i.nro_cuenta = p_nro_cuenta OR p_nro_cuenta IS NULL)
         AND i.estado NOT IN ('S') -- solicitada
         AND (i.estado <> 'C' OR i.fec_cancelacion = v_fec_actual OR
             (i.estado = 'C' AND trunc(i.fec_modificacion) = v_fec_actual))
      UNION
      SELECT f.nro_cuenta,
             nvl(f.monto, 0) saldo,
             f.cod_moneda,
             c.cod_persona,
             c.cat_riesgo,
             c.cat_automatica,
             f.cod_modalidad,
             f.cod_oficina,
             f.fec_cancelacion,
             f.cod_modulo,
             c.cod_gru_economico,
             f.estado estado,
             f.est_batch,
             o.cat_ren_anterior,
             o.lib_prevision,
             nvl(f.monto, 0),
             0 mto_utilizado,
             c.fec_ult_clasif
        FROM ge_clientes c, ge_cta_clientes cc, cx_fianzas f, ge_cla_operaciones o
       WHERE f.nro_cuenta = cc.nro_cuenta
         AND o.nro_cuenta(+) = f.nro_cuenta
         AND cc.relacion = 'P'
         AND cc.cod_persona = c.cod_persona
         AND (f.nro_cuenta = p_nro_cuenta OR p_nro_cuenta IS NULL)
         AND f.contragarantia = 'N' -- ICL 22/03/12: Mail HB
         AND f.estado NOT IN ('S') -- solicitada
         AND (f.estado <> 'C' OR f.fec_cancelacion = v_fec_actual OR
             (f.estado = 'C' AND trunc(f.fec_modificacion) = v_fec_actual))
         AND f.monto > 0;

   /* Obtener garantía computable. */
   FUNCTION lf_obt_gar_computable
   (
      p_nro_cuenta IN cx_cta_importaciones.nro_cuenta%TYPE,
      p_tot_cash   OUT cx_cta_importaciones.monto%TYPE -- me indica si tiene un monto correspondiente a cash collateral para aplicar 100%.
   ) RETURN NUMBER IS
      v_gar_compu cx_cta_garantias.mto_apl_computable%TYPE := 0;
      v_gar_cash  cx_cta_garantias.mto_con_computable%TYPE := 0;
      v_tot_gara  cx_cta_garantias.mto_apl_computable%TYPE := 0;
      v_cot_aux   ge_cotizaciones.val_conversion%TYPE;
      CURSOR c_garantias IS
         SELECT g.mto_apl_computable, t.cod_garantia
           FROM cx_cta_garantias g, pr_gar_tipos t
          WHERE g.nro_cuenta = p_nro_cuenta
            AND g.cod_garantia = t.cod_garantia
            AND t.computable = 'S'
            AND nvl(g.mto_apl_computable, 0) > 0;
   BEGIN
      v_tot_gara := 0;
      FOR reg IN c_garantias LOOP
         v_cot_aux   := NULL;
         v_gar_compu := nvl(reg.mto_apl_computable, 0);
         --- totalizar garantías computables en moneda de la cuenta ---------
         v_tot_gara := nvl(v_tot_gara, 0) + nvl(v_gar_compu, 0);
         IF reg.cod_garantia IN (5, 19, 21) THEN
            v_gar_cash := v_gar_cash + nvl(v_gar_compu, 0);
         END IF;
         p_tot_cash := v_gar_cash;
      END LOOP;
      RETURN v_tot_gara;
   END;
   /* Obtener Previsión anterior. */
   FUNCTION lf_obt_prv_ant
   (
      p_nro_cuenta IN cx_cta_importaciones.nro_cuenta%TYPE,
      p_fec_actual IN DATE,
      P_IND_PRI_SEM_CAT6  OUT cx_previsiones.ind_pri_sem_cat6%TYPE
   ) RETURN NUMBER IS
      v_monto cx_previsiones.monto%TYPE;
   BEGIN
      SELECT SUM(nvl(monto, 0)), ind_pri_sem_cat6
        INTO v_monto,P_IND_PRI_SEM_CAT6
        FROM cx_previsiones
       WHERE nro_cuenta = p_nro_cuenta
         AND fecha = (SELECT MAX(fecha)
                        FROM cx_previsiones
                       WHERE nro_cuenta = p_nro_cuenta
                         AND fecha <= p_fec_actual)
      GROUP BY ind_pri_sem_cat6;
      RETURN v_monto;
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       RETURN 0;
   END;
   /* Obtener Previsión año anterior */
   FUNCTION lf_obt_prv_per_ant
   (
      p_nro_cuenta IN cx_cta_importaciones.nro_cuenta%TYPE,
      p_fec_actual IN DATE
   ) RETURN NUMBER IS
      v_monto cx_previsiones.monto%TYPE;
   BEGIN
      SELECT nvl(SUM(monto), 0)
        INTO v_monto
        FROM cx_previsiones
       WHERE nro_cuenta = p_nro_cuenta
         AND fecha = (SELECT MAX(fecha)
                        FROM cx_previsiones
                       WHERE nro_cuenta = p_nro_cuenta
                         AND fecha <= trunc(p_fec_actual, 'year'))
         AND NOT EXISTS (SELECT 1
                FROM cx_previsiones
               WHERE nro_cuenta = p_nro_cuenta
                 AND fecha >= trunc(p_fec_actual, 'year')
                 AND monto = 0);
      RETURN v_monto;
   EXCEPTION
      WHEN OTHERS THEN
         v_monto := 0;
         RETURN v_monto;
   END;
   /* Obtener Desafectación anterior */
   FUNCTION lf_obt_des_ant
   (
      p_nro_cuenta IN cx_cta_importaciones.nro_cuenta%TYPE,
      p_fec_actual IN DATE
   ) RETURN NUMBER IS
      v_monto cx_previsiones.monto%TYPE;
   BEGIN
      SELECT nvl(SUM(tot_desafectacion), 0)
        INTO v_monto
        FROM cx_previsiones
       WHERE nro_cuenta = p_nro_cuenta
         AND fecha >= trunc(p_fec_actual, 'year');

      RETURN v_monto;
   END;
   /* Obtener la categoría de previsión de clientes para categoría 1(Uno)*/
   FUNCTION lf_obt_cat_prevision(p_cod_persona IN ge_cla_operaciones.cod_persona%TYPE) RETURN NUMBER AS
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

   /* Insertar registros en la tabla de previsiones de comex. */
   PROCEDURE lp_ins_prevision(rp_pprev IN cx_previsiones%ROWTYPE) IS
   BEGIN
      INSERT INTO cx_previsiones
         (fecha, nro_cuenta, monto, saldo, porcentaje, tot_gar_computable, tot_pri_prevision,
          mto_pre_anterior, por_pre_anterior, por_calculado, ind_pri_sem_cat6)
      VALUES
         (rp_pprev.fecha, rp_pprev.nro_cuenta, rp_pprev.monto, rp_pprev.saldo, rp_pprev.porcentaje,
          rp_pprev.tot_gar_computable, rp_pprev.tot_pri_prevision,
          rp_pprev.mto_pre_anterior, rp_pprev.por_pre_anterior, rp_pprev.por_calculado, rp_pprev.ind_pri_sem_cat6);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Ins.Prev. ' || SQLERRM);
   END;
BEGIN
   v_fec_actual    := pag_cal.fu_obt_fec_actual(6);
   v_hora          := fug_ini_hora(SYSDATE);
   v_cod_mon_local := pag_gen.fu_obt_mon_local;

   BEGIN
      SELECT por_riesgo_1a,
             por_riesgo_1b,
             por_riesgo_2,
             por_riesgo_3,
             por_riesgo_4,
             por_riesgo_5,
             por_riesgo_6
        INTO v_riesgo1a, v_riesgo1b, v_riesgo2, v_riesgo3, v_riesgo4, v_riesgo5, v_riesgo6
        FROM pr_parametros
       WHERE rownum = 1;
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000, 'Parámetros de riesgos no definidos');
   END;
   v_nro_secuencia := 0;
   FOR reg IN c_comex LOOP
      v_cat_prev      := reg.cat_riesgo;
      v_prevision     := 0;
      v_pri_prevision := 0;
      v_por_prev_clie := 0;
      v_tot_cash      := 0;

      v_garantia := lf_obt_gar_computable(reg.nro_cuenta, v_tot_cash);

      ---
      IF v_cat_prev = 2 THEN
         v_por_prev_clie := v_riesgo2;
      ELSIF v_cat_prev = 3 THEN
         v_por_prev_clie := v_riesgo3;
      ELSIF v_cat_prev = 4 THEN
         v_por_prev_clie := v_riesgo4;
      ELSIF v_cat_prev = 5 THEN
         v_por_prev_clie := v_riesgo5;
      ELSIF v_cat_prev = 6 THEN
         v_por_prev_clie := v_riesgo6;
      ELSE
         v_por_prev_clie := 0;
      END IF;
      --- Tomar la mayor previsión como porcentaje
      v_por_prevision := v_por_prev_clie;

      --- REALIZAR PRIMERA PREVISIÓN
      --- Aplicar el 50% de la previsión obtenida al neto
      v_por_prevision := v_por_prevision / 2;
      --- Obtener el importe del saldo para la primera previsión.
      v_tot_apl := nvl(reg.saldo, 0);
      --
      IF v_tot_cash > 0 THEN
         -- si tiene garantía cash
         IF v_tot_cash >= v_tot_apl THEN
            -- el cash es mayor que la deuda, cubre todo
            v_tot_apl  := 0;
            v_garantia := v_garantia - v_tot_apl; -- restar lo utilizado
         ELSE
            -- la deuda es mayor que el cash
            v_tot_apl  := v_tot_apl - v_tot_cash;
            v_garantia := v_garantia - v_tot_cash; -- restar el cash de la garantía total
         END IF;
      END IF; -- si no tiene cash, el total aplicar es la deuda total
      -- hallar primera previsión s/ el saldo a aplicar
      -- BBVADES 1257 agregar redondeo
      v_redondeo  := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', reg.cod_modulo,
                                             reg.cod_modalidad, reg.cod_moneda), 0);
      v_prevision := round(nvl(v_tot_apl, 0) * v_por_prevision / 100, v_redondeo);

      --- HALLAR VALOR COMPUTABLE DE LA GARANTÍA
      IF nvl(v_garantia, 0) = 0 AND nvl(v_tot_cash, 0) = 0 THEN
         --- Según modificación a Res. 8 IX. Regímenes de previsiones Inc. 29.
         --- Esta metodología de cálculo no se aplicará cuando las cartas de Comercio Exterior carezcan de garantía
         --- en cuyo caso el % de previsión se aplicará sobre el saldo total de la deuda
         v_prevision     := 0;
         v_por_prevision := v_por_prevision * 2;
      ELSE
         IF v_cat_prev = 6 THEN
            v_por_prevision := v_por_prevision * 2;
         END IF;
      END IF;
      v_pri_prevision := v_prevision;
      --- REALIZAR SEGUNDA PREVISIÓN
      v_neto := nvl(reg.saldo, 0) - nvl(v_garantia, 0) - nvl(v_tot_cash, 0) - v_prevision;
      ---
      IF v_neto < 0 THEN
         v_neto := 0;
      END IF;
      --- Calcular cantidad de días desde la última clasificación
      --- Recuperar previsión anterior si la tuviere
      v_prv_anterior     := lf_obt_prv_ant(reg.nro_cuenta, v_fec_actual, v_ind_pri_sem_cat6_ant);

      v_dias_cat := v_fec_actual - reg.fec_ult_clasif;
      IF reg.cat_riesgo = 6 AND v_garantia > 0 AND v_dias_cat >= 545 THEN --545 = 365 días (que está en la categoría 6) + 180 días (1 semestre)
         --- Previsiones Genéricas - Solo si tiene garantía
         v_por_previsionado := 0;
         v_prv_anterior := lf_obt_prv_ant(reg.nro_cuenta, v_fec_actual, v_ind_pri_sem_cat6_ant);
         v_ind_pri_sem_cat6 := v_ind_pri_sem_cat6_ant;
         v_por_previsionado := round(nvl(v_prv_anterior, 0)/reg.saldo * 100,2);
         if v_dias_cat >= 725 then -- 725= 365 días (que está en la categoría 6) + 360 días (2 semestres de 180 días cada 1)
            -- al año tengo que previsionar el 100% de la deuda
            --- Se debe previsionar el 100% de la deuda
            v_prevision     := reg.saldo;
            v_por_prevision := 100;
            v_por_calculado := 100;
         --545 = 365 días (que está en la categoría 6) + 180 días (1 semestre)
         elsif v_dias_cat >= 545 and nvl(v_ind_pri_sem_cat6, 'N') = 'N' then
            -- a los 6 primeros meses tengo que previsionar 25% mas es decir 75% de la deuda
            v_por_pri_semestre := 100 - v_por_previsionado;
            if v_por_pri_semestre > 25 then
               v_por_pri_semestre := v_por_pri_semestre -25;
            end if;

            v_por_calculado := nvl(v_por_previsionado, 0) + nvl(v_por_pri_semestre, 0);
              
            if v_por_calculado = 100 then
               v_prevision := reg.saldo;
            else 
               v_prevision := round(v_prv_anterior + (nvl(reg.saldo,0)* v_por_pri_semestre/100),v_redondeo);
            end if;
            
            v_por_prevision := 100;
            v_ind_pri_sem_cat6 := 'S';
         END IF;
      ELSE
         v_por_previsionado := null;
         v_por_calculado := null;
         v_ind_pri_sem_cat6 := null;

         v_prevision := v_prevision + round(nvl(v_neto, 0) * v_por_prevision / 100, v_redondeo);
      END IF;
      v_prv_per_anterior := lf_obt_prv_per_ant(reg.nro_cuenta, v_fec_actual) -
                            lf_obt_des_ant(reg.nro_cuenta, v_fec_actual);
      v_diferencia       := 0;
      v_dif_prevision    := 0;

      --- Inicializar datos cabecera del movimiento
      r_gmovi.cod_usuario    := USER;
      r_gmovi.hora           := v_hora;
      r_gmovi.fecha          := v_fec_actual;
      r_gmovi.fec_valor      := v_fec_actual;
      r_gmovi.cod_mod_padre  := reg.cod_modulo;
      r_gmovi.cod_mad_padre  := reg.cod_modalidad;
      r_gmovi.cod_modulo     := reg.cod_modulo;
      r_gmovi.cod_modalidad  := reg.cod_modalidad;
      r_gmovi.cod_oficina    := reg.cod_oficina;
      r_gmovi.cod_ofi_origen := reg.cod_oficina;
      r_gmovi.cod_moneda     := reg.cod_moneda;
      r_gmovi.estado         := 'N';
      r_gmovi.reversado      := 'N';
      r_gmovi.emi_aviso      := 'N';
      r_gmovi.protegido      := 'N';
      r_gmovi.nro_cuenta     := reg.nro_cuenta;
      r_gmovi.est_cuenta     := reg.estado;
      IF v_nro_secuencia + 2 > 999 THEN
         v_nro_secuencia := 0;
         v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
         r_gmovi.hora    := v_hora;
      END IF;
      IF reg.fec_cancelacion IS NOT NULL THEN
         v_prevision := 0;
      END IF;
      v_diferencia := nvl(v_prevision, 0) - nvl(v_prv_anterior, 0);

      IF abs(v_diferencia) >= nvl(v_prv_per_anterior, 0) AND nvl(v_prv_per_anterior, 0) != 0 THEN
         v_dif_prevision := nvl(v_prv_per_anterior, 0);
      ELSIF abs(v_diferencia) < nvl(v_prv_per_anterior, 0) AND nvl(v_prv_per_anterior, 0) != 0 THEN
         v_dif_prevision := abs(v_diferencia);
      ELSIF nvl(v_prv_per_anterior, 0) = 0 THEN
         v_dif_prevision := 0;
      ELSE
         v_dif_prevision := nvl(v_prv_anterior, 0) - nvl(v_prv_per_anterior, 0);
      END IF;

      if reg.cat_riesgo = 6 and v_dias_cat between 545 and 724 and v_garantia > 0
         and nvl(v_ind_pri_sem_cat6, 'N') = 'S' and nvl(v_ind_pri_sem_cat6_ant, 'N') = nvl(v_ind_pri_sem_cat6, 'N') then
         v_diferencia := 0;
      end if;

      r_gmovi.monto := nvl(v_diferencia, 0);
      IF v_diferencia <> 0 THEN
         --- Insertar previsión
         r_pprev.nro_cuenta         := reg.nro_cuenta;
         r_pprev.fecha              := v_fec_actual;
         r_pprev.monto              := nvl(v_prevision, 0);
         r_pprev.saldo              := nvl(reg.saldo, 0);
         r_pprev.porcentaje         := nvl(v_por_prevision, 0);
         r_pprev.tot_gar_computable := nvl(v_garantia, 0);
         r_pprev.tot_pri_prevision  := nvl(v_pri_prevision, 0);
         r_pprev.mto_pre_anterior := nvl(v_prv_anterior,0);
         r_pprev.por_pre_anterior := nvl(v_por_previsionado,0);
         r_pprev.por_calculado := nvl(v_por_calculado,0);
         r_pprev.ind_pri_sem_cat6 := v_ind_pri_sem_cat6;

         lp_ins_prevision(r_pprev);
         IF v_diferencia < 0 THEN
            IF abs(v_diferencia) >= abs(v_dif_prevision) THEN
               --- Desafectar previsiones
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.monto           := nvl(abs(v_dif_prevision), 0);
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.cod_tra_padre   := 757;
               r_gmovi.cod_transaccion := 7757;
               r_gmovi.concepto        := 'DESAFECTACION DE PREVISION';
               IF r_gmovi.monto != 0 THEN
                  pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
                  --Actualizar en cx_previsiones el campo de desafectación.
                  UPDATE cx_previsiones
                     SET tot_desafectacion = nvl(abs(v_dif_prevision), 0)
                   WHERE nro_cuenta = p_nro_cuenta
                     AND fecha = (SELECT MAX(fecha)
                                    FROM cx_previsiones
                                   WHERE nro_cuenta = p_nro_cuenta
                                     AND fecha <= v_fec_actual);
               END IF;
               --- Reversar previsiones
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.monto           := (nvl(v_diferencia * -1, 0) - nvl(abs(v_dif_prevision), 0));
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.cod_tra_padre   := 757;
               r_gmovi.cod_transaccion := 757;
               r_gmovi.concepto        := 'EXTORNO DE PREVISION';
               IF r_gmovi.monto != 0 THEN
                  pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
               END IF;
            ELSE
               --- Reversar previsiones
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.monto           := nvl(v_diferencia * -1, 0);
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.cod_tra_padre   := 757;
               r_gmovi.cod_transaccion := 757;
               r_gmovi.concepto        := 'EXTORNO DE PREVISION';
               IF r_gmovi.monto != 0 THEN
                  pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
               END IF;
            END IF;
         ELSIF v_diferencia > 0 THEN
            --- Constituir previsiones
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.cod_tra_padre   := 756;
            r_gmovi.cod_transaccion := 756;
            r_gmovi.concepto        := 'CONSTITUCION DE PREVISION';
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
         END IF;
      END IF;
      UPDATE ge_cla_operaciones
         SET tot_prevision     = pag_gen.fu_con_mon_a_moneda(cod_moneda, v_cod_mon_local,
                                                             nvl(v_prevision, 0)),
             tot_pri_prevision = pag_gen.fu_con_mon_a_moneda(cod_moneda, v_cod_mon_local,
                                                             nvl(v_pri_prevision, 0)),
             tot_cap_pri_prevision = pag_gen.fu_con_mon_a_moneda(cod_moneda, v_cod_mon_local,nvl(v_pri_prevision,0)),
             tot_cap_seg_prevision = pag_gen.fu_con_mon_a_moneda(cod_moneda, v_cod_mon_local,
                                                                                             (nvl(v_prevision,0) -  nvl(v_pri_prevision,0))),
             tot_int_pri_prevision = 0,
             tot_int_seg_prevision = 0
       WHERE nro_cuenta = reg.nro_cuenta;

   END LOOP;
END;
/

