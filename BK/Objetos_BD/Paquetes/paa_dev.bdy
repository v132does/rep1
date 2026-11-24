CREATE OR REPLACE PACKAGE BODY IT.PAA_DEV IS

G_SAL_ACUMULADO AH_CTA_VISTAS.SAL_TOTAL%TYPE;
G_DIA_ACUMULADO AH_DEVENGADOS.CAN_DIA_INTERES%TYPE;
G_SECUENCIA NUMBER(3);
G_MTO_CAPITAL AH_CTA_CERTIFICADOS.CAPITAL%TYPE;
G_TAS_PERSONALIZADA AH_CTA_VISTAS.TAS_PERSONALIZADA%TYPE;
G_SAL_DISPONIBLE AH_DEVENGADOS.SAL_ACUMULADO%TYPE;
G_FEC_APERTURA AH_CTA_PLAZOS.FEC_APERTURA%TYPE;
G_FEC_ULT_CAPITALIZACION AH_CTA_PLAZOS.FEC_ULT_CAPITALIZACION%TYPE;
G_FEC_INICIO AH_DEVENGADOS.FEC_INICIO%TYPE;
G_FEC_VENCIMIENTO AH_CTA_PLAZOS.FEC_VENCIMIENTO%TYPE;

/* Obtener fecha de vencimiento. */
FUNCTION FU_OBT_FEC_VTO_CUPON
 (P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_FEC_VENCIMIENTO IN AH_CTA_PLAZOS.FEC_VENCIMIENTO%TYPE
 )
 RETURN DATE
 IS

  V_FEC_VENCIMIENTO AH_CTA_PLAZOS.FEC_VENCIMIENTO%TYPE;
  v_fec_final    date;
BEGIN
  v_fec_final := paa_dev.g_fec_hoy;
  If paa_dev.G_FEC_HOY = paa_dev.G_ULT_MES_HABIL Then
     v_fec_final := paa_dev.G_ULT_DIA_MES;
  End If;

  SELECT MAX(FEC_VENCIMIENTO)
    INTO V_FEC_VENCIMIENTO
    FROM AH_CUPONES
   WHERE NRO_CUENTA = P_NRO_CUENTA
     AND ((FEC_VENCIMIENTO < P_FEC_VENCIMIENTO and PAA_DEV.G_FEC_ANTERIOR + 1 = v_fec_final) OR
          (FEC_VENCIMIENTO <= P_FEC_VENCIMIENTO and PAA_DEV.G_FEC_ANTERIOR + 1 < v_fec_final)) ;
  RETURN(V_FEC_VENCIMIENTO);
EXCEPTION
  WHEN OTHERS THEN
    V_FEC_VENCIMIENTO := PAA_DEV.G_FEC_HOY;
    RETURN(V_FEC_VENCIMIENTO);
END;
--;
/* Obtener el saldo inicial de la cuenta. */
FUNCTION FU_OBT_SAL_INICIAL
 (P_COD_MODULO IN OUT AH_CTA_VISTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN OUT AH_CTA_VISTAS.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN OUT AH_CTA_VISTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN OUT AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN OUT AH_CTA_VISTAS.FEC_APERTURA%TYPE
 )
 RETURN NUMBER
 IS

V_SAL_INICIAL AH_CTA_VISTAS.SAL_TOTAL%TYPE;

/* Obtener interes cupón. */
FUNCTION FU_OBT_INT_CUPON
 (P_NRO_CUENTA IN AH_CUPONES.NRO_CUENTA%TYPE
 ,P_FEC_FIN_DEVENGAMIENTO IN AH_CUPONES.FEC_VENCIMIENTO%TYPE
 )
 RETURN NUMBER;

/* Obtener interes cupón. */
FUNCTION FU_OBT_INT_CUPON
 (P_NRO_CUENTA IN AH_CUPONES.NRO_CUENTA%TYPE
 ,P_FEC_FIN_DEVENGAMIENTO IN AH_CUPONES.FEC_VENCIMIENTO%TYPE
 )
 RETURN NUMBER
 IS

V_MTO_INTERES AH_CUPONES.MTO_INTERES%TYPE;
BEGIN
      SELECT MTO_INTERES
        INTO V_MTO_INTERES
        FROM AH_CUPONES
       WHERE NRO_CUENTA = P_NRO_CUENTA
         AND FEC_VENCIMIENTO = P_FEC_FIN_DEVENGAMIENTO + 1;
      RETURN (V_MTO_INTERES);
   EXCEPTION
      WHEN OTHERS THEN
         RETURN (-9999);
   END;
BEGIN
      SELECT NVL(SAL_INI_MES,0)
        INTO V_SAL_INICIAL
        FROM AH_SAL_MENSUALES
       WHERE COD_MODULO = P_COD_MODULO
         AND COD_MODALIDAD = P_COD_MODALIDAD
         AND COD_OFICINA = P_COD_OFICINA
         AND MES = TO_NUMBER(TO_CHAR(P_FECHA, 'MM'))
         AND ANO = TO_NUMBER(TO_CHAR(P_FECHA, 'YYYY'));
     RETURN V_SAL_INICIAL;
   EXCEPTION
     WHEN OTHERS THEN
        V_SAL_INICIAL := 0;
        RETURN(V_SAL_INICIAL);
   END;
--;
/* Obtener interes cupón. */
FUNCTION FU_OBT_INT_CUPON
 (P_NRO_CUENTA IN AH_CUPONES.NRO_CUENTA%TYPE
 ,P_FEC_FIN_DEVENGAMIENTO IN AH_CUPONES.FEC_VENCIMIENTO%TYPE
 )
 RETURN NUMBER
 IS

V_MTO_INTERES AH_CUPONES.MTO_INTERES%TYPE;
BEGIN
      SELECT MTO_INTERES
        INTO V_MTO_INTERES
        FROM AH_CUPONES
       WHERE NRO_CUENTA = P_NRO_CUENTA
         AND FEC_VENCIMIENTO = P_FEC_FIN_DEVENGAMIENTO + 1;
      RETURN (V_MTO_INTERES);
   EXCEPTION
      WHEN OTHERS THEN
         RETURN (null);
   END;
/* Actualiza la tabla devengados histórirco. */
PROCEDURE PR_PRO_AH_DEVENG_HIS
 (P_FEC_PROCESO IN DATE
 ,P_MTO_INTERES IN AH_DEVENGADOS_HIS.MTO_INTERES%TYPE
 )
 IS
BEGIN
      UPDATE AH_DEVENGADOS_HIS SET
             MTO_INTERES = nvl(MTO_INTERES,0) + P_MTO_INTERES
       WHERE COD_MODULO = PAA_DEV.G_COD_MODULO
         AND COD_MODALIDAD = PAA_DEV.G_COD_MODALIDAD
         AND COD_OFICINA = PAA_DEV.G_COD_OFICINA
         AND NRO_CUENTA = PAA_DEV.G_NRO_CUENTA
         AND ANO = TO_NUMBER(TO_CHAR(P_FEC_PROCESO,'YYYY'))
         AND MES = TO_NUMBER(TO_CHAR(P_FEC_PROCESO,'MM'));

       IF SQL%NOTFOUND THEN
          /* si no encontro el registro para el mes inserta uno nuevo */

          INSERT INTO AH_DEVENGADOS_HIS
                     (COD_MODULO,
                      COD_MODALIDAD,
                      COD_OFICINA,
                      NRO_CUENTA,
                      ANO,
                      MES,
                      MTO_INTERES)
              VALUES (PAA_DEV.G_COD_MODULO,
                      PAA_DEV.G_COD_MODALIDAD,
                      PAA_DEV.G_COD_OFICINA,
                      PAA_DEV.G_NRO_CUENTA,
                      TO_NUMBER(TO_CHAR(P_FEC_PROCESO,'YYYY')),
                      TO_NUMBER(TO_CHAR(P_FEC_PROCESO,'MM')),
                      P_MTO_INTERES);
       END IF;
   END;
/* Insertar ahorro devengados.. */
PROCEDURE PR_INS_AH_DEVENGADOS
 (P_FEC_INICIO IN AH_DEVENGADOS.FEC_INICIO%TYPE
 ,P_NRO_DIAS IN AH_DEVENGADOS.CAN_DIA_INTERES%TYPE
 ,P_MTO_INTERES IN AH_DEVENGADOS.MTO_INTERES%TYPE
 ,P_MTO_CAPITAL IN AH_DEVENGADOS.SAL_ACUMULADO%TYPE
 ,P_VAL_TASA IN AH_DEVENGADOS.VAL_TASA%TYPE
 ,P_FEC_TASA IN AH_DEVENGADOS.FEC_TASA%TYPE
 ,P_MTO_AJUSTE IN AH_DEVENGADOS.MTO_AJUSTE%TYPE DEFAULT 0
 )
 IS
BEGIN
      PAA_DEV.G_LUGAR := 'INSERTAR AH_DEVENGADOS';
      INSERT INTO AH_DEVENGADOS(NRO_CUENTA,
                                COD_MONEDA,
                                FECHA,
                                VAL_TASA,
                                FEC_TASA,
                                CAN_DIA_INTERES,
                                SAL_ACUMULADO,
                                MTO_INTERES,
                                FEC_INICIO,
                                MTO_DEV_ACUMULADO,
                                MTO_AJUSTE)
                         VALUES(PAA_DEV.G_NRO_CUENTA,
                                PAA_DEV.G_COD_MONEDA,
                                PAA_DEV.G_FEC_HOY,
                                p_VAL_TASA,
                                P_FEC_TASA,
                                P_NRO_DIAS,
                                P_MTO_CAPITAL,
                                P_MTO_INTERES,
                                P_FEC_INICIO,
                                P_MTO_INTERES,
                                P_MTO_AJUSTE);
   EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000, SQLERRM||' / '||PAA_DEV.G_LUGAR||' / '||PAA_DEV.G_NRO_CUENTA);
   END;
/* Acturalizar ahorros devengados. */
PROCEDURE PR_ACT_AH_DEVENGADOS
 (P_NRO_CUENTA IN VARCHAR2
 ,P_FEC_INICIO IN AH_DEVENGADOS.FEC_INICIO%TYPE
 ,P_VAL_TASA IN AH_DEVENGADOS.VAL_TASA%TYPE
 ,P_MTO_CAPITAL IN AH_DEVENGADOS.SAL_ACUMULADO%TYPE
 ,P_INT_ANTERIOR IN AH_DEVENGADOS.MTO_INTERES%TYPE
 ,P_DIA_ANTERIORES IN AH_DEVENGADOS.CAN_DIA_INTERES%TYPE
 ,P_DEV_ACUMULADO IN AH_DEVENGADOS.MTO_DEV_ACUMULADO%TYPE
 ,P_NRO_DIAS IN AH_DEVENGADOS.CAN_DIA_INTERES%TYPE
 ,P_MTO_INTERES IN AH_DEVENGADOS.MTO_INTERES%TYPE
 ,P_MTO_AJUSTE IN AH_DEVENGADOS.MTO_AJUSTE%TYPE
 )
 IS

V_INT_HOY AH_DEVENGADOS.MTO_INTERES%TYPE;
BEGIN
      PAA_DEV.G_LUGAR := 'ACTUALIZA AH_DEVENGADOS';
      V_INT_HOY := NVL(P_MTO_INTERES,0) - NVL(P_DEV_ACUMULADO,0);

      UPDATE AH_DEVENGADOS
         SET CAN_DIA_INTERES = P_NRO_DIAS,
             MTO_DEV_ANTERIOR = P_INT_ANTERIOR,
             DIA_DEV_ANTERIOR = P_DIA_ANTERIORES,
             MTO_INTERES = V_INT_HOY,
             MTO_DEV_ACUMULADO = NVL(MTO_DEV_ACUMULADO,0) + NVL(V_INT_HOY,0),
             FECHA = PAA_DEV.G_FEC_HOY,
             SAL_ACUMULADO = P_MTO_CAPITAL,
             VAL_TASA = P_VAL_TASA,
             MTO_AJUSTE = P_MTO_AJUSTE
       WHERE NRO_CUENTA = P_NRO_CUENTA
         AND FEC_INICIO = P_FEC_INICIO;
   --
   PAA_DEV.G_LUGAR := 'PR_PRO_AH_DEVENGADOS_HIS(update_AH_DEVENGADOS)';
   PR_PRO_AH_DEVENG_HIS(P_FEC_INICIO + (P_NRO_DIAS - 1), V_INT_HOY);

EXCEPTION
  WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20000, SQLERRM||' - '||PAA_DEV.G_LUGAR||' - '||P_NRO_CUENTA||' - '||
                            'Interes '||TO_CHAR(V_INT_HOY)||' - '||'P_MTO_CAPITAL '||TO_CHAR(P_MTO_CAPITAL));
END;
/* Procesar AH_DEVENGADOS. */
PROCEDURE PR_PRO_AH_DEVENGADOS
 (P_FEC_DEV_INICIO IN AH_DEVENGADOS.FEC_INICIO%TYPE
 ,P_NRO_DIAS IN AH_DEVENGADOS.CAN_DIA_INTERES%TYPE
 ,P_MTO_INTERES IN AH_DEVENGADOS.MTO_INTERES%TYPE
 ,P_MTO_CAPITAL IN AH_DEVENGADOS.SAL_ACUMULADO%TYPE
 ,P_VAL_TASA IN AH_DEVENGADOS.VAL_TASA%TYPE
 ,P_FEC_TASA IN AH_DEVENGADOS.FEC_TASA%TYPE
 ,P_MTO_AJUSTE IN AH_DEVENGADOS.MTO_AJUSTE%TYPE DEFAULT 0
 )
 IS

V_ID AH_DEVENGADOS%ROWTYPE;
V_INT_HOY AH_DEVENGADOS.MTO_INTERES%TYPE;
/*Recupera registro en AH_DEVENGADOS que corresponda a la cuenta del cursor C_AH_DEVENGADOS */
   CURSOR C_AH_DEVENGADOS IS
   SELECT *
     FROM AH_DEVENGADOS
    WHERE NRO_CUENTA  = PAA_DEV.G_NRO_CUENTA
      AND FEC_INICIO  = P_FEC_DEV_INICIO;
      --AND VAL_TASA  = P_VAL_TASA;
--
BEGIN
      V_ID := NULL;
      OPEN C_AH_DEVENGADOS;
      FETCH C_AH_DEVENGADOS INTO V_ID;
      CLOSE C_AH_DEVENGADOS;
      --
      IF V_ID.FEC_INICIO IS NULL THEN
         V_INT_HOY:= NVL(P_MTO_INTERES,0);
         --IF PAA_DEV.G_COD_MODALIDAD = 31 AND PAA_DEV.G_SAL_PROMEDIO < PAA_DEV.G_SAL_MIN_PACTADO THEN
         if p_nro_dias > 0 then
           IF PAA_DEV.G_COD_MODALIDAD = 31 AND (NVL(P_MTO_CAPITAL,0)/NVL(P_NRO_DIAS,1)) < PAA_DEV.G_SAL_MIN_PACTADO THEN
              V_INT_HOY := 0;
           END IF;
         else
           v_int_hoy := 0;
         end if;
         PAA_DEV.G_LUGAR := 'Insertar AH_DEVENGADDOS';
--dbms_output.put_line('Tasa ins '||p_val_tasa);
         IF V_INT_HOY >= 0 THEN
            PR_INS_AH_DEVENGADOS(P_FEC_DEV_INICIO, P_NRO_DIAS, V_INT_HOY, P_MTO_CAPITAL, P_VAL_TASA, P_FEC_TASA, P_MTO_AJUSTE);
            PR_PRO_AH_DEVENG_HIS(P_FEC_DEV_INICIO, V_INT_HOY);
         END IF;
      ELSE
         V_INT_HOY := NVL(P_MTO_INTERES,0);
         IF PAA_DEV.G_COD_MODALIDAD = 31 AND PAA_DEV.G_SAL_PROMEDIO < PAA_DEV.G_SAL_MIN_PACTADO THEN
            V_INT_HOY:= 0;
         END IF;
         PAA_DEV.G_LUGAR := 'Acturalizar AH_DEVENGADDOS';
         PR_ACT_AH_DEVENGADOS(V_ID.NRO_CUENTA, P_FEC_DEV_INICIO, P_VAL_TASA, P_MTO_CAPITAL,
                              V_ID.MTO_INTERES, V_ID.CAN_DIA_INTERES, V_ID.MTO_DEV_ACUMULADO,
                              P_NRO_DIAS, V_INT_HOY,P_MTO_AJUSTE);
      END IF;
   EXCEPTION
       WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(-20000, SQLERRM||' - '||PAA_DEV.G_LUGAR||' - '||PAA_DEV.G_NRO_CUENTA);
   END;
/* Calculo del devengamientos para Ahorro a Plazo Fijo. */
PROCEDURE PR_CAL_DEV_AH_CTA_PL  (P_FEC_DEV_INICIO IN OUT AH_DEVENGADOS.FEC_INICIO%TYPE  ,P_FEC_DEV_FINAL IN OUT AH_DEVENGADOS.FECHA%TYPE  ,P_MTO_CAPITAL IN OUT AH_DEVENGADOS.SAL_ACUMULADO%TYPE  ,P_TAS_PERSONALIZADA IN OUT AH_CTA_PLAZOS.TAS_PERSONALIZADA%TYPE
 ,P_FEC_APERTURA IN OUT AH_CTA_PLAZOS.FEC_APERTURA%TYPE  ,P_FEC_ULT_CAPITALIZACION IN OUT AH_CTA_PLAZOS.FEC_ULT_CAPITALIZACION%TYPE
 ,P_TIP_CAPITALIZACION IN OUT AH_CTA_PLAZOS.TIP_CAPITALIZACION%TYPE
 )
 IS
V_DIAS AH_DEVENGADOS.CAN_DIA_INTERES%TYPE;
V_MTO_INTERES AH_DEVENGADOS.MTO_INTERES%TYPE;
V_MTO_INT_CUPON AH_CUPONES.MTO_INTERES%TYPE;
V_MTO_AJUSTE AH_CUPONES.MTO_INTERES%TYPE;
V_FEC_VTO_CUPON DATE;
v_redondeo number(5);

BEGIN
      IF PAA_DEV.G_COD_MODALIDAD <> 37 THEN
         PAA_DEV.G_LUGAR := 'Busca el valor de tasa a aplicar (PR_CAL_DEV_AH_CTA_PLAZOS)';
         PAG_GEN.PR_OBT_VAL_TASA(PAA_DEV.G_COD_MODULO,
                              PAA_DEV.G_COD_MODALIDAD, PAA_DEV.G_COD_OFICINA,
                              PAA_DEV.G_NRO_CUENTA, PAA_DEV.G_COD_MONEDA, P_MTO_CAPITAL,
                              P_TAS_PERSONALIZADA, PAA_DEV.G_COD_TASA, 609, P_FEC_DEV_FINAL,
                              PAA_DEV.G_VAL_TASA, PAA_DEV.G_FEC_VIG_TASA, PAA_DEV.G_TIP_VALOR,
                              PAA_DEV.G_TIP_TASA);
      END IF;
      -- busco la fecha de vencimiento de algun cupón entre la ultima capitalización y hoy
      IF PAA_DEV.G_COD_MODALIDAD IN (33,34,35,36,37) THEN
         V_FEC_VTO_CUPON := PAA_DEV.FU_OBT_FEC_VTO_CUPON(PAA_DEV.G_NRO_CUENTA, P_FEC_DEV_FINAL);
      END IF;
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',3,PAA_DEV.G_COD_MODALIDAD,PAA_DEV.G_COD_MONEDA);
      IF (PAA_DEV.G_COD_MODALIDAD = 32 AND PAG_GEN.FU_AGR_MES(NVL(TRUNC(P_FEC_ULT_CAPITALIZACION),P_FEC_APERTURA),P_TIP_CAPITALIZACION) < P_FEC_DEV_FINAL) OR
         (PAA_DEV.G_COD_MODALIDAD IN (33,34,35,36,37) AND V_FEC_VTO_CUPON - 1 > P_FEC_DEV_INICIO  ) THEN
       -- Corte porque existe un cupon vencido en dia no habil anterior a hoy(posterior a la ultima capitalizacion)

         IF PAA_DEV.G_COD_MODALIDAD = 32 THEN
            V_DIAS := (PAG_GEN.FU_AGR_MES(NVL(TRUNC(P_FEC_ULT_CAPITALIZACION),P_FEC_APERTURA), P_TIP_CAPITALIZACION) - P_FEC_DEV_FINAL) + 1;
         ELSE
            V_DIAS := V_FEC_VTO_CUPON - P_FEC_DEV_INICIO;
         END IF;
         --
         PAA_DEV.G_LUGAR := 'Calcular Interes (PR_CAL_DEV_AH_CTA_PLAZOS)';
         V_MTO_INTERES := PAG_GEN.FU_CAL_INT_SIMPLE(P_MTO_CAPITAL, V_DIAS, PAA_DEV.G_VAL_TASA);
         --
         IF (PAA_DEV.G_COD_MODALIDAD IN (33,34,35/*,36*/)) OR
            (PAA_DEV.G_COD_MODALIDAD = 36 AND NOT FU_BON_SUB_SEN(PAA_DEV.G_NRO_CUENTA)) THEN
            V_MTO_INTERES:= FLOOR(V_MTO_INTERES) ;
         ELSIF PAA_DEV.G_COD_MONEDA = PAA_DEV.G_MON_LOCAL THEN
            V_MTO_INTERES := ROUND(V_MTO_INTERES,v_redondeo);
         ELSE
            V_MTO_INTERES := ROUND(V_MTO_INTERES,v_redondeo);
         END IF;
         V_MTO_AJUSTE := 0;
         -- Ajusto el interes al del cupón si es que son diferentes
         IF PAA_DEV.G_COD_MODALIDAD IN (33,34,35,36) THEN
            V_MTO_INT_CUPON := PAA_DEV.FU_OBT_INT_CUPON(PAA_DEV.G_NRO_CUENTA, V_FEC_VTO_CUPON - 1); -- SE envia -1 para tomar el valor del vencimiento actual
            IF ABS(V_MTO_INTERES - nvl(V_MTO_INT_CUPON,0)) != 0 and v_mto_int_cupon is not null THEN
               V_MTO_AJUSTE  := NVL(V_MTO_INTERES,0) - nvl(V_MTO_INT_CUPON,0);  -- monto del ajuste
               V_MTO_INTERES := V_MTO_INT_CUPON;
            END IF;
         END IF;
         PAA_DEV.G_MTO_DEVENGADO := PAA_DEV.G_MTO_DEVENGADO + V_MTO_INTERES;
         IF V_MTO_INTERES >= 0 THEN
            PAA_DEV.G_LUGAR := 'Procesar AH_DEVENGADOS PR_CAL_DEV_AH_CTA_PLAZOS';
            PAA_DEV.PR_PRO_AH_DEVENGADOS(P_FEC_DEV_INICIO, V_DIAS, V_MTO_INTERES, P_MTO_CAPITAL, PAA_DEV.G_VAL_TASA, V_FEC_VTO_CUPON-1, V_MTO_AJUSTE);
         END IF;
         --
         IF PAA_DEV.G_COD_MODALIDAD = 32 THEN
            P_FEC_DEV_INICIO := PAG_GEN.FU_AGR_MES(NVL(TRUNC(P_FEC_ULT_CAPITALIZACION),P_FEC_APERTURA), P_TIP_CAPITALIZACION) + 1;
         ELSE
            P_FEC_DEV_INICIO := V_FEC_VTO_CUPON;
         END IF;
      ELSIF PAA_DEV.FU_OBT_FEC_VTO_CUPON(PAA_DEV.G_NRO_CUENTA,P_FEC_DEV_FINAL+1) = P_FEC_DEV_FINAL and p_fec_dev_final = paa_dev.G_FEC_HOY THEN
         ---- Si el cupón vence hoy debe devengar por un solo día - Le envio mañana para que devuelva si vence hoy
         P_FEC_DEV_INICIO := P_FEC_DEV_FINAL;
      END IF;

      V_DIAS:= (P_FEC_DEV_FINAL - P_FEC_DEV_INICIO) + 1;
      PAA_DEV.G_LUGAR := 'Calcular Interes (PR_CAL_DEV_AH_CTA_PLAZOS)';
      V_MTO_INTERES := PAG_GEN.FU_CAL_INT_SIMPLE(P_MTO_CAPITAL, V_DIAS, PAA_DEV.G_VAL_TASA);
      --
      IF (PAA_DEV.G_COD_MODALIDAD IN (33,34,35/*,36*/)) OR
         (PAA_DEV.G_COD_MODALIDAD = 36 AND NOT FU_BON_SUB_SEN(PAA_DEV.G_NRO_CUENTA)) THEN
         V_MTO_INTERES:= FLOOR(V_MTO_INTERES) ;
      ELSIF PAA_DEV.G_COD_MONEDA = PAA_DEV.G_MON_LOCAL THEN
         V_MTO_INTERES := ROUND(V_MTO_INTERES,v_redondeo);
      ELSE
         V_MTO_INTERES := ROUND(V_MTO_INTERES,v_redondeo);
      END IF;
      V_MTO_AJUSTE := 0;
      -- Ajusto el Interés al del cupón si es que son diferentes(solo hasta 20)
      IF PAA_DEV.G_COD_MODALIDAD IN (33,34,35,36) THEN
         V_MTO_INT_CUPON := PAA_DEV.FU_OBT_INT_CUPON(PAA_DEV.G_NRO_CUENTA, P_FEC_DEV_FINAL);
            IF ABS(V_MTO_INTERES - nvl(V_MTO_INT_CUPON,0)) != 0 and v_mto_int_cupon is not null THEN
               V_MTO_AJUSTE  := NVL(V_MTO_INTERES,0) - nvl(V_MTO_INT_CUPON,0);  -- monto del ajuste
               V_MTO_INTERES := V_MTO_INT_CUPON;
            END IF;
      END IF;
      PAA_DEV.G_MTO_DEVENGADO := PAA_DEV.G_MTO_DEVENGADO + V_MTO_INTERES;

      IF V_MTO_INTERES >= 0 THEN
         PAA_DEV.G_LUGAR := 'Procesar AH_DEVENGADOS (PR_CAL_DEV_AH_CTA_PLAZOS)';
         PAA_DEV.PR_PRO_AH_DEVENGADOS(P_FEC_DEV_INICIO, V_DIAS, V_MTO_INTERES, P_MTO_CAPITAL, PAA_DEV.G_VAL_TASA, P_FEC_DEV_FINAL, V_MTO_AJUSTE);
      END IF;
   END;
   --;
/* Procesar AH_DEVENGADOS Reversados. */
PROCEDURE PR_REV_AH_DEVENGADOS
 (P_NRO_CUENTA IN VARCHAR2
 ,P_FEC_ULT_CAPITALIZACION IN OUT AH_CTA_PLAZOS.FEC_ULT_CAPITALIZACION%TYPE
 ,P_FEC_ULT_DEVENGAMIENTO IN AH_DEVENGADOS.FECHA%TYPE
 ,P_FEC_PROCESO IN AH_DEVENGADOS.FECHA%TYPE
 )
 IS

V_REVERSAR AH_DEVENGADOS%ROWTYPE;
V_DEV_ACU_ACTUAL AH_DEVENGADOS.MTO_DEV_ACUMULADO%TYPE;
V_DEV_ACU_REVERSADO AH_DEVENGADOS.MTO_DEV_ACUMULADO%TYPE;
V_INT_HOY AH_DEVENGADOS.MTO_INTERES%TYPE;
/* Para realizar el asiento de reversión */
   CURSOR C_AH_DEVENGADOS IS
   SELECT *
     FROM AH_DEVENGADOS
    WHERE NRO_CUENTA = P_NRO_CUENTA
      AND FECHA <> P_FEC_PROCESO
      AND NVL(MTO_DEV_ACUMULADO,0) > 0
      AND FEC_INICIO BETWEEN P_FEC_ULT_CAPITALIZACION AND P_FEC_ULT_DEVENGAMIENTO;
BEGIN
      V_REVERSAR := NULL;
      OPEN C_AH_DEVENGADOS;
      FETCH C_AH_DEVENGADOS INTO V_REVERSAR;
      CLOSE C_AH_DEVENGADOS;
      IF V_REVERSAR.FEC_INICIO IS NOT NULL
     AND V_REVERSAR.VAL_TASA IS NOT NULL
     AND V_REVERSAR.CAN_DIA_INTERES IS NOT NULL THEN
     --
         PAA_DEV.G_LUGAR := 'Sumariza en AH_DEVENGADOS el MTO_DEV_ACUMULADO Actualizado entre P_FEC_ULT_CAPITALIZACION - P_FEC_ULT_DEVENGAMIENTO';
      BEGIN
         SELECT SUM(MTO_DEV_ACUMULADO)
           INTO V_DEV_ACU_ACTUAL
           FROM AH_DEVENGADOS
          WHERE NRO_CUENTA = P_NRO_CUENTA
            AND FECHA = P_FEC_PROCESO
            AND FEC_INICIO BETWEEN P_FEC_ULT_CAPITALIZACION AND P_FEC_ULT_DEVENGAMIENTO;
      EXCEPTION
         WHEN OTHERS THEN
            V_DEV_ACU_ACTUAL := 0;
      END;
      --
      V_INT_HOY := NVL(V_DEV_ACU_ACTUAL,0) - NVL(V_DEV_ACU_REVERSADO,0);
      --
      IF V_INT_HOY <> 0 THEN
         PAA_DEV.G_LUGAR := 'Reversar Devengado 1 (Devengado del Dia)';
         UPDATE AH_DEVENGADOS
            SET MTO_INTERES = 0
          WHERE NRO_CUENTA = P_NRO_CUENTA
            AND FECHA = P_FEC_PROCESO
            AND FEC_INICIO BETWEEN P_FEC_ULT_CAPITALIZACION AND P_FEC_ULT_DEVENGAMIENTO;
          --
          PAA_DEV.G_LUGAR := 'Reversar Devengado 2 (Reversado del Dia)';
          UPDATE AH_DEVENGADOS
             SET MTO_INTERES = V_INT_HOY,
                 FECHA = P_FEC_PROCESO,
                 MTO_DEV_ANTERIOR = V_DEV_ACU_REVERSADO,
                 MTO_DEV_ACUMULADO = 0
           WHERE NRO_CUENTA = P_NRO_CUENTA
             AND FEC_INICIO = V_REVERSAR.FEC_INICIO
             AND VAL_TASA = V_REVERSAR.VAL_TASA
             AND CAN_DIA_INTERES = V_REVERSAR.CAN_DIA_INTERES;
            IF SQL%FOUND THEN
             PAA_DEV.G_LUGAR := 'Procesar AH_DEVENGADOS_HIS (Rervesado Devengado)';
             PAA_DEV.PR_PRO_AH_DEVENG_HIS(V_REVERSAR.FEC_INICIO, V_INT_HOY);
             --
             PAA_DEV.G_LUGAR := 'Actualiza los demas registros a cero diferentes a la fecha de hoy';
             UPDATE AH_DEVENGADOS
                SET MTO_INTERES = 0,
                    FECHA = P_FEC_PROCESO,
                    MTO_DEV_ACUMULADO = 0
              WHERE NRO_CUENTA = P_NRO_CUENTA
                AND FECHA = P_FEC_PROCESO
                AND FEC_INICIO BETWEEN P_FEC_ULT_CAPITALIZACION AND P_FEC_ULT_DEVENGAMIENTO;
            END IF;
         --
         END IF;
      --
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,SQLERRM||' '||PAA_DEV.G_LUGAR||' '||'P_NRO_CUENTA '||P_NRO_CUENTA||
                                 'Fecha '||TO_CHAR(V_REVERSAR.FEC_INICIO + V_REVERSAR.CAN_DIA_INTERES,'DD/MM/YYYY'));
   END;
   --;
/* Calcular AH_DEVENGADOS. */
PROCEDURE PR_CAL_AH_DEVENGADOS
 (P_FEC_INICIAL IN OUT AH_DEVENGADOS.FEC_INICIO%TYPE
 ,P_FEC_FINAL IN OUT AH_DEVENGADOS.FECHA%TYPE
 ,P_SALDO IN OUT AH_DEVENGADOS.SAL_ACUMULADO%TYPE
 ,P_SAL_PROMEDIO IN AH_DEVENGADOS.SAL_ACUMULADO%TYPE
 ,P_SAL_ACU_DIARIO IN OUT AH_DEVENGADOS.SAL_ACUMULADO%TYPE
 ,P_CAN_DIA_ACUMULADO IN OUT AH_DEVENGADOS.CAN_DIA_INTERES%TYPE
 )
 IS
-- Variables del procedimiento principal
v_redondeo number(5);

/* Calcula el Saldo Acumulado */
PROCEDURE LP_CAL_SAL_ACUMULADO
 (P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN AH_CTA_VISTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FINAL IN DATE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_SALDO IN OUT NUMBER
 ,P_SAL_PROMEDIO IN OUT AH_CAPITALIZACIONES.SAL_PROMEDIO%TYPE
 ,P_SAL_ACUMULADO IN OUT NUMBER
 ,P_CAN_DIA_ACUMULADO IN OUT AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 );
   V_MTO_INTERES NUMBER(18, 2) := 0;
   V_COD_MON_LOCAL BA_MONEDAS.COD_MONEDA%TYPE;
   V_MTO_INT_ACUMULADO NUMBER(18, 2) := 0;
   V_FEC_VIGENCIA DATE;
   /* Bandera que indica la terminación del ciclo */
   V_FIN_TASA VARCHAR2(1) := 'N';
   -- V_TAS_VIGENTE GE_TAS_FECHAS.VAL_TASA%TYPE;
   V_VAL_TASA GE_TAS_FECHAS.VAL_TASA%TYPE;
   /* Siguiente Valor de la Tasa */
   -- V_SIG_VAL_TASA GE_TAS_FECHAS.VAL_TASA%TYPE;
   /* Siguiente Fecha de Vigencia de la Tasa */
   V_SIG_FEC_VIGENCIA DATE;
   V_TIP_VALOR GE_TASAS.TIP_VALOR%TYPE;
   V_FEC_INICIAL DATE;
   V_FEC_FINAL DATE;
   V_CAN_DIA_ACUMULADO AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
   -- V_SAL_DISPONIBLE AH_DEVENGADOS.SAL_ACUMULADO%TYPE := 0;
   V_SAL_ACUMULADO AH_DEVENGADOS.SAL_ACUMULADO%TYPE := 0;
   V_SAL_PROMEDIO AH_DEVENGADOS.SAL_ACUMULADO%TYPE := 0;
   V_TIPO GE_TASAS.TIPO%TYPE;

/* Calcula el Saldo Acumulado */
PROCEDURE LP_CAL_SAL_ACUMULADO
 (P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN AH_CTA_VISTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FINAL IN DATE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_SALDO IN OUT NUMBER
 ,P_SAL_PROMEDIO IN OUT AH_CAPITALIZACIONES.SAL_PROMEDIO%TYPE
 ,P_SAL_ACUMULADO IN OUT NUMBER
 ,P_CAN_DIA_ACUMULADO IN OUT AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 )
 IS

V_COD_MON_LOCAL BA_MONEDAS.COD_MONEDA%TYPE;
V_COD_TRANSACCION GE_TRANSACCIONES.COD_TRANSACCION%TYPE;
V_TIP_DETALLE GE_TRANSACCIONES.TIPO%TYPE;
V_FEC_VALOR AH_MOVIMIENTOS_HIS.FEC_VALOR%TYPE;
V_MONTO AH_MOVIMIENTOS_HIS.MONTO%TYPE;
-------------------------------------------------------------------
--------- Acumula credito y debito que se encuentra en el  --------
--------- rango de fechas                                  --------
-------------------------------------------------------------------
CURSOR c_mov_historicos IS
   SELECT FEC_VALOR, MONTO, T.COD_TRANSACCION, DECODE(T.COD_TRANSACCION,515,'C',560,'C',565,'C',TIPO) TIPO
     FROM GE_TRANSACCIONES T, AH_MOVIMIENTOS_HIS M
    WHERE T.COD_MODULO = p_cod_modulo
      AND T.COD_MODALIDAD = p_cod_modalidad
      AND M.NRO_CUENTA = p_nro_cuenta
      AND T.COD_TRANSACCION = M.COD_TRANSACCION
      AND T.COD_MODULO = M.COD_MODULO
      AND T.COD_MODALIDAD = M.COD_MODALIDAD
      AND FEC_VALOR >= p_fec_inicial
      AND FEC_VALOR <= p_fec_final
      AND TIPO IN ('C','D')
      AND AFECTA <> 'N'
      AND VE_CLIENTE = 'S'
 UNION ALL
    SELECT FEC_VALOR, MONTO, T.COD_TRANSACCION, DECODE(T.COD_TRANSACCION,515,'C',560,'C',565,'C',TIPO)
      FROM GE_TRANSACCIONES T, GE_MOVIMIENTOS M
     WHERE T.COD_MODULO = p_cod_modulo
       AND T.COD_MODALIDAD = p_cod_modalidad
       AND M.NRO_CUENTA = p_nro_cuenta
       AND T.COD_TRANSACCION = M.COD_TRANSACCION
       AND T.COD_MODULO = M.COD_MODULO
       AND T.COD_MODALIDAD = M.COD_MODALIDAD
       AND FEC_VALOR >= p_fec_inicial
       AND FEC_VALOR <= p_fec_final
       AND TIPO IN ('C','D')
       AND VE_CLIENTE = 'S'
       AND AFECTA <> 'N'
    ORDER  BY 1;
BEGIN
--dbms_output.put_line('Entre a acumulado');
    --Obtiene la moneda local
    v_cod_mon_local:= pag_gen.fu_obt_mon_local;
    If p_fec_inicial = to_date('01'||to_char(p_fec_inicial, 'MMYYYY'), 'DDMMYYYY') and
       (p_fec_final = last_day(p_fec_final) or p_fec_final = PAA_DEV.G_ULT_MES_HABIL) Then
       --- Busca el saldo promedio ---
       pag_cta.PR_OBT_SAL_PROMEDIO (p_cod_modulo,
                                    p_cod_modalidad,
                                    p_cod_oficina,
                                    p_nro_cuenta,
                                    p_fec_inicial,
                                    p_fec_final,
                                    p_sal_acumulado,
                                    p_sal_promedio,
                                    p_can_dia_acumulado);
       -- Obtiene el Saldo Final por si tenga que utilizar para el proximo sub-periodo
       begin
         Select sal_ini_mes
           into p_saldo
           from ah_sal_mensuales
          where nro_cuenta = p_nro_cuenta
            and mes = to_number(to_char(add_months(p_fec_final,1), 'MM'))
            and ano = to_number(to_char(add_months(p_fec_final,1), 'YYYY'));
       exception
          when no_data_found then
             p_saldo := 0;
       end;
    Else
       p_can_dia_acumulado := p_fec_final - p_fec_inicial + 1;

       p_sal_acumulado := p_saldo; --Inicializa Acumulado al Saldo Inicial
       p_sal_acumulado := (NVL(p_sal_acumulado,0) * NVL(p_can_dia_acumulado,0));


       IF c_mov_historicos%ISOPEN THEN
          CLOSE c_mov_historicos;
       END IF;
    --dbms_output.put_line('A leer cursor');
       OPEN c_mov_historicos;
          LOOP
             FETCH c_mov_historicos
             INTO v_fec_valor, v_monto, v_cod_transaccion, v_tip_detalle;
             EXIT WHEN c_mov_historicos%NOTFOUND;

             --Calcula el Saldo Acumulado
/*             if p_cod_moneda = v_cod_mon_local \*and
                v_cod_transaccion not in(515, 565)*\ then
                if v_tip_detalle = 'C' then
                   p_sal_acumulado := p_sal_acumulado +((p_fec_final-v_fec_valor+1)*v_monto);
                   p_saldo := p_saldo + v_monto;
                else
                   p_sal_acumulado := p_sal_acumulado -((p_fec_final-v_fec_valor+1)*v_monto);
                   p_saldo := p_saldo - v_monto;
                end if;
             end if;
             if p_cod_moneda <> v_cod_mon_local and
                v_cod_transaccion not in(607, 610) then
                if v_tip_detalle = 'C' then
                   p_sal_acumulado := p_sal_acumulado +((p_fec_final-v_fec_valor+1)*v_monto);
                   p_saldo := p_saldo + v_monto;
                else
                   p_sal_acumulado := p_sal_acumulado -((p_fec_final-v_fec_valor+1)*v_monto);
                   p_saldo := p_saldo - v_monto;
                end if;
             end if;*/
             if v_tip_detalle  = 'C'  THEN
                p_sal_acumulado := p_sal_acumulado + ((p_fec_final-v_fec_valor+1)*v_monto);
                p_saldo  := to_number(p_saldo) + v_monto;
             else
                p_sal_acumulado := p_sal_acumulado -((p_fec_final-v_fec_valor+1)*v_monto);
                p_saldo := p_saldo - v_monto;
             end if;
          END LOOP;
          If nvl(p_can_dia_acumulado,0) > 0 then
            p_sal_promedio := p_sal_acumulado/ p_can_dia_acumulado;
          End if;
    End If;
END;
BEGIN
   --Obtiene la moneda local
   v_cod_mon_local:= pag_gen.fu_obt_mon_local;
   -- v_sal_disponible    := 0; --mientras tanto, ver donde se asigna el valor en el original,
   v_sal_acumulado     := 0;
   v_mto_int_acumulado := 0;
   v_fec_inicial       := p_fec_inicial;
   v_fec_final         := p_fec_final;
   v_fin_tasa          := 'N';
   ---
   LOOP
      EXIT WHEN v_fin_tasa = 'S';
      -- Obtengo la sgte fecha de vigencia ---
      paa_cta.pr_tas_sig_vigencia(paa_dev.g_cod_tasa,3,31,paa_dev.g_cod_oficina,
                                  paa_dev.g_cod_moneda, paa_dev.g_nro_cuenta,
                                  v_fec_inicial, p_fec_final,
                                  v_sig_fec_vigencia, v_fin_tasa);
      v_fec_final := v_sig_fec_vigencia-1;
      -- modificacion para Banco Regional
      if to_char(v_fec_final,'yyyymm') <> to_char(v_fec_inicial,'yyyymm') then
         v_fec_final := last_day(v_fec_inicial); -- ultimo dia del mes
         v_sig_fec_vigencia := v_fec_final + 1;
         v_fin_tasa := 'N';
      end if;
      -- calculo el promedio del sub-periodo
       lp_cal_sal_acumulado(3, --modulo
                            paa_dev.g_cod_modalidad,
                            paa_dev.g_cod_oficina,
                            paa_dev.g_nro_cuenta,
                            v_fec_inicial,
                            v_fec_final,
                            paa_dev.g_cod_moneda,
                            --- OUT
                            p_saldo,
                            v_sal_promedio,
                            v_sal_acumulado,
                            v_can_dia_acumulado);
      -- si hay sub periodo que calcular
      if v_can_dia_acumulado > 0 then
         --
         pag_gen.pr_obt_val_tasa(paa_dev.g_cod_modulo,  paa_dev.g_cod_modalidad,
                                 paa_dev.g_cod_oficina, paa_dev.g_nro_cuenta,
                                 paa_dev.g_cod_moneda,  v_sal_promedio,
                                 paa_dev.g_tas_personalizada, paa_dev.g_cod_tasa,
                                 null,    v_fec_final,
                                 --- OUT ---
                                 v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
         v_mto_interes :=  pag_gen.fu_cal_int_simple((v_sal_acumulado/v_can_dia_acumulado),
                                                      v_can_dia_acumulado,
                                                      v_val_tasa);
      else
         v_val_tasa    := 0; --- Si no tuvo promedios
         v_mto_interes := 0;
      end if;
----
      -- Redondeo del Interes.
      ---------------------------------------------------
      -- Si la Moneda de la Cuenta es igual a la Moneda Local
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',3,paa_dev.G_COD_MODALIDAD,paa_dev.g_cod_moneda);
      v_mto_interes := round(v_mto_interes,v_redondeo);
      --- Insertar devengado
      PAA_DEV.G_LUGAR := 'Procesar AH_DEVENGADOS (PR_CAL_AH_DEVENGADOS)';
---dbms_output.put_line('Devengado '||v_mto_interes);
      PAA_DEV.PR_PRO_AH_DEVENGADOS(v_fec_inicial, v_can_dia_acumulado, V_MTO_INTERES,
                                   v_sal_acumulado, v_val_tasa, v_fec_inicial, 0);
      --
      v_mto_int_acumulado := v_mto_int_acumulado + v_mto_interes;
      -----------------------------------------------------------------------
      -- v_tas_vigente := v_sig_val_tasa;
      v_fec_inicial := v_sig_fec_vigencia;
   END LOOP;
exception
   when others then
      raise_application_error(-20020,'Dev. Cta. '||paa_dev.g_nro_cuenta||' '||sqlerrm);
END;
/* Devengamiento de AH_CTA_CERTIFICADOS. */
PROCEDURE PR_DEV_AH_CTA_CERTIF
 (P_CIERRE VARCHAR2 DEFAULT null)
 IS

V_TIP_CAPITALIZACION AH_CTA_PLAZOS.TIP_CAPITALIZACION%TYPE;
-- SELECCIONA CDA PARA DEVENGAR
   CURSOR C_AH_CTA_CERTIFICADOS IS
      SELECT COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA, FEC_APERTURA,
           CAPITAL, FEC_VENCIMIENTO, COD_TASA, TAS_PERSONALIZADA, FEC_ULT_CAPITALIZACION
      FROM AH_CTA_CERTIFICADOS
     WHERE ((NVL(P_CIERRE,'N') = 'N' AND  -- Si es por dev. diario normal
             EST_BATCH NOT IN ('V','A','T','P','C','X') AND
             NVL(FEC_ULT_CAPITALIZACION, FEC_APERTURA) <= PAA_DEV.G_FEC_HOY AND
             FEC_VENCIMIENTO > PAA_DEV.G_FEC_ANTERIOR + 1) OR
            (NVL(P_CIERRE,'N') = 'S' AND -- Si es el cierre mensual
             ESTADO NOT IN ('V','A','T','P','C','X') AND
             FEC_APERTURA = PAA_DEV.G_FEC_HOY AND
             FEC_VENCIMIENTO > PAA_DEV.G_FEC_HOY))
       UNION -- Bonos Subordinados via SEN. RABF-12/01/2012
      SELECT A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA, A.NRO_CUENTA, A.COD_MONEDA, A.FEC_APERTURA,
           A.CAPITAL, A.FEC_VENCIMIENTO, A.COD_TASA, A.TAS_PERSONALIZADA, A.FEC_ULT_CAPITALIZACION
      FROM AH_CTA_CERTIFICADOS A, AH_TITULOS T
     WHERE ((NVL(P_CIERRE,'N') = 'N' AND  -- SI ES POR DEV. DIARIO NORMAL
             A.EST_BATCH NOT IN ('V','A','T','P','C','X') AND
             NVL(A.FEC_ULT_CAPITALIZACION, A.FEC_APERTURA) <= PAA_DEV.G_FEC_HOY AND
             A.FEC_VENCIMIENTO > PAA_DEV.G_FEC_ANTERIOR + 1) OR
            (NVL(P_CIERRE,'N') = 'S' AND -- SI ES EL CIERRE MENSUAL
             A.ESTADO NOT IN ('V','A','T','P','C','X') AND
             A.FEC_VENCIMIENTO > PAA_DEV.G_FEC_HOY
             AND NOT EXISTS (SELECT 1 FROM AH_DEVENGADOS D
                             WHERE  D.NRO_CUENTA = A.NRO_CUENTA)
             AND NOT EXISTS (SELECT 1 FROM AH_DEVENGADOS_HIS H
                             WHERE  H.NRO_CUENTA = A.NRO_CUENTA)))
             AND A.SER_TITULO = T.SERIE
             AND A.NRO_TITULO = T.NRO_TITULO
             AND T.SER_ORIGEN = 'SEN';
BEGIN
--
   FOR CTA_A_DEV IN C_AH_CTA_CERTIFICADOS LOOP
      PAA_DEV.G_LUGAR := 'INICIALIZA VARIABLE ';
      PAA_DEV.G_COD_MODULO := CTA_A_DEV.COD_MODULO;
      PAA_DEV.G_COD_MODALIDAD := CTA_A_DEV.COD_MODALIDAD;
      PAA_DEV.G_COD_OFICINA := CTA_A_DEV.COD_OFICINA;
      PAA_DEV.G_NRO_CUENTA := CTA_A_DEV.NRO_CUENTA;
      PAA_DEV.G_COD_MONEDA := CTA_A_DEV.COD_MONEDA;
      PAA_DEV.G_FEC_APERTURA := CTA_A_DEV.FEC_APERTURA;
      PAA_DEV.G_FEC_VENCIMIENTO := CTA_A_DEV.FEC_VENCIMIENTO;
      PAA_DEV.G_FEC_ULT_CAPITALIZACION := CTA_A_DEV.FEC_ULT_CAPITALIZACION;
      PAA_DEV.G_COD_TASA := CTA_A_DEV.COD_TASA;
      PAA_DEV.G_MTO_CAPITAL := CTA_A_DEV.CAPITAL;

      -- fecha de inicio del devengamiento
      PAA_DEV.G_LUGAR := 'Inicializa la fecha inicio del Devengado';
      IF PAA_DEV.G_FEC_ULT_CAPITALIZACION IS NULL THEN
         PAA_DEV.G_FEC_INICIO := PAA_DEV.G_FEC_APERTURA;
      ELSE ---IF PAA_DEV.G_FEC_ULT_CAPITALIZACION >= PAA_DEV.G_FEC_APERTURA THEN
         PAA_DEV.G_FEC_INICIO := PAA_DEV.G_FEC_ULT_CAPITALIZACION;
      END IF;
      -- fecha fin del devengamiento--
      IF PAA_DEV.G_FEC_HOY = PAA_DEV.G_ULT_MES_HABIL THEN
         --PAA_DEV.G_FEC_INICIO := PAA_DEV.G_FEC_HOY;
         PAA_DEV.G_FEC_FINAL := PAA_DEV.G_ULT_DIA_MES;
      --ELSIF PAA_DEV.G_FEC_HOY = PAA_DEV.G_PRI_MES_HABIL AND PAA_DEV.G_PRI_MES_HABIL != PAA_DEV.G_PRI_DIA_MES THEN
      --   PAA_DEV.G_FEC_INICIO := PAA_DEV.G_PRI_DIA_MES;
      --   PAA_DEV.G_FEC_FINAL := PAA_DEV.G_FEC_PROXIMA - 1;
      ELSE
         --PAA_DEV.G_FEC_INICIO := PAA_DEV.G_FEC_ANTERIOR + 1;
         PAA_DEV.G_FEC_FINAL := PAA_DEV.G_FEC_HOY;
      END IF;
      -- Se ajusta la fecha del devengamiento si ya vence el capital
      IF PAA_DEV.G_FEC_FINAL >= PAA_DEV.G_FEC_VENCIMIENTO THEN
         PAA_DEV.G_FEC_FINAL := PAA_DEV.G_FEC_VENCIMIENTO -1;
      END IF;
      -- calculo del devengamiento
      V_TIP_CAPITALIZACION := 1;
      PAA_DEV.G_LUGAR := 'PR_DEV_AH_CTA_CERTIFICADOS';
      PAA_DEV.PR_CAL_DEV_AH_CTA_PL(PAA_DEV.G_FEC_INICIO,
                                   PAA_DEV.G_FEC_FINAL, PAA_DEV.G_MTO_CAPITAL,
                                   CTA_A_DEV.TAS_PERSONALIZADA, CTA_A_DEV.FEC_APERTURA,
                                   CTA_A_DEV.FEC_ULT_CAPITALIZACION, V_TIP_CAPITALIZACION);
      --
   END LOOP;
END;
   --;
/* Devengamiento de AH_CTA_PLAZOS. */
PROCEDURE PR_DEV_AH_CTA_PLAZOS (P_CIERRE VARCHAR2 DEFAULT null)
 IS
-- SELECCIONA AH_CTA_PLAZOS
   CURSOR C_AH_CTA_PLAZOS IS
    SELECT COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA, FEC_ULT_CAPITALIZACION,
           FEC_APERTURA, CAPITAL, COD_TASA, TAS_PERSONALIZADA, FEC_VENCIMIENTO, TIP_CAPITALIZACION, VAL_TASA
      FROM AH_CTA_PLAZOS A
     WHERE A.COD_MODALIDAD = 37 --CVDAHPRO-1 - Devenga Solo Ahorro Plazo Fijo--
       AND (
             (NVL(P_CIERRE,'N') = 'N' AND 
              EST_BATCH NOT IN ('V','A','T','P','C','X') AND
              NVL(FEC_ULT_CAPITALIZACION, FEC_APERTURA) <= PAA_DEV.G_FEC_HOY AND
              FEC_VENCIMIENTO > PAA_DEV.G_FEC_ANTERIOR + 1)
          OR (NVL(P_CIERRE,'N') = 'S' AND
              ESTADO NOT IN ('V','A','T','P','C','X') AND
              FEC_APERTURA = PAA_DEV.G_FEC_HOY AND
              FEC_VENCIMIENTO > PAA_DEV.G_FEC_HOY)
           );
BEGIN
   --
      FOR CTA_A_DEV IN C_AH_CTA_PLAZOS  LOOP
         PAA_DEV.G_LUGAR := 'INICIALIZA VARIABLE ';
         PAA_DEV.G_COD_MODULO := CTA_A_DEV.COD_MODULO;
         PAA_DEV.G_COD_MODALIDAD := CTA_A_DEV.COD_MODALIDAD;
         PAA_DEV.G_COD_OFICINA := CTA_A_DEV.COD_OFICINA;
         PAA_DEV.G_NRO_CUENTA := CTA_A_DEV.NRO_CUENTA;
         PAA_DEV.G_COD_MONEDA := CTA_A_DEV.COD_MONEDA;
         PAA_DEV.G_FEC_VENCIMIENTO := CTA_A_DEV.FEC_VENCIMIENTO;
         PAA_DEV.G_FEC_ULT_CAPITALIZACION := CTA_A_DEV.FEC_ULT_CAPITALIZACION;
         PAA_DEV.G_FEC_APERTURA := CTA_A_DEV.FEC_APERTURA;
         PAA_DEV.G_COD_TASA := CTA_A_DEV.COD_TASA;
         PAA_DEV.G_SAL_DISPONIBLE := CTA_A_DEV.CAPITAL;
         PAA_DEV.G_VAL_TASA := CTA_A_DEV.VAL_TASA;
         --
         PAA_DEV.G_LUGAR := 'Inicializa la fecha inicio del Devengado';
         IF PAA_DEV.G_FEC_ULT_CAPITALIZACION IS NULL THEN
            PAA_DEV.G_FEC_INICIO := PAA_DEV.G_FEC_APERTURA;
         ELSE --IF PAA_DEV.G_FEC_ULT_CAPITALIZACION >= PAA_DEV.G_FEC_APERTURA THEN
            PAA_DEV.G_FEC_INICIO := PAA_DEV.G_FEC_ULT_CAPITALIZACION +1 ;
         END IF;
         --
         IF PAA_DEV.G_FEC_HOY = PAA_DEV.G_ULT_MES_HABIL THEN
            --PAA_DEV.G_FEC_INICIO := PAA_DEV.G_FEC_HOY;
            PAA_DEV.G_FEC_FINAL := PAA_DEV.G_ULT_DIA_MES;
         --ELSIF PAA_DEV.G_FEC_HOY = PAA_DEV.G_PRI_MES_HABIL AND PAA_DEV.G_PRI_MES_HABIL != PAA_DEV.G_PRI_DIA_MES THEN
         --   PAA_DEV.G_FEC_INICIO := PAA_DEV.G_PRI_DIA_MES;
         --   PAA_DEV.G_FEC_FINAL := PAA_DEV.G_FEC_PROXIMA - 1;
         ELSE
            --PAA_DEV.G_FEC_INICIO := PAA_DEV.G_FEC_ANTERIOR + 1;
            PAA_DEV.G_FEC_FINAL := PAA_DEV.G_FEC_HOY;
         END IF;
         --
         IF PAA_DEV.G_FEC_FINAL >= PAA_DEV.G_FEC_VENCIMIENTO THEN
            PAA_DEV.G_FEC_FINAL := PAA_DEV.G_FEC_VENCIMIENTO -1;
         END IF;
            PAA_DEV.G_LUGAR := 'PR_CAL_DEV_AH_CTA_PLAZOS';
            PAA_DEV.PR_CAL_DEV_AH_CTA_PL(PAA_DEV.G_FEC_INICIO,PAA_DEV.G_FEC_FINAL,PAA_DEV.G_SAL_DISPONIBLE,
                                      CTA_A_DEV.TAS_PERSONALIZADA,CTA_A_DEV.FEC_APERTURA,
                                      CTA_A_DEV.FEC_ULT_CAPITALIZACION, CTA_A_DEV.TIP_CAPITALIZACION);
      --
      END LOOP;
   END;
   --;
/* Devengar AH_CTA_VISTAS. */
PROCEDURE PR_DEV_AH_CTA_VISTAS
 IS
-- Selecciona ahorros a la vista para devengar
   CURSOR C_AH_CTA_VISTAS IS
      SELECT COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA, FEC_APERTURA,
        FEC_ULT_CAPITALIZACION, SAL_MINIMO, TAS_PERSONALIZADA, SAL_TOTAL, COD_TASA,
       (SAL_TOTAL + MTO_CRE_A_CONFIRMAR) - (SAL_BLOQUEADO + SAL_RETENIDO + MTO_CRE_PENDIENTES + MTO_DEB_PENDIENTES) SAL_DISPONIBLE,
        SAL_ULT_CAPITALIZACION, COD_SUB_MODALIDAD
      FROM AH_CTA_VISTAS
     WHERE ESTADO NOT IN ('C','A','P','X','T')
     AND FEC_APERTURA <= PAA_DEV.G_FEC_HOY; -- 03/03/2014. CB. DYDMR-371
BEGIN
      PAA_DEV.G_LUGAR := 'Empieza el ciclo';
      FOR CTA_A_DEV IN C_AH_CTA_VISTAS  LOOP
         PAA_DEV.G_LUGAR             := 'INICIALIZA VARIABLE ';
         PAA_DEV.G_SECUENCIA         := 0;
         PAA_DEV.G_COD_MODULO        := CTA_A_DEV.COD_MODULO;
         PAA_DEV.G_COD_MODALIDAD     := CTA_A_DEV.COD_MODALIDAD;
         PAA_DEV.G_COD_SUB_MODALIDAD := CTA_A_DEV.COD_SUB_MODALIDAD;
         PAA_DEV.G_COD_OFICINA       := CTA_A_DEV.COD_OFICINA;
         PAA_DEV.G_NRO_CUENTA        := CTA_A_DEV.NRO_CUENTA;
         PAA_DEV.G_COD_MONEDA        := CTA_A_DEV.COD_MONEDA;
         PAA_DEV.G_FEC_ULT_CAPITALIZACION := CTA_A_DEV.FEC_ULT_CAPITALIZACION;
         PAA_DEV.G_FEC_APERTURA      := CTA_A_DEV.FEC_APERTURA;
         PAA_DEV.G_COD_TASA          := CTA_A_DEV.COD_TASA;
         PAA_DEV.G_SAL_DISPONIBLE    := CTA_A_DEV.SAL_DISPONIBLE;
         PAA_DEV.G_TAS_PERSONALIZADA := CTA_A_DEV.TAS_PERSONALIZADA;
         --
         IF PAA_DEV.G_FEC_HOY = PAA_DEV.G_ULT_MES_HABIL THEN
            PAA_DEV.G_FEC_FINAL := PAA_DEV.G_ULT_DIA_MES;
         ELSIF PAA_DEV.G_FEC_HOY = PAA_DEV.G_PRI_MES_HABIL AND PAA_DEV.G_PRI_MES_HABIL != PAA_DEV.G_PRI_DIA_MES THEN
            PAA_DEV.G_FEC_FINAL := PAA_DEV.G_FEC_PROXIMA - 1;
         ELSE
            PAA_DEV.G_FEC_FINAL := PAA_DEV.G_FEC_PROXIMA - 1;
         END IF;
         --
         PAA_DEV.G_LUGAR := 'Inicializa la fecha inicio del Devengado';
         IF PAA_DEV.G_FEC_ULT_CAPITALIZACION IS NULL THEN
            PAA_DEV.G_FEC_INICIO := PAA_DEV.G_FEC_APERTURA;
         ELSIF PAA_DEV.G_FEC_ULT_CAPITALIZACION >= PAA_DEV.G_FEC_APERTURA THEN
            PAA_DEV.G_FEC_INICIO := PAA_DEV.G_FEC_ULT_CAPITALIZACION + 1 ;
         ELSE
            raise_application_error(-20021,
            'Fecha de ultima capitalización no puede ser menor a la de apertura');
         END IF;
         --
         PAA_DEV.G_LUGAR := 'Inicializa Saldo Minimo Pactado';

         IF CTA_A_DEV.SAL_MINIMO IS NULL THEN
            --
            PAA_DEV.G_LUGAR := 'Obtener Parametro Saldo Minimo';
            --recuperar el saldo minimo del parametro
            DECLARE
              v_cod_persona varchar2(15) := fug_obt_cli_principal(PAA_DEV.G_NRO_CUENTA);
            BEGIN
               PAA_DEV.G_SAL_MIN_GENERAL := FUG_OBT_SAL_MIN_PACTADO(PAA_DEV.G_COD_MONEDA, v_cod_persona, PAA_DEV.G_COD_MODULO,
                               PAA_DEV.G_COD_MODALIDAD, PAA_DEV.G_COD_OFICINA, PAA_DEV.G_COD_SUB_MODALIDAD);
            END;
            PAA_DEV.G_SAL_MIN_PACTADO := PAA_DEV.G_SAL_MIN_GENERAL;
         ELSE
            PAA_DEV.G_SAL_MIN_PACTADO := CTA_A_DEV.SAL_MINIMO;
         END IF;
         --
         PAA_DEV.G_LUGAR := 'Obtener Saldo Promedio AH_CTA_VISTAS';
         PAG_CTA.PR_OBT_SAL_PROMEDIO(PAA_DEV.G_COD_MODULO, PAA_DEV.G_COD_MODALIDAD, PAA_DEV.G_COD_OFICINA,
                                     PAA_DEV.G_NRO_CUENTA, PAA_DEV.G_FEC_INICIO, PAA_DEV.G_FEC_FINAL,
                                     PAA_DEV.G_SAL_ACUMULADO, PAA_DEV.G_SAL_PROMEDIO, PAA_DEV.G_DIA_ACUMULADO);
---dbms_output.put_line('Cta '||paa_dev.g_nro_cuenta||' Prom '||paa_dev.g_sal_promedio||' Acum '||paa_dev.g_sal_acumulado||' Ini '||paa_dev.g_fec_inicio);
         PAA_DEV.G_LUGAR := 'Calcular devengado AH_CTA_VISTAS';
         --- Esta rutina debe coincidir con la capitalización de ahorro a la vista
         PAA_DEV.PR_CAL_AH_DEVENGADOS(PAA_DEV.G_FEC_INICIO, PAA_DEV.G_FEC_FINAL,  CTA_A_DEV.SAL_ULT_CAPITALIZACION,
                                      PAA_DEV.G_SAL_PROMEDIO, PAA_DEV.G_SAL_ACUMULADO, PAA_DEV.G_DIA_ACUMULADO );
         --
         PAA_DEV.G_LUGAR := 'Reversion de devengamiento AH_CTA_VISTAS';
         PAA_DEV.PR_REV_AH_DEVENGADOS(PAA_DEV.G_NRO_CUENTA, PAA_DEV.G_FEC_INICIO, PAA_DEV.G_FEC_FINAL,PAA_DEV.G_FEC_HOY);
         --
      END LOOP;
   END;
/* Devengar AH_CTA_PLAZOS Y AH_CTA_CERTIFICADOS. */
PROCEDURE PR_PF_CDA_PRINCIPAL
 IS
--RUTINA PRINCIPAL
PROCEDURE PF_CDA IS

   BEGIN
      PAA_DEV.G_LUGAR := 'Obtener Moneda Local';
      PAA_DEV.G_MON_LOCAL := PAG_GEN.FU_OBT_MON_LOCAL;
      --
      PAA_DEV.G_LUGAR := 'Obtiene cambio de GE_CALENDARIOS';
      PAG_CAL.PR_OBT_DAT_CALENDAR(PAA_DEV.G_COD_MODULO);
      --
      PAA_DEV.G_FEC_HOY := PAG_CAL.G_FEC_ACTUAL;
      PAA_DEV.G_ULT_MES_HABIL := PAG_CAL.G_ULT_DIA_MES_HABIL;
      PAA_DEV.G_ULT_DIA_MES := PAG_CAL.G_ULT_DIA_MES;
      PAA_DEV.G_FEC_PROXIMA := PAG_CAL.G_FEC_PROXIMA;
      PAA_DEV.G_PRI_DIA_MES := PAG_CAL.G_PRI_DIA_MES_HABIL;
      PAA_DEV.G_PRI_MES_HABIL := PAG_CAL.G_PRI_DIA_MES_HABIL;
      PAA_DEV.G_FEC_ANTERIOR := PAG_CAL.G_FEC_ANTERIOR;
      --
      PAA_DEV.G_LUGAR := 'Devengamiento Plazo fijo';
      PR_DEV_AH_CTA_PLAZOS;
      --
      PAA_DEV.G_LUGAR := 'Devengamiento CDA';
      PR_DEV_AH_CTA_CERTIF;
      --
   EXCEPTION
     WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20001,SQLERRM||' '||PAA_DEV.G_LUGAR);
   END;
BEGIN
  NULL;
END PR_PF_CDA_PRINCIPAL;
/* Devengar Captaciones */
PROCEDURE PR_AH_PRINCIPAL
 IS
BEGIN
--dbms_output.put_line('Entro al procedimiento');
      PAA_DEV.G_LUGAR     := 'Obtener Moneda Local';
      PAA_DEV.G_MON_LOCAL := PAG_GEN.FU_OBT_MON_LOCAL;
   --
      PAA_DEV.G_LUGAR := 'Obtiene cambio de GE_CALENDRIOS';
      PAG_CAL.PR_OBT_DAT_CALENDAR(PAA_DEV.G_COD_MODULO);
   --
   --
      PAA_DEV.G_FEC_HOY       := PAG_CAL.G_FEC_ACTUAL;
      PAA_DEV.G_ULT_MES_HABIL := PAG_CAL.G_ULT_DIA_MES_HABIL;
      PAA_DEV.G_ULT_DIA_MES   := PAG_CAL.G_ULT_DIA_MES;
      PAA_DEV.G_FEC_PROXIMA   := PAG_CAL.G_FEC_PROXIMA;
      PAA_DEV.G_PRI_DIA_MES   := PAG_CAL.G_PRI_DIA_MES;
      PAA_DEV.G_PRI_MES_HABIL := PAG_CAL.G_PRI_DIA_MES_HABIL;
   --
      PAA_DEV.G_LUGAR := 'Devengamiento Ahorro a la vista';
      PR_DEV_AH_CTA_VISTAS;
   --
   EXCEPTION
      WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20001,SQLERRM||' '||PAA_DEV.G_LUGAR);
   END;

/* Devengar Plusvalia y Minusvalia de Bonos Subordinados. */
PROCEDURE PR_DEV_BON_SUBORDINADOS
 IS
   v_fec_actual DATE := pag_cal.fu_obt_fec_actual(3);
   ---
   CURSOR rg_movi IS
      SELECT b.nro_cuenta,
             b.monto,
             b.fec_inicio,
             b.fec_vencimiento,
             b.fec_ult_proceso,
             b.mto_dev_anterior,
             b.mto_dev_actual,
             b.mto_dev_acumulado,
             b.estado,
             b.can_dia_actual,
             b.can_dia_anterior,
             b.cod_modulo,
             b.cod_modalidad,
             b.cod_moneda,
             c.estado est_cuenta,
             c.cod_oficina,
             b.cod_usuario,
             b.cod_transaccion,
             b.concepto
        FROM ah_dev_bon_subordinados b, ge_cuentas c
       WHERE b.mto_dev_acumulado < b.monto
         AND b.nro_cuenta = c.nro_cuenta
         AND b.fec_inicio < v_fec_actual
         AND b.estado <> 'C'
         AND c.estado in ('C','N');
   ---
   v_fec_calculo         DATE;
   v_can_dia_anterior    ge_mov_diferidos.can_dia_anterior%TYPE;
   v_can_dia_actual      ge_mov_diferidos.can_dia_actual%TYPE;
   v_mto_dev_anterior    ge_mov_diferidos.mto_dev_anterior%TYPE;
   v_mto_dev_actual      ge_mov_diferidos.mto_dev_actual%TYPE;
   v_mto_dev_acumulado   ge_mov_diferidos.mto_dev_acumulado%TYPE;
   v_can_tot_dias        NUMBER;
   v_estado              ge_mov_diferidos.estado%TYPE;
   v_redondeo            NUMBER(5);
   v_nro_secuencia       ge_movimientos.nro_secuencia%TYPE := 0;
   v_hora                ge_movimientos.hora%TYPE := to_char(SYSDATE, 'hh24:mi:ss');
   r_gmovi               ge_movimientos%ROWTYPE;
BEGIN
   FOR i IN rg_movi LOOP
      v_can_dia_anterior := i.can_dia_actual;
      v_mto_dev_anterior := i.mto_dev_actual;
      v_can_tot_dias     := i.fec_vencimiento - i.fec_inicio;
      v_can_dia_actual   := 0;
      v_mto_dev_actual   := 0;
      --- Cuentas canceladas deben devengar totalmente
      IF (i.est_cuenta = 'C') OR (v_fec_actual > i.fec_vencimiento) THEN
         v_fec_calculo := i.fec_vencimiento;
      ELSE
         v_fec_calculo := v_fec_actual;
      END IF;
      ---
      v_can_dia_actual := v_fec_calculo - nvl(i.fec_ult_proceso, i.fec_inicio);
      ---
      IF v_can_dia_actual > 0 THEN
         -- Si la Moneda de la Cuenta es igual a la Moneda Local
         v_redondeo       := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 3, 36, i.cod_moneda);
         v_mto_dev_actual := round(i.monto / v_can_tot_dias * v_can_dia_actual, v_redondeo);
         -- Se verifica si corresponde a una reversión
         IF i.mto_dev_acumulado >= i.monto AND i.fec_vencimiento > v_fec_actual THEN
            i.mto_dev_acumulado := i.mto_dev_acumulado - i.mto_dev_actual;
            v_estado            := 'C';
         ELSE
            v_estado := 'N';
         END IF;
         -- para redondear correctamente en el último devengado
         IF (i.mto_dev_acumulado + v_mto_dev_actual) > i.monto THEN
            v_mto_dev_actual := i.monto - i.mto_dev_acumulado;
         END IF;
         ---
         v_mto_dev_acumulado := i.mto_dev_acumulado + v_mto_dev_actual;
         ---
         IF nvl(v_mto_dev_acumulado, 0) > 0 THEN
            IF v_nro_secuencia > 990 THEN
               v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
               v_nro_secuencia := -999;
            ELSE
               v_nro_secuencia := v_nro_secuencia + 1;
            END IF;
            r_gmovi.cod_usuario       := i.cod_usuario;
            r_gmovi.hora              := v_hora;
            r_gmovi.nro_secuencia     := v_nro_secuencia;
            r_gmovi.cod_modulo        := i.cod_modulo;
            r_gmovi.cod_modalidad     := i.cod_modalidad;
            r_gmovi.cod_oficina       := i.cod_oficina;
            r_gmovi.nro_cuenta        := NULL;
            r_gmovi.cod_moneda        := i.cod_moneda;
            r_gmovi.fecha             := v_fec_actual;
            r_gmovi.fec_valor         := v_fec_actual;
            r_gmovi.cod_tra_padre     := 3631;
            r_gmovi.cod_transaccion   := i.cod_transaccion;
            r_gmovi.nro_documento     := i.nro_cuenta;
            r_gmovi.nro_documento3    := NULL;
            r_gmovi.monto             := nvl(v_mto_dev_acumulado, 0);
            r_gmovi.estado            := 'N';
            r_gmovi.cod_ofi_origen    := i.cod_oficina;
            r_gmovi.concepto          := i.concepto;
            r_gmovi.reversado         := 'N';
            r_gmovi.emi_aviso         := 'N';
            r_gmovi.protegido         := 'N';
            r_gmovi.cod_mod_padre     := i.cod_modulo;
            r_gmovi.cod_mad_padre     := i.cod_modalidad;
            r_gmovi.tip_mov_rubro     := NULL;
            r_gmovi.cod_rubro         := NULL;
            r_gmovi.referencia        := i.nro_cuenta;
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
         END IF;
         ---
         UPDATE ah_dev_bon_subordinados
            SET can_dia_anterior  = v_can_dia_anterior,
                can_dia_actual    = v_can_dia_actual,
                mto_dev_anterior  = v_mto_dev_anterior,
                mto_dev_actual    = v_mto_dev_actual,
                mto_dev_acumulado = v_mto_dev_acumulado,
                estado            = v_estado,
                fec_ult_proceso   = v_fec_actual
          WHERE nro_cuenta = i.nro_cuenta;
      END IF;
   END LOOP;
END;

---
FUNCTION FU_BON_SUB_SEN (P_NRO_CUENTA GE_CUENTAS.NRO_CUENTA%TYPE)
   RETURN BOOLEAN
IS
   v_existe number(1):=0;
BEGIN
   SELECT 1
     INTO v_existe
     FROM AH_CTA_CERTIFICADOS A, AH_TITULOS T
    WHERE A.NRO_CUENTA = P_NRO_CUENTA
      AND A.SER_TITULO = T.SERIE
      AND A.NRO_TITULO = T.NRO_TITULO
      AND T.SER_ORIGEN = 'SEN';
   IF nvl(v_existe,0) = 1 THEN
     RETURN TRUE;
   ELSE
     RETURN FALSE;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
     RETURN FALSE;
END;

END PAA_DEV;
/

