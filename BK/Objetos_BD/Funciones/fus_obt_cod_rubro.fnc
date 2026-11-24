CREATE OR REPLACE FUNCTION IT.fus_obt_cod_rubro
   (
   p_nro_cuenta  IN VARCHAR2,
   p_sal_buscado IN VARCHAR2
   ) RETURN VARCHAR2 IS
   v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
   v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
   v_ind_deudor       ge_tip_asientos.ind_deudor%TYPE;
   v_ind_plazo        ge_tip_asientos.ind_plazo%TYPE;
   v_ind_producto     ge_tip_asientos.ind_producto%TYPE;
   p_cod_rubro        ge_tip_asientos.cod_rubro%TYPE;
   v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
   v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
   v_fec_vencimiento  ge_cuentas.fec_vencimiento%TYPE;
   v_fec_apertura     ge_cuentas.fec_apertura%TYPE;
   ---
   v_cod_modulo       ba_modulos.cod_modulo%TYPE;
   v_cod_modalidad    ge_modalidades.cod_modalidad%TYPE;
   v_cod_moneda       ba_monedas.cod_moneda%type;
   v_cod_sit_contable ge_cuentas.cod_sit_contable%TYPE;
   v_est_cuenta       ge_cuentas.estado%TYPE;

   v_cod_sec_contable ge_clientes.cod_sec_contable%TYPE;
   v_cod_tip_deudor   ge_clientes.cod_tip_deudor%TYPE;
   v_residente        ge_clientes.residente%TYPE;
   v_cat_automatica   ge_clientes.cat_riesgo%TYPE;

   v_tip_cuenta       pr_cta_prestamos.tipo%type;
   v_tip_renovacion   pr_cta_prestamos.tip_renovacion%type;
   v_tip_interes      pr_cta_prestamos.tip_interes%type;
   v_cod_sec_credito  pr_cta_prestamos.cod_sec_credito%type;

   v_cod_transaccion  ge_transacciones.cod_transaccion%type;
   v_tip_movimiento   varchar2(1);

   p_rubro varchar2(1);

   v_sit_deuda           cc_sobregiros_res.sit_deuda%TYPE;
   v_sal_capital         cc_cta_corrientes.sal_total%TYPE;
   v_tip_operacion       varchar2(40);

   v_rub_con_pignorado   sb_crc_saldos_det.rub_con_capital%TYPE;
   v_tip_ope_cta_cte     VARCHAR2(1);
   v_tip_ope_pignorado   VARCHAR2(1);
   v_sob_con_acuerdo     NUMBER(22,2);
   v_mto_lin_sobregiro   NUMBER(22,2);

   v_cod_rubro           cb_sal_inventarios.cod_rubro%type;
   rg_pcpre              pr_cta_prestamos%rowtype;

   FUNCTION fu_obt_rub_con_tipo
   (
      p_nro_cuenta IN VARCHAR2,
      p_tip_saldo  IN VARCHAR2,
      p_tip_ope    IN VARCHAR2,
      p_sit_deuda  IN VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2 IS
      v_cod_rubro cb_rubros.cod_rubro%TYPE;
   BEGIN
      SELECT a.cod_rubro
        INTO v_cod_rubro
        FROM cb_sal_inventarios a, cb_sal_inventarios_det d
       WHERE a.nro_referencia = d.nro_referencia
         AND d.nro_cuenta = p_nro_cuenta
         AND a.tip_saldo = p_tip_saldo
         AND substr(a.cod_rubro, 6, 3) = p_tip_ope
         AND (p_sit_deuda IS NULL OR a.situacion = p_sit_deuda);
      RETURN v_cod_rubro;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   -- Funci?n para obtener el valor del tipo de operaci?n.
   FUNCTION fu_obt_tip_operacion( p_tip_operacion IN sb_crc_saldos_det.tip_operacion%TYPE,
                                  p_domino        IN ba_cod_referencias.dominio%TYPE ) RETURN VARCHAR2 IS
      v_es_tip_operacion VARCHAR2(1) := 'N';
   BEGIN
      SELECT decode(nvl(COUNT(*), 0), 0, 'N', 'S')
        INTO v_es_tip_operacion
        FROM ba_cod_referencias x
       WHERE x.dominio = p_domino
         AND x.val_minimo = p_tip_operacion;
      RETURN(v_es_tip_operacion);
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 'S';
   END;

   FUNCTION lf_obt_sal_bloqueado(p_nro_cuenta IN cc_cta_corrientes.nro_cuenta%TYPE)
        RETURN NUMBER IS
        v_sal_bloqueado sb_crc_saldos_det.sal_capital%TYPE;
      BEGIN
        SELECT SUM(NVL(gb.monto, 0))
          INTO v_sal_bloqueado
          FROM ge_bloqueos     gb,
               ge_embargos_det ged
         WHERE gb.nro_cuenta = ged.nro_cuenta
           AND gb.nro_documento = ged.cod_embargo
           AND gb.nro_cuenta = p_nro_cuenta;
          RETURN v_sal_bloqueado;
      EXCEPTION
        WHEN no_data_found THEN
          RETURN 0;
        WHEN OTHERS THEN
          RETURN 0;
      END;
   --- P/ QUERY 10 ---
BEGIN
   /*Busco datos del Cliente*/
   SELECT fec_vencimiento, fec_apertura,
          cod_modulo, cod_modalidad, cod_moneda,
          cod_sit_contable, estado
     INTO v_fec_vencimiento, v_fec_apertura,
          v_cod_modulo, v_cod_modalidad, v_cod_moneda,
          v_cod_sit_contable, v_est_cuenta
     FROM ge_cuentas
    WHERE nro_cuenta = p_nro_cuenta;
   ---
   if p_sal_buscado = 'X' then
      --- Venta de Cartera ---
      IF v_cod_modulo = 6 then
        pap_pre.pr_obt_dat_prestamo(p_nro_cuenta,rg_pcpre);
        v_sit_deuda     := rg_pcpre.est_batch;
      ELSIF v_cod_modulo != 15 then
        pag_cta.pr_obt_cuenta(p_nro_cuenta);
        v_sit_deuda     := pag_cta.g_ctas.est_batch;
      ELSE
        BEGIN
          select a.est_batch
            into v_sit_deuda
            from ov_cta_vencidas a
           where a.nro_cuenta = p_nro_cuenta;
        END;
      END IF;
      BEGIN
         SELECT a.cod_rubro
           INTO v_cod_rubro
           FROM cb_sal_inventarios a, cb_sal_inventarios_det d
          WHERE a.nro_referencia = d.nro_referencia
            AND d.nro_cuenta = p_nro_cuenta
            AND a.situacion = v_sit_deuda
            AND a.tip_operacion = 'D';
         RETURN v_cod_rubro;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            BEGIN
               SELECT a.cod_rubro
                 INTO v_cod_rubro
                 FROM cb_sal_inventarios a, cb_sal_inventarios_det d
                WHERE a.nro_referencia = d.nro_referencia
                  AND d.nro_cuenta = p_nro_cuenta
                  AND a.tip_operacion = 'D';
               RETURN v_cod_rubro;
            EXCEPTION
               WHEN OTHERS THEN
                  RETURN NULL;
            END;
         WHEN OTHERS THEN
            RETURN NULL;
      END;
   end if;

   v_cod_plazo := fug_obt_plz_contable(nvl(v_fec_vencimiento - v_fec_apertura, 0));

   SELECT b.cod_sec_contable, b.cod_tip_deudor, b.residente, b.cat_riesgo
     INTO v_cod_sec_contable, v_cod_tip_deudor, v_residente, v_cat_automatica
     FROM ge_cta_clientes g, ge_clientes b
    WHERE g.nro_cuenta = p_nro_cuenta
      AND b.cod_persona = g.cod_persona
      AND g.relacion = 'P';

   if v_cod_modulo = 6 then
      SELECT a.tipo, a.tip_renovacion, a.tip_interes, a.cod_sec_credito
        INTO v_tip_cuenta, v_tip_renovacion, v_tip_interes, v_cod_sec_credito
        FROM pr_cta_prestamos a
       WHERE a.nro_cuenta = p_nro_cuenta;

      v_cod_transaccion := pap_pre.fu_obt_tra_concepto('CA', v_est_cuenta, v_tip_cuenta, v_tip_interes, v_tip_renovacion);
      v_tip_movimiento  := 'C';

   elsif v_cod_modulo = 3 then
      if v_cod_modalidad = 31 then
         select decode(nvl(a.cta_combinada, 'N'), 'S', 682, 602)
           into v_cod_transaccion
           from ah_cta_vistas a
          WHERE a.nro_cuenta = p_nro_cuenta;
      elsif v_cod_modalidad in (33,36) then
         select decode(a.estado,'V',604,602)
           into v_cod_transaccion
           from ah_cta_certificados a
          WHERE a.nro_cuenta = p_nro_cuenta;
      elsif v_cod_modalidad in (37,38) then
         select decode(a.estado,'V',604,602)
           into v_cod_transaccion
           from ah_cta_plazos a
          WHERE a.nro_cuenta = p_nro_cuenta;
      end if;
      v_tip_movimiento  := 'C';
   elsif v_cod_modulo = 5 then
      if nvl(p_sal_buscado,'C') = 'C' then
         IF v_est_cuenta = 'N' THEN
            v_cod_transaccion := 690; --normal
         ELSIF (v_est_cuenta = 'V') THEN
            v_cod_transaccion := 923; --vencidas
         ELSIF (v_est_cuenta = 'G') THEN
            v_cod_transaccion := 921; --en gestion
         ELSIF (v_est_cuenta = 'M') THEN
            v_cod_transaccion := 922; --morosas
         ELSIF (v_est_cuenta = 'C') then
            v_cod_transaccion := 1506; --vigentes
         /*ELSE
            rp_gcsal.rub_con_capital := i.cta_con_cap_original; */--- canceladas
         END IF;
         v_tip_movimiento  := 'C';
      elsif nvl(p_sal_buscado,'C') = 'O' then --- rub_con_contingencia
         v_cod_transaccion := 224;
         v_tip_movimiento  := 'D';
      end if;
   elsif v_cod_modulo = 4 then
      begin
         SELECT i.cod_rubro
           into v_cod_rubro
           FROM cb_sal_inventarios_det d, cb_sal_inventarios i
          WHERE d.nro_cuenta = p_nro_cuenta
            and i.nro_referencia = d.nro_referencia
            AND i.tip_saldo = 'C'
            and i.situacion <> 'N'
            --AND fu_obt_tip_operacion(substr(i.cod_rubro,6,3), 'SIB_CRC_TIP_OPE_SOBREGIRO') = 'S';
            AND (SELECT decode(nvl(COUNT(*), 0), 0, 'N', 'S')
                   FROM ba_cod_referencias x
                  WHERE x.dominio = 'SIB_CRC_TIP_OPE_SOBREGIRO'
                    AND x.val_minimo = 'S') = 'S';
      exception
         when others then
            v_cod_rubro := null;
      end;
      v_tip_operacion := substr(v_cod_rubro, 6, 3);

      if nvl(p_sal_buscado,'C') = 'C' then
         BEGIN
            SELECT r.sit_deuda
              INTO v_sit_deuda
              FROM cc_sobregiros_res r
             WHERE r.nro_cuenta = p_nro_cuenta;
         EXCEPTION
            WHEN no_data_found THEN
               v_sit_deuda         := 'S';
            WHEN OTHERS THEN
               v_sit_deuda         := NULL;
         END;
         SELECT nvl(a.sal_tot_batch, 0) - nvl(a.sal_ret_batch, 0) - nvl(a.sal_blo_batch, 0) monto
           into v_sal_capital
           from cc_cta_corrientes a
          where a.nro_cuenta = p_nro_cuenta;
         if v_cod_modalidad = 41 then

            v_rub_con_pignorado := fu_obt_rub_con_tipo(p_nro_cuenta, 'P', v_tip_operacion);

            p_cod_rubro := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'C', 'N');

            v_tip_ope_cta_cte := fu_obt_tip_operacion(v_tip_operacion, 'SIB_CRC_TIP_OPE_CTA_CTE');
            v_tip_ope_pignorado := fu_obt_tip_operacion(v_tip_operacion, 'SIB_CRC_TIP_OPE_PIGNORADO');

            v_mto_lin_sobregiro := fuc_obt_mto_lin_sob(p_nro_cuenta);

            IF nvl(v_mto_lin_sobregiro, 0) >= abs(v_sal_capital) THEN
               v_sob_con_acuerdo := v_sal_capital;
            ELSIF nvl(v_mto_lin_sobregiro,0) > 0 AND nvl(v_mto_lin_sobregiro,0) < abs(v_sal_capital) THEN
               v_sob_con_acuerdo := v_mto_lin_sobregiro;
            ELSE
               v_sob_con_acuerdo := 0;
            END IF;

            IF nvl(v_sal_capital, 0) < 0 AND v_tip_ope_cta_cte = 'S' THEN
               p_cod_rubro := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'C', 'N');
            ELSIF nvl(v_sal_capital, 0) < 0 AND v_tip_ope_pignorado = 'S' THEN
               p_cod_rubro := v_rub_con_pignorado;
            ELSIF nvl(v_sal_capital, 0) < 0 AND fu_obt_tip_operacion(v_tip_operacion, 'SIB_CRC_TIP_OPE_SOB_PER') = 'S' THEN
               IF nvl(v_sob_con_acuerdo,0) <> 0 THEN
                  p_cod_rubro := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'C', 'A');
               ELSE
                  p_cod_rubro := v_cod_rubro; --i.cta_con_cap_original;
               END IF;
            ELSIF nvl(v_sal_capital, 0) < 0 AND fu_obt_tip_operacion(v_tip_operacion, 'SIB_CRC_TIP_OPE_SOB_TEM') = 'S' THEN
               IF v_sit_deuda = 'S' THEN
                  p_cod_rubro := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'C', 'T');
               END IF;
            ELSIF nvl(v_sal_capital, 0) >=0 AND v_tip_ope_cta_cte = 'S' THEN
               p_cod_rubro := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'C', 'N');
            ELSIF nvl(v_sal_capital, 0) >=0 AND v_tip_ope_pignorado = 'S' THEN
               p_cod_rubro := v_rub_con_pignorado;
            ELSIF fu_obt_tip_operacion(v_tip_operacion, 'SIB_CRC_TIP_OPE_SOBREGIRO') = 'S' AND nvl(v_sal_capital, 0) >= 0 then
               p_cod_rubro := v_cod_rubro; --i.cta_con_cap_original;
            END IF;
            IF p_rubro IS NULL THEN
               IF v_sit_deuda = 'S' THEN
                  p_rubro := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'C', 'A');
                  IF p_rubro IS NULL THEN
                     p_rubro := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'C', 'T');
                  END IF;
               ELSE
                  p_rubro := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'C', v_sit_deuda);
               END IF;
            END IF;
         ELSIF v_cod_modalidad = 47 THEN---Para agregar el city
            p_rubro := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'C');
         ELSE
            p_rubro := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'B');
         END IF;
         IF v_tip_ope_cta_cte = 'S' THEN
            IF nvl(lf_obt_sal_bloqueado(p_nro_cuenta),0) > 0 /*i.sub_tip_ope = 'EMB'*/ THEN
               p_rubro := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'Q', 'N');
            END IF;
         END IF;

         if p_rubro is null then
            v_cod_transaccion := 602;
            v_tip_movimiento  := 'C';
         else
            return p_rubro;
         end if;
      elsif nvl(p_sal_buscado,'C') = 'O' then --- rub_con_contingencia
         p_rubro := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'O');
         if p_rubro is null then
            v_cod_transaccion := 920;
            v_tip_movimiento  := 'D';
         else
            return p_rubro;
         end if;
      end if;

   elsif v_cod_modulo = 8 then
      v_cod_transaccion := 890;
      v_tip_movimiento  := 'D';
   elsif v_cod_modulo = 15 then
      IF v_est_cuenta = 'I' THEN
         v_cod_transaccion := 959;
      ELSIF v_est_cuenta <> 'I' THEN
         v_cod_transaccion := 711;
      END IF;
      v_tip_movimiento  := 'D';

   elsif v_cod_modulo = 10 then
      IF v_cod_modalidad IN (101, 102, 105, 125, 129, 132, 123,114, 104, 124) --bonos tesoro, municipalidad, cc, lrm,bonos privados
         THEN
         v_tip_movimiento := 'D';
         IF v_cod_sit_contable = '10000001' THEN
            v_cod_transaccion := 805;
         ELSE
            v_cod_transaccion := 711;
         END IF;
      ELSIF v_cod_modalidad IN (101, 102, 129, 132, 123, 114) THEN
         v_tip_movimiento  := 'C';
         v_cod_transaccion := 811;
      ELSIF v_cod_modalidad IN (117, 145) THEN
         --prestamos afd
         v_tip_movimiento  := 'C';
         v_cod_transaccion := 801;
      ELSIF v_cod_modalidad IN (109, 118, 112, 126, 134, 144, 106, 110, 116, 146) THEN
         --prestamos recibidos,colocaciones, bonos afd
         v_tip_movimiento  := 'D';
         v_cod_transaccion := 711;
      END IF;

   end if;

   if p_rubro is null then
      /* busco la transaccion que le corresponde */
      SELECT tr.cod_tip_asiento, cod_tip_asiento2, cod_pro_contable
        INTO v_cod_tip_asiento, v_cod_tip_asiento2, v_cod_pro_contable
        FROM ge_modalidades mo, ge_transacciones tr
       WHERE tr.cod_modulo = v_cod_modulo
         AND tr.cod_modalidad = v_cod_modalidad
         AND tr.cod_transaccion = v_cod_transaccion
         AND mo.cod_modulo = v_cod_modulo
         AND mo.cod_modalidad = v_cod_modalidad;

      /* busco la cuenta contable que le corresponde */
      SELECT ind_plazo, ind_deudor, cod_rubro, ind_producto
        INTO v_ind_plazo, v_ind_deudor, p_cod_rubro, v_ind_producto
        FROM ge_tip_asientos
       WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
         AND cod_moneda = v_cod_moneda
         AND (cod_sec_contable IS NULL OR cod_sec_contable = v_cod_sec_contable)
         AND (tip_renovacion IS NULL OR tip_renovacion = nvl(v_tip_renovacion, 'A'))
         AND (tip_interes IS NULL OR tip_interes = v_tip_interes)
         AND ((nvl(v_tip_cuenta, 'x') = 'B' and tip_cuenta = v_tip_cuenta) or
             (nvl(v_tip_cuenta, 'x') <> 'B' and (tip_cuenta IS NULL OR tip_cuenta = v_tip_cuenta)))
         AND (cat_automatica IS NULL OR cat_automatica = v_cat_automatica)
         AND (est_cuenta IS NULL OR est_cuenta = v_est_cuenta)
         AND (ind_residente = 'X' OR ind_residente = v_residente)
         AND (cod_sit_contable IS NULL OR cod_sit_contable = v_cod_sit_contable)
         AND tip_movimiento = v_tip_movimiento
         AND nro_linea =
             (SELECT MIN(nro_linea)
                FROM ge_tip_asientos
               WHERE cod_tip_asiento = v_cod_tip_asiento
                 AND cod_moneda = v_cod_moneda
                 AND (cod_sec_contable IS NULL OR cod_sec_contable = v_cod_sec_contable)
                 AND (tip_renovacion IS NULL OR tip_renovacion = nvl(v_tip_renovacion, 'A'))
                 AND (tip_interes IS NULL OR tip_interes = v_tip_interes)
                 AND (tip_cuenta IS NULL OR tip_cuenta = v_tip_cuenta)
                 AND (cat_automatica IS NULL OR cat_automatica = v_cat_automatica)
                 AND (est_cuenta IS NULL OR est_cuenta = v_est_cuenta)
                 AND (ind_residente = 'X' OR ind_residente = v_residente)
                 AND (cod_sit_contable IS NULL OR cod_sit_contable = v_cod_sit_contable)
                 AND tip_movimiento = v_tip_movimiento)
         AND rownum = 1;

      IF v_ind_plazo = 'S' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 2) || v_cod_plazo || substr(p_cod_rubro, 4, 12);
      END IF;
      IF v_ind_deudor = 'S' OR substr(p_cod_rubro, 9, 2) = 'TD' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 8) || (ltrim(to_char(v_cod_tip_deudor, '00'))) ||
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
                        ltrim(to_char(fup_obt_sec_rubro(v_cod_sec_credito), '000')) ||
                        substr(p_cod_rubro, 14, 2);
      END IF;
   end if;
   RETURN p_cod_rubro;
EXCEPTION
   WHEN OTHERS THEN
      p_cod_rubro := NULL;
      RETURN p_cod_rubro;
END;
/

