CREATE OR REPLACE PROCEDURE IT.prp_cal_sal_inicial_tmp IS
-- Procedimiento temporal para calcular el saldo inicial de rubros transitorios porción del banco, en cobro de cargos
-- por seguro incendio y vida.
CURSOR c_prestamos IS
  SELECT *
    FROM pr_cta_prestamos a
   WHERE a.estado NOT IN ('I','N')
     AND EXISTS (SELECT 1 FROM pr_cta_gastos b
                  WHERE b.nro_cuenta = a.nro_cuenta
                    AND b.cod_transaccion IN (1520,1521)
                    AND b.fec_ult_pago IS NULL)
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
--
--
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
--
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

      if v_val_tas_pri_vida <= v_val_tas_vida then
        v_val_tas_vida_global := v_val_tas_pri_vida * 100 / v_val_tas_vida;
        v_mto_car_vida     := round((v_tot_car_vida * (100 - v_val_tas_vida_global) / 100),v_redondeo);
      else
        v_mto_car_vida := 0;
      end if;

      if v_val_tas_pri_incendio <= v_val_tas_incendio then
        v_val_tas_ince_global := v_val_tas_pri_incendio * 100 / v_val_tas_incendio;
        v_mto_car_incendio := round((v_tot_car_incendio * (100 - v_val_tas_ince_global) / 100),v_redondeo);
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
              v_residente, k.cod_moneda, k.est_batch, 'U', v_cod_plazo, k.tip_renovacion,
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
  commit;
end;
/

