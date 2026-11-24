CREATE OR REPLACE FUNCTION IT.FUP_OBT_RUB_PRESTAMO (p_nro_cuenta IN VARCHAR2)
RETURN VARCHAR2 IS

  CURSOR MOVIMIEN IS
  SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta,
         c.cod_sec_contable, c.cod_tip_deudor, c.residente, a.cod_moneda,
         a.estado, a.tipo, a.tip_renovacion, cod_plazo,
         a.val_int_devengar, a.dev_acumulado, a.dev_no_cobrado,
         a.dev_suspenso, a.sal_cap_batch,
         nvl(a.sal_int_ade_batch, 0) + nvl(a.sal_int_batch, 0) sal_interes,
         a.tip_interes, c.cat_riesgo
    FROM ge_plz_contables d, ge_clientes c, ge_cta_clientes b, pr_cta_prestamos a
   WHERE b.nro_cuenta = a.nro_cuenta
     AND b.relacion = 'P'
     AND c.cod_persona = b.cod_persona
     AND a.estado != 'N'
     AND can_dias = (SELECT MIN(can_dias)
                       FROM ge_plz_contables
                      WHERE can_dias >= a.fec_vencimiento - a.fec_inicio)
     AND a.nro_cuenta = p_nro_cuenta;

  v_cod_modulo        NUMBER(03);
  v_cod_modalidad     NUMBER(03);
  v_cod_transaccion   NUMBER(03);
  v_cod_oficina       NUMBER(03);
  v_nro_cuenta        VARCHAR2(15);
  v_cod_sector        VARCHAR2(01);
  v_tip_deudor        NUMBER(02);
  v_residente         VARCHAR2(01);
  v_cod_moneda        VARCHAR2(03);
  v_estado            VARCHAR2(01);
  v_tip_operacion     VARCHAR2(01);
  v_cod_plazo         NUMBER(02);
  v_sal_capital       NUMBER(22,2);
  v_sal_interes       NUMBER(22,2);
  v_int_devengar      NUMBER(22,2);
  v_tip_interes       VARCHAR2(01);
  v_cod_rubro         VARCHAR2(15);
  v_cat_riesgo        VARCHAR2(1);
  v_tip_renovacion    VARCHAR2(1);
  v_dev_acumulado     NUMBER(22,2);
  v_dev_no_cobrado    NUMBER(22,2);
  v_dev_suspenso      NUMBER(22,2);

-- obtiene el codigo de rubro que corresponde a una cuenta
PROCEDURE LP_OBT_COD_RUBRO (p_cod_modulo        IN NUMBER,
                            p_cod_modalidad     IN NUMBER,
                            p_cod_transaccion   IN NUMBER,
                            p_cod_moneda        IN VARCHAR2,
                            p_cod_sec_contable  IN VARCHAR2,
                            p_cod_tip_deudor    IN NUMBER,
                            p_residente         IN VARCHAR2,
                            p_cod_plazo         IN VARCHAR2,
                            p_tip_movimiento    IN VARCHAR2,
                            p_cod_rubro         IN OUT VARCHAR2,
                            p_est_cuenta        IN VARCHAR2 DEFAULT NULL,
                            p_tip_renovacion    IN VARCHAR2 DEFAULT NULL,
                            p_cat_automatica    IN NUMBER DEFAULT NULL,
                            p_tip_interes       IN VARCHAR2 DEFAULT NULL,
                            p_tip_cuenta        IN VARCHAR2 DEFAULT NULL) IS

  v_cod_tip_asiento   ge_tip_asientos.cod_tip_asiento%type;
  v_cod_tip_asiento2  ge_tip_asientos.cod_tip_asiento%type;
  v_ind_deudor        VARCHAR2(1);
  v_ind_plazo         VARCHAR2(1);
  v_ind_producto      VARCHAR2(1);
  v_cod_pro_contable  NUMBER(3);

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
      AND (tip_renovacion IS NULL   OR tip_renovacion = NVL(p_tip_renovacion, 'A'))
      AND (tip_interes IS NULL      OR tip_interes = p_tip_interes)
      AND (tip_cuenta IS NULL       OR tip_cuenta = p_tip_cuenta)
      AND (cat_automatica IS NULL   OR cat_automatica = p_cat_automatica)
      AND (est_cuenta IS NULL       OR est_cuenta = p_est_cuenta)
      AND (ind_residente = 'X'      OR ind_residente = p_residente)
      AND tip_movimiento = p_tip_movimiento
      AND nro_linea = (SELECT MIN(nro_linea)
                         FROM ge_tip_asientos
                        WHERE cod_tip_asiento = v_cod_tip_asiento
                          AND cod_moneda = p_cod_moneda
                          AND (cod_sec_contable IS NULL OR cod_sec_contable = p_cod_sec_contable)
                          AND (tip_renovacion IS NULL   OR tip_renovacion = NVL(p_tip_renovacion, 'A'))
                          AND (tip_interes IS NULL      OR tip_interes = p_tip_interes)
                          AND (tip_cuenta IS NULL       OR tip_cuenta = p_tip_cuenta)
                          AND (cat_automatica IS NULL   OR cat_automatica = p_cat_automatica)
                          AND (est_cuenta IS NULL       OR est_cuenta = p_est_cuenta)
                          AND (ind_residente = 'X'      OR ind_residente = p_residente)
                          AND tip_movimiento = p_tip_movimiento);

   IF v_ind_plazo = 'S' then
     p_cod_rubro := substr(p_cod_rubro,1,2) || p_cod_plazo|| substr(p_cod_rubro,4,12);
   END IF;
   IF v_ind_deudor = 'S' OR substr(p_cod_rubro,9,2) = 'TD' then
     p_cod_rubro := substr(p_cod_rubro,1,8) || (ltrim(to_char(p_cod_tip_deudor,'00'))) || substr(p_cod_rubro,11,5);
   END IF;
   ---Reemplaza el codigo del producto -----------------------
   IF v_IND_PRODUCTO = 'S' THEN
     p_cod_rubro := substr(p_cod_rubro,1,10) || ltrim(TO_CHAR(v_cod_pro_contable,'000')) || substr(p_cod_rubro,14,2);
   END IF;

EXCEPTION
  WHEN OTHERS THEN
    p_cod_rubro := NULL;
END;
--- fin del obtener codigo de rubro------------------------------------

-- PROCESO PRINCIPAL
BEGIN
  IF MOVIMIEN%ISOPEN THEN
    CLOSE MOVIMIEN;
  END IF;
  ------------------------- LEER MOVIMIEN ------------------------------
  OPEN MOVIMIEN;
  FETCH MOVIMIEN INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_nro_cuenta,
                      v_cod_sector, v_tip_deudor, v_residente, v_cod_moneda,
                      v_estado, v_tip_operacion, v_tip_renovacion, v_cod_plazo,
                      v_int_devengar, v_dev_acumulado, v_dev_no_cobrado, v_dev_suspenso,
                      v_sal_capital, v_sal_interes, v_tip_interes,
                      v_cat_riesgo;

  IF v_cod_modulo IS NOT NULL THEN
    IF v_estado IN ('C','A') THEN
      IF v_tip_operacion = 'A' THEN
        v_cod_transaccion := 801;
      ELSE
        v_cod_transaccion  := 805;
      END IF;
    ELSIF v_estado = 'V' THEN
        v_cod_plazo := 0;
      IF v_tip_operacion = 'A' THEN
        v_cod_transaccion := 820;
      ELSE
        v_cod_transaccion := 821;
      END IF;
    ELSIF v_estado = 'G' THEN
        v_cod_plazo := 0;
        v_cod_transaccion := 822;
      ELSIF v_estado IN ('M','I') THEN
        v_cod_plazo := 0;
        v_cod_transaccion := 823;
    END IF;
    --- busco la cuenta que le corresponde al saldo ----
    lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda, v_cod_sector,
                     v_tip_deudor, v_residente, to_char(v_cod_plazo), 'C', v_cod_rubro, v_estado,
                     v_tip_renovacion, v_cat_riesgo, v_tip_interes, v_tip_operacion);
  END IF;
  CLOSE MOVIMIEN;
  RETURN v_cod_rubro;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'ERROR:' || SQLERRM);
END;
/

