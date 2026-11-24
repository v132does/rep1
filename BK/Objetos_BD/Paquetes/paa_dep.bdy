CREATE OR REPLACE PACKAGE BODY it.PAA_DEP IS
--Proyecto CVDAHPRO-1 Ahorro Programado--

G_SAL_ACUMULADO AH_CTA_PLAZOS.SAL_TOTAL%TYPE;
G_DIA_ACUMULADO AH_DEVENGADOS.CAN_DIA_INTERES%TYPE;
G_SECUENCIA NUMBER(3);
G_MTO_CAPITAL AH_CTA_CERTIFICADOS.CAPITAL%TYPE;
G_TAS_PERSONALIZADA AH_CTA_PLAZOS.TAS_PERSONALIZADA%TYPE;
G_SAL_DISPONIBLE AH_DEVENGADOS.SAL_ACUMULADO%TYPE;
G_FEC_APERTURA AH_CTA_PLAZOS.FEC_APERTURA%TYPE;
G_FEC_ULT_CAPITALIZACION AH_CTA_PLAZOS.FEC_ULT_CAPITALIZACION%TYPE;
G_FEC_INICIO AH_DEVENGADOS.FEC_INICIO%TYPE;
G_FEC_VENCIMIENTO AH_CTA_PLAZOS.FEC_VENCIMIENTO%TYPE;
TYPE typ_devengado IS TABLE OF ah_devengados%ROWTYPE ;
TYPE typ_devengado_his IS TABLE OF ah_devengados_his%ROWTYPE ;
reg_ins_devengado typ_devengado := typ_devengado();
reg_upd_devengado typ_devengado := typ_devengado();
reg_ins_his_devengado typ_devengado_his := typ_devengado_his();
reg_upd_his_devengado typ_devengado_his := typ_devengado_his();
TYPE typ_idx_control IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(50);
g_idx_control_ins typ_idx_control;

/* Actualiza la tabla devengados histórirco. */
PROCEDURE PR_PRO_AH_DEVENG_HIS
 (P_FEC_PROCESO IN DATE
 ,P_MTO_INTERES IN AH_DEVENGADOS_HIS.MTO_INTERES%TYPE
 )
 IS
 v_can number :=0;
 v_ano number;
 v_mes number;
 v_clave_idx varchar2(50);
 v_indice pls_integer;
BEGIN
    v_ano := TO_NUMBER(TO_CHAR(P_FEC_PROCESO, 'YYYY'));
    v_mes := TO_NUMBER(TO_CHAR(P_FEC_PROCESO, 'MM'));
   BEGIN
        v_clave_idx := paa_dep.g_NRO_CUENTA || '-' || v_ano || '-' || v_mes;
        SELECT count(1)
          INTO v_can
          FROM AH_DEVENGADOS_HIS
         WHERE NRO_CUENTA = paa_dep.g_NRO_CUENTA
           AND ANO = v_ano
           AND MES = v_mes;
    if v_can > 0 then
            reg_upd_his_devengado.EXTEND;
            reg_upd_his_devengado(reg_upd_his_devengado.count).cod_modulo := paa_dep.g_COD_MODULO;
            reg_upd_his_devengado(reg_upd_his_devengado.count).cod_modalidad := paa_dep.g_COD_MODALIDAD;
            reg_upd_his_devengado(reg_upd_his_devengado.count).cod_oficina := paa_dep.g_COD_OFICINA;
            reg_upd_his_devengado(reg_upd_his_devengado.count).nro_cuenta := paa_dep.g_NRO_CUENTA;
            reg_upd_his_devengado(reg_upd_his_devengado.count).mto_interes := P_MTO_INTERES;
            reg_upd_his_devengado(reg_upd_his_devengado.count).ano := v_ano;
            reg_upd_his_devengado(reg_upd_his_devengado.count).mes := v_mes;
    else
        
        IF g_idx_control_ins.EXISTS(v_clave_idx) THEN
            --Recuperamos su posición y sumamos el monto
            v_indice := g_idx_control_ins(v_clave_idx);
            reg_ins_his_devengado(v_indice).mto_interes := 
            NVL(reg_ins_his_devengado(v_indice).mto_interes,0) + P_MTO_INTERES;
        ELSE

                  -- No existe ni en BD ni en la coleccion: Creamos NUEVO INSERT
                  reg_ins_his_devengado.EXTEND;
                  v_indice := reg_ins_his_devengado.count;
                  
                  reg_ins_his_devengado(v_indice).cod_modulo := paa_dep.g_COD_MODULO;
                  reg_ins_his_devengado(v_indice).cod_modalidad := paa_dep.g_COD_MODALIDAD;
                  reg_ins_his_devengado(v_indice).cod_oficina := paa_dep.g_COD_OFICINA;
                  reg_ins_his_devengado(v_indice).nro_cuenta := paa_dep.g_NRO_CUENTA;
                  reg_ins_his_devengado(v_indice).mto_interes := P_MTO_INTERES;
                  reg_ins_his_devengado(v_indice).ano := v_ano;
                  reg_ins_his_devengado(v_indice).mes := v_mes;              
                  --Registramos en el índice para que la próxima vuelta lo encuentre
                  g_idx_control_ins(v_clave_idx) := v_indice;
        END IF;
     end if;
      EXCEPTION
         WHEN OTHERS THEN
             reg_ins_his_devengado.EXTEND;
             v_indice := reg_ins_his_devengado.count;
             reg_ins_his_devengado(v_indice).cod_modulo := paa_dep.g_COD_MODULO;
             reg_ins_his_devengado(v_indice).cod_modalidad := paa_dep.g_COD_MODALIDAD;
             reg_ins_his_devengado(v_indice).cod_oficina := paa_dep.g_COD_OFICINA;
             reg_ins_his_devengado(v_indice).nro_cuenta := paa_dep.g_NRO_CUENTA;
             reg_ins_his_devengado(v_indice).mto_interes := P_MTO_INTERES;
             reg_ins_his_devengado(v_indice).ano := v_ano;
             reg_ins_his_devengado(v_indice).mes := v_mes;
             
             g_idx_control_ins(v_clave_idx) := v_indice;

   END;
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
      paa_dep.g_LUGAR := 'INSERTAR AH_DEVENGADOS';
      reg_ins_devengado.EXTEND;
      reg_ins_devengado(reg_ins_devengado.count).nro_cuenta :=paa_dep.g_NRO_CUENTA;
      reg_ins_devengado(reg_ins_devengado.count).COD_MONEDA :=paa_dep.g_COD_MONEDA;
      reg_ins_devengado(reg_ins_devengado.count).FECHA :=paa_dep.g_FEC_HOY;
      reg_ins_devengado(reg_ins_devengado.count).VAL_TASA := p_VAL_TASA;
      reg_ins_devengado(reg_ins_devengado.count).FEC_TASA :=P_FEC_TASA;
      reg_ins_devengado(reg_ins_devengado.count).CAN_DIA_INTERES :=P_NRO_DIAS;
      reg_ins_devengado(reg_ins_devengado.count).SAL_ACUMULADO :=P_MTO_CAPITAL;
      reg_ins_devengado(reg_ins_devengado.count).MTO_INTERES :=P_MTO_INTERES;
      reg_ins_devengado(reg_ins_devengado.count).FEC_INICIO :=P_FEC_INICIO;
      reg_ins_devengado(reg_ins_devengado.count).MTO_DEV_ACUMULADO :=P_MTO_INTERES;
      reg_ins_devengado(reg_ins_devengado.count).MTO_AJUSTE :=P_MTO_AJUSTE;
   EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000, SQLERRM||' / '||paa_dep.g_LUGAR||' / '||paa_dep.g_NRO_CUENTA);
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
      paa_dep.g_LUGAR := 'ACTUALIZA AH_DEVENGADOS';
      V_INT_HOY := NVL(P_MTO_INTERES,0) - NVL(P_DEV_ACUMULADO,0);
      reg_upd_devengado.EXTEND;
      reg_upd_devengado(reg_upd_devengado.count).NRO_CUENTA:= P_NRO_CUENTA;
      reg_upd_devengado(reg_upd_devengado.count).FEC_INICIO:= P_FEC_INICIO;
      reg_upd_devengado(reg_upd_devengado.count).VAL_TASA:= P_VAL_TASA;
      reg_upd_devengado(reg_upd_devengado.count).MTO_DEV_ANTERIOR:= P_INT_ANTERIOR;
      reg_upd_devengado(reg_upd_devengado.count).DIA_DEV_ANTERIOR:= P_DIA_ANTERIORES;
      reg_upd_devengado(reg_upd_devengado.count).SAL_ACUMULADO:= P_MTO_CAPITAL;
      reg_upd_devengado(reg_upd_devengado.count).MTO_INTERES:=  V_INT_HOY;--V_ID.MTO_INTERES;
      reg_upd_devengado(reg_upd_devengado.count).MTO_DEV_ACUMULADO:= NVL(V_INT_HOY,0);--V_ID.MTO_DEV_ACUMULADO;
      reg_upd_devengado(reg_upd_devengado.count).CAN_DIA_INTERES:= P_NRO_DIAS;
      reg_upd_devengado(reg_upd_devengado.count).MTO_INTERES:= V_INT_HOY;
      reg_upd_devengado(reg_upd_devengado.count).MTO_AJUSTE:= P_MTO_AJUSTE;
      reg_upd_devengado(reg_upd_devengado.count).fecha:= paa_dep.g_FEC_HOY;
      reg_upd_devengado(reg_upd_devengado.count).VAL_TASA:=P_VAL_TASA;-- paa_dep.g_FEC_HOY;
  --
      paa_dep.g_LUGAR := 'PR_PRO_AH_DEVENGADOS_HIS(update_AH_DEVENGADOS)';
      PR_PRO_AH_DEVENG_HIS(P_FEC_INICIO + (P_NRO_DIAS - 1), V_INT_HOY);
 EXCEPTION
  WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20000, SQLERRM||' - '||paa_dep.g_LUGAR||' - '||P_NRO_CUENTA||' - '||
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
 ,P_INT_ACUM   IN NUMBER DEFAULT 0 --INTERES ACUMULADO DE PERIODOS CERRADOS
 )
 IS

V_ID AH_DEVENGADOS%ROWTYPE;
V_INT_HOY AH_DEVENGADOS.MTO_INTERES%TYPE;
V_SAL_ACUM  NUMBER(20,2):=0;
/*Recupera registro en AH_DEVENGADOS que corresponda a la cuenta del cursor C_AH_DEVENGADOS */
   CURSOR C_AH_DEVENGADOS IS
   SELECT *
     FROM AH_DEVENGADOS
    WHERE NRO_CUENTA  = paa_dep.g_NRO_CUENTA
      AND FEC_INICIO  = P_FEC_DEV_INICIO;
      --AND VAL_TASA  = P_VAL_TASA;
--
BEGIN
      V_ID := NULL;
      OPEN C_AH_DEVENGADOS;
      FETCH C_AH_DEVENGADOS INTO V_ID;
      CLOSE C_AH_DEVENGADOS;
      --
      V_SAL_ACUM:=ROUND((P_MTO_CAPITAL)+(P_INT_ACUM*P_NRO_DIAS));
      IF V_ID.FEC_INICIO IS NULL THEN
         V_INT_HOY:= NVL(P_MTO_INTERES,0);
         --IF paa_dep.g_COD_MODALIDAD = 31 AND paa_dep.g_SAL_PROMEDIO < paa_dep.g_SAL_MIN_PACTADO THEN
         if p_nro_dias > 0 then
           IF paa_dep.g_COD_MODALIDAD = 31 AND (NVL(P_MTO_CAPITAL,0)/NVL(P_NRO_DIAS,1)) < paa_dep.g_SAL_MIN_PACTADO THEN
              V_INT_HOY := 0;
           END IF;
         else
           v_int_hoy := 0;
         end if;
         paa_dep.g_LUGAR := 'Insertar AH_DEVENGADDOS';
--dbms_output.put_line('Tasa ins '||p_val_tasa);
         IF V_INT_HOY >= 0 THEN
          PR_INS_AH_DEVENGADOS(P_FEC_DEV_INICIO, P_NRO_DIAS, V_INT_HOY, V_SAL_ACUM, P_VAL_TASA, P_FEC_TASA, P_MTO_AJUSTE); --SUMAMOS AL CAPITAL ACUMULADO EL INTERES ACUMULADO DE PERIODOS ANTERIORES
          PR_PRO_AH_DEVENG_HIS(P_FEC_DEV_INICIO, V_INT_HOY);
         END IF;
      ELSE
         V_INT_HOY := NVL(P_MTO_INTERES,0);
         IF paa_dep.g_COD_MODALIDAD = 31 AND paa_dep.g_SAL_PROMEDIO < paa_dep.g_SAL_MIN_PACTADO THEN
            V_INT_HOY:= 0;
         END IF;
         paa_dep.g_LUGAR := 'Acturalizar AH_DEVENGADDOS';
         PR_ACT_AH_DEVENGADOS(V_ID.NRO_CUENTA, P_FEC_DEV_INICIO, P_VAL_TASA,V_SAL_ACUM, --SUMAMOS AL CAPITAL ACUMULADO EL INTERES ACUMULADO DE PERIODOS ANTERIORES
                              V_ID.MTO_INTERES, V_ID.CAN_DIA_INTERES, V_ID.MTO_DEV_ACUMULADO,
                              P_NRO_DIAS, V_INT_HOY,P_MTO_AJUSTE);
      END IF;
   EXCEPTION
       WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(-20000, SQLERRM||' - '||paa_dep.g_LUGAR||' - '||paa_dep.g_NRO_CUENTA);
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
         paa_dep.g_LUGAR := 'Sumariza en AH_DEVENGADOS el MTO_DEV_ACUMULADO Actualizado entre P_FEC_ULT_CAPITALIZACION - P_FEC_ULT_DEVENGAMIENTO';
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
         paa_dep.g_LUGAR := 'Reversar Devengado 1 (Devengado del Dia)';
         UPDATE AH_DEVENGADOS
            SET MTO_INTERES = 0
          WHERE NRO_CUENTA = P_NRO_CUENTA
            AND FECHA = P_FEC_PROCESO
            AND FEC_INICIO BETWEEN P_FEC_ULT_CAPITALIZACION AND P_FEC_ULT_DEVENGAMIENTO;
          --
          paa_dep.g_LUGAR := 'Reversar Devengado 2 (Reversado del Dia)';
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
             paa_dep.g_LUGAR := 'Procesar AH_DEVENGADOS_HIS (Rervesado Devengado)';
             PAA_DEP.PR_PRO_AH_DEVENG_HIS(V_REVERSAR.FEC_INICIO, V_INT_HOY);
             --
             paa_dep.g_LUGAR := 'Actualiza los demas registros a cero diferentes a la fecha de hoy';
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
         RAISE_APPLICATION_ERROR(-20000,SQLERRM||' '||paa_dep.g_LUGAR||' '||'P_NRO_CUENTA '||P_NRO_CUENTA||
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
v_acu_interes number(20,2):=0;
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
  -- V_COD_MON_LOCAL BA_MONEDAS.COD_MONEDA%TYPE;
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

V_COD_TRANSACCION GE_TRANSACCIONES.COD_TRANSACCION%TYPE;
V_TIP_DETALLE GE_TRANSACCIONES.TIPO%TYPE;
V_FEC_VALOR AH_MOVIMIENTOS_HIS.FEC_VALOR%TYPE;
V_MONTO AH_MOVIMIENTOS_HIS.MONTO%TYPE;
-------------------------------------------------------------------
--------- Acumula credito y debito que se encuentra en el  --------
--------- rango de fechas                                  --------
-------------------------------------------------------------------
BEGIN
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
    --End If;  --rbpa--
END;
BEGIN
   v_sal_acumulado     := 0;
   v_mto_int_acumulado := 0;
   v_fec_inicial       := p_fec_inicial;
   v_fec_final         := p_fec_final;
   v_fin_tasa          := 'N';
   ---
   LOOP
      EXIT WHEN v_fin_tasa = 'S';
      v_fin_tasa := 'S';
       v_sig_fec_vigencia := P_FEC_FINAL + 1;
      v_fec_final := v_sig_fec_vigencia-1;
      -- modificacion para Banco Regional
      if to_char(v_fec_final,'yyyymm') <> to_char(v_fec_inicial,'yyyymm') then
         v_fec_final := last_day(v_fec_inicial); -- ultimo dia del mes
         v_sig_fec_vigencia := v_fec_final + 1;
         v_fin_tasa := 'N';
      end if;
      -- calculo el promedio del sub-periodo
       lp_cal_sal_acumulado(3, --modulo
                            paa_dep.g_cod_modalidad,
                            paa_dep.g_cod_oficina,
                            paa_dep.g_nro_cuenta,
                            v_fec_inicial,
                            v_fec_final,
                            paa_dep.g_cod_moneda,
                            --- OUT
                            p_saldo,
                            v_sal_promedio,
                            v_sal_acumulado,
                            v_can_dia_acumulado);
      -- si hay sub periodo que calcular
      if v_can_dia_acumulado > 0 then
         v_val_tasa := paa_dep.g_VAL_TASA;
         v_acu_interes:=PAA_PRO.FU_OBT_DEV_ACU_AH_SAL(paa_dep.g_nro_cuenta, to_number(to_char(v_fec_final, 'YYYYMM')));--OBTENEMOS EL INTERES ACUMULADO DE PERIODOS ANTERIORES
         v_mto_interes :=  pag_gen.fu_cal_int_simple(((v_sal_acumulado/v_can_dia_acumulado)+v_acu_interes), --SUMAMOS EL INTERES AL PROMEDIO DEL CAPITAL
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
      If paa_dep.g_cod_moneda != PAA_DEP.g_MON_LOCAL then
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',3,paa_dep.g_COD_MODALIDAD,paa_dep.g_cod_moneda);
      else
        v_redondeo:=0;
      end if;
      v_mto_interes := round(v_mto_interes,v_redondeo);
      --- Insertar devengado
      paa_dep.g_LUGAR := 'Procesar AH_DEVENGADOS (PR_CAL_AH_DEVENGADOS)';
      PAA_DEP.PR_PRO_AH_DEVENGADOS(v_fec_inicial, v_can_dia_acumulado, V_MTO_INTERES,
                                   v_sal_acumulado, v_val_tasa, v_fec_inicial, 0,v_acu_interes);
      --
      v_mto_int_acumulado := v_mto_int_acumulado + v_mto_interes;
      -----------------------------------------------------------------------
      v_fec_inicial := v_sig_fec_vigencia;
   END LOOP;
exception
   when others then
      raise_application_error(-20020,'Dev. Cta. '||paa_dep.g_nro_cuenta||' '||sqlerrm);
END;
/* Devengar AH_CTA_PLAZOS PROGRAMADO. */
PROCEDURE PR_DEV_AH_CTA_PLA_PROG
 IS
 V_CAN_CUENTAS NUMBER(6) := 0;
 L_CAN_ERROR NUMBER :=0;
-- Selecciona ahorros a la vista para devengar
   CURSOR C_AH_CTA_VISTAS IS
      SELECT COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA, FEC_APERTURA,
        FEC_ULT_PROVISION, 0 SAL_MINIMO, TAS_PERSONALIZADA, SAL_TOTAL, COD_TASA,
       NULL SAL_DISPONIBLE,
        NULL SAL_ULT_CAPITALIZACION, NULL COD_SUB_MODALIDAD, VAL_TASA
      FROM AH_CTA_PLAZOS
     WHERE COD_MODALIDAD = 38 --Ahorro Programado--
       AND ESTADO NOT IN ('V','A','T','P','C','X')
       AND FEC_APERTURA <= paa_dep.g_FEC_HOY;

     TYPE t_list_cta_vistas IS TABLE OF C_AH_CTA_VISTAS%ROWTYPE;
     v_ah_cta_vistas t_list_cta_vistas;
     v_limite CONSTANT PLS_INTEGER := 500000;
BEGIN
 OPEN C_AH_CTA_VISTAS;
      LOOP
        FETCH C_AH_CTA_VISTAS BULK COLLECT INTO V_AH_CTA_VISTAS LIMIT v_limite;
        EXIT WHEN V_AH_CTA_VISTAS.COUNT = 0;
        FOR i in 1..V_AH_CTA_VISTAS.COUNT loop
           V_CAN_CUENTAS := NVL(V_CAN_CUENTAS,0) + 1;
           paa_dep.g_LUGAR             := 'INICIALIZA VARIABLE ';
           paa_dep.g_SECUENCIA         := 0;
           paa_dep.g_COD_MODULO        := V_AH_CTA_VISTAS(i).cod_modulo;
           paa_dep.g_COD_MODALIDAD     := V_AH_CTA_VISTAS(i).COD_MODALIDAD;
           paa_dep.g_COD_SUB_MODALIDAD := V_AH_CTA_VISTAS(i).COD_SUB_MODALIDAD;
           paa_dep.g_COD_OFICINA       := V_AH_CTA_VISTAS(i).COD_OFICINA;
           paa_dep.g_NRO_CUENTA        := V_AH_CTA_VISTAS(i).NRO_CUENTA;
           paa_dep.g_COD_MONEDA        := V_AH_CTA_VISTAS(i).COD_MONEDA;
           paa_dep.g_FEC_ULT_CAPITALIZACION := V_AH_CTA_VISTAS(i).FEC_ULT_PROVISION;
           paa_dep.g_FEC_APERTURA      := V_AH_CTA_VISTAS(i).FEC_APERTURA;
           paa_dep.g_COD_TASA          := V_AH_CTA_VISTAS(i).COD_TASA;
           paa_dep.g_SAL_DISPONIBLE    := V_AH_CTA_VISTAS(i).SAL_DISPONIBLE;
           paa_dep.g_TAS_PERSONALIZADA := V_AH_CTA_VISTAS(i).TAS_PERSONALIZADA;
           paa_dep.g_VAL_TASA := null;
           paa_dep.g_VAL_TASA          := V_AH_CTA_VISTAS(i).VAL_TASA;
           --
           IF paa_dep.g_FEC_HOY = paa_dep.g_ULT_MES_HABIL THEN
              paa_dep.g_FEC_FINAL := paa_dep.g_ULT_DIA_MES;
           ELSIF paa_dep.g_FEC_HOY = paa_dep.g_PRI_MES_HABIL AND paa_dep.g_PRI_MES_HABIL != paa_dep.g_PRI_DIA_MES THEN
              paa_dep.g_FEC_FINAL := paa_dep.g_FEC_PROXIMA - 1;
           ELSE
              paa_dep.g_FEC_FINAL := paa_dep.g_FEC_PROXIMA - 1;
           END IF;
           --
           paa_dep.g_LUGAR := 'Inicializa la fecha inicio del Devengado';
           IF paa_dep.g_FEC_ULT_CAPITALIZACION IS NULL THEN
              paa_dep.g_FEC_INICIO := paa_dep.g_FEC_APERTURA;
           ELSIF paa_dep.g_FEC_ULT_CAPITALIZACION >= paa_dep.g_FEC_APERTURA THEN
              paa_dep.g_FEC_INICIO := paa_dep.g_FEC_ULT_CAPITALIZACION + 1 ;
           ELSE
              raise_application_error(-20021,
              'Fecha de ultima capitalización no puede ser menor a la de apertura');
           END IF;
           --
           paa_dep.g_LUGAR := 'Inicializa Saldo Minimo Pactado';

           IF V_AH_CTA_VISTAS(i).SAL_MINIMO IS NULL THEN
              --
              paa_dep.g_LUGAR := 'Obtener Parametro Saldo Minimo';
              --recuperar el saldo minimo del parametro
              DECLARE
                v_cod_persona varchar2(15) := fug_obt_cli_principal(paa_dep.g_NRO_CUENTA);
              BEGIN
                 paa_dep.g_SAL_MIN_GENERAL := FUG_OBT_SAL_MIN_PACTADO(paa_dep.g_COD_MONEDA, v_cod_persona, paa_dep.g_COD_MODULO,
                                 paa_dep.g_COD_MODALIDAD, paa_dep.g_COD_OFICINA, paa_dep.g_COD_SUB_MODALIDAD);
              END;
              paa_dep.g_SAL_MIN_PACTADO := paa_dep.g_SAL_MIN_GENERAL;
           ELSE
              paa_dep.g_SAL_MIN_PACTADO := V_AH_CTA_VISTAS(i).SAL_MINIMO;
           END IF;
           --
           paa_dep.g_LUGAR := 'Obtener Saldo Promedio AH_CTA_VISTAS';
           PAG_CTA.PR_OBT_SAL_PROMEDIO(paa_dep.g_COD_MODULO, paa_dep.g_COD_MODALIDAD, paa_dep.g_COD_OFICINA,
                                       paa_dep.g_NRO_CUENTA, paa_dep.g_FEC_INICIO, paa_dep.g_FEC_FINAL,
                                       paa_dep.g_SAL_ACUMULADO, paa_dep.g_SAL_PROMEDIO, paa_dep.g_DIA_ACUMULADO);
           paa_dep.g_LUGAR := 'Calcular devengado AH_CTA_VISTAS - '||paa_dep.g_NRO_CUENTA||' - ('||V_CAN_CUENTAS||')';
           --- Esta rutina debe coincidir con la capitalización de ahorro a la vista
           PAA_DEP.PR_CAL_AH_DEVENGADOS(paa_dep.g_FEC_INICIO, paa_dep.g_FEC_FINAL,  V_AH_CTA_VISTAS(i).SAL_ULT_CAPITALIZACION,
                                        paa_dep.g_SAL_PROMEDIO, paa_dep.g_SAL_ACUMULADO, paa_dep.g_DIA_ACUMULADO );
           --
           paa_dep.g_LUGAR := 'Reversion de devengamiento AH_CTA_VISTAS';
           PAA_DEP.PR_REV_AH_DEVENGADOS(paa_dep.g_NRO_CUENTA, paa_dep.g_FEC_INICIO, paa_dep.g_FEC_FINAL,paa_dep.g_FEC_HOY);
           --
        END LOOP;
      END LOOP;
 CLOSE C_AH_CTA_VISTAS;
 BEGIN
  FORALL i IN 1 .. REG_INS_DEVENGADO.COUNT
    INSERT INTO AH_DEVENGADOS
      (NRO_CUENTA,
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
    VALUES
      (reg_ins_devengado(i).nro_cuenta,
       reg_ins_devengado(i).cod_moneda,
       reg_ins_devengado(i).fecha,
       reg_ins_devengado(i).val_tasa,
       reg_ins_devengado(i).fec_tasa,
       reg_ins_devengado(i).can_dia_interes,
       reg_ins_devengado(i).SAL_ACUMULADO,
       reg_ins_devengado(i).MTO_INTERES,
       reg_ins_devengado(i).FEC_INICIO,
       reg_ins_devengado(i).MTO_DEV_ACUMULADO,
       reg_ins_devengado(i).MTO_AJUSTE
       );
 EXCEPTION
  WHEN OTHERS THEN
    l_can_error := SQL%BULK_EXCEPTIONS.count;
    IF l_can_error > 0 then
      FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
        PRG_ACT_LOG_PROCESOS('PAA_DEP.PR_AH_PROGRAMADO',1,trunc(sysdate),to_char(sysdate, 'hh24:mi:ss'),to_char(sysdate, 'hh24:mi:ss'),
                             'Error en insert AH_DEVENGADOS en Cta: ' || REG_INS_DEVENGADO(indx).nro_cuenta || ' ' ||SQLERRM(-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE));
        raise_application_error(-20001, 'Error EN INSERT AH_DEVENGADOS en Cta: ' || REG_INS_DEVENGADO(indx).nro_cuenta || ' ' ||SQLERRM(-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) || ' ');
      END LOOP;
    END IF;
 END;
 BEGIN
  FORALL i IN 1 .. reg_upd_devengado.COUNT
    UPDATE AH_DEVENGADOS
       SET CAN_DIA_INTERES   = reg_upd_devengado(i).CAN_DIA_INTERES, --P_NRO_DIAS,
           MTO_DEV_ANTERIOR  = reg_upd_devengado(i).MTO_DEV_ANTERIOR, --P_INT_ANTERIOR,
           DIA_DEV_ANTERIOR  = reg_upd_devengado(i).DIA_DEV_ANTERIOR, --P_DIA_ANTERIORES,
           MTO_INTERES       = nvl(reg_upd_devengado(i).MTO_INTERES, 0), --V_INT_HOY,
           MTO_DEV_ACUMULADO = NVL(MTO_DEV_ACUMULADO, 0) +
                               nvl(reg_upd_devengado(i).MTO_DEV_ACUMULADO, 0), --NVL(MTO_DEV_ACUMULADO,0) + NVL(V_INT_HOY,0),
           FECHA             = reg_upd_devengado(i).fecha,
           SAL_ACUMULADO     = reg_upd_devengado(i).SAL_ACUMULADO, --P_MTO_CAPITAL,
           VAL_TASA          = reg_upd_devengado(i).VAL_TASA, --P_VAL_TASA,
           MTO_AJUSTE        = reg_upd_devengado(i).MTO_AJUSTE --P_MTO_AJUSTE
     WHERE NRO_CUENTA = reg_upd_devengado(i).NRO_CUENTA --P_NRO_CUENTA
       AND FEC_INICIO = reg_upd_devengado(i).FEC_INICIO; --P_FEC_INICIO;

 EXCEPTION
  WHEN OTHERS THEN
    l_can_error := SQL%BULK_EXCEPTIONS.count;
    IF l_can_error > 0 then
      FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
        PRG_ACT_LOG_PROCESOS('PAA_DEP.PR_AH_PROGRAMADO',1,trunc(sysdate),to_char(sysdate, 'hh24:mi:ss'),to_char(sysdate, 'hh24:mi:ss'),
                             'Error en UPDATE AH_DEVENGADOS en Cta: ' || reg_upd_devengado(indx).nro_cuenta || ' ' ||
                             SQLERRM(-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE));
        raise_application_error(-20002, 'Error EN UPDATE AH_DEVENGADOS en Cta: ' || reg_upd_devengado(indx).nro_cuenta || ' ' ||
                                SQLERRM(-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) || ' ');
      END LOOP;
    END IF;
 END;
 BEGIN
   FORALL i IN 1 .. reg_upd_his_devengado.COUNT
     UPDATE AH_DEVENGADOS_HIS
        SET MTO_INTERES = nvl(MTO_INTERES, 0) +nvl(reg_upd_his_devengado(i).mto_interes, 0)
      WHERE NRO_CUENTA = reg_upd_his_devengado(i).nro_cuenta
        AND ANO = reg_upd_his_devengado(i).ano
        AND MES = reg_upd_his_devengado(i).mes;
 EXCEPTION
   WHEN OTHERS THEN
     l_can_error := SQL%BULK_EXCEPTIONS.count;
     IF l_can_error > 0 then
       FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
         PRG_ACT_LOG_PROCESOS('PAA_DEP.PR_AH_PROGRAMADO', 1, trunc(sysdate), to_char(sysdate, 'hh24:mi:ss'), to_char(sysdate, 'hh24:mi:ss'),
                              'Error en UPDATE AH_DEVENGADOS_HIS en Cta: ' || reg_upd_his_devengado(indx).nro_cuenta || ' ' ||
                              SQLERRM(-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE));
         raise_application_error(-20003,'Error EN UPDATE AH_DEVENGADOS_HIS en Cta: ' || reg_upd_his_devengado(indx).nro_cuenta || ' ' ||
                                 SQLERRM(-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) || ' ');
       END LOOP;
     END IF;
 END;

 BEGIN
   FORALL i IN 1 .. reg_ins_his_devengado.COUNT
     INSERT INTO AH_DEVENGADOS_HIS
       (COD_MODULO,
        COD_MODALIDAD,
        COD_OFICINA,
        NRO_CUENTA,
        ANO,
        MES,
        MTO_INTERES)
     VALUES
       (reg_ins_his_devengado(i).cod_modulo,
        reg_ins_his_devengado(i).cod_modalidad,
        reg_ins_his_devengado(i).cod_oficina,
        reg_ins_his_devengado(i).nro_cuenta,
        reg_ins_his_devengado(i).ano,
        reg_ins_his_devengado(i).mes,
        reg_ins_his_devengado(i).MTO_INTERES
        );

 EXCEPTION
   WHEN OTHERS THEN
     l_can_error := SQL%BULK_EXCEPTIONS.count;
     IF l_can_error > 0 then
       FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
         PRG_ACT_LOG_PROCESOS('PAA_DEP.PR_AH_PROGRAMADO',1,trunc(sysdate),to_char(sysdate, 'hh24:mi:ss'),to_char(sysdate, 'hh24:mi:ss'),
                              'Error en INSERT AH_DEVENGADOS_HIS en Cta: ' || reg_ins_his_devengado(indx).nro_cuenta || ' ' ||
                              SQLERRM(-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE));
         raise_application_error(-20004,'Error EN INSERT AH_DEVENGADOS_HIS en Cta: ' || reg_ins_his_devengado(indx).nro_cuenta || ' ' ||
                                 SQLERRM(-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) || ' ');
       END LOOP;
     END IF;
 END;

 END;
/* Devengar Ahorro Programado */
PROCEDURE PR_AH_PROGRAMADO
 IS
BEGIN
      reg_ins_devengado := typ_devengado();
      reg_upd_devengado := typ_devengado();
      reg_ins_his_devengado := typ_devengado_his();
      reg_upd_his_devengado := typ_devengado_his();
      paa_dep.g_LUGAR     := 'Obtener Moneda Local';
      paa_dep.g_MON_LOCAL := PAG_GEN.FU_OBT_MON_LOCAL;
   --
      paa_dep.g_LUGAR := 'Obtiene cambio de GE_CALENDRIOS';
      PAG_CAL.PR_OBT_DAT_CALENDAR(paa_dep.g_COD_MODULO);
   --
   --
      paa_dep.g_FEC_HOY       := PAG_CAL.G_FEC_ACTUAL;
      paa_dep.g_ULT_MES_HABIL := PAG_CAL.G_ULT_DIA_MES_HABIL;
      paa_dep.g_ULT_DIA_MES   := PAG_CAL.G_ULT_DIA_MES;
      paa_dep.g_FEC_PROXIMA   := PAG_CAL.G_FEC_PROXIMA;
      paa_dep.g_PRI_DIA_MES   := PAG_CAL.G_PRI_DIA_MES;
      paa_dep.g_PRI_MES_HABIL := PAG_CAL.G_PRI_DIA_MES_HABIL;
   --
      paa_dep.g_LUGAR := 'Devengamiento Ahorro a la vista';
      PR_DEV_AH_CTA_PLA_PROG;
   --
   EXCEPTION
      WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20001,SQLERRM||' '||paa_dep.g_LUGAR);
   END;

END PAA_DEP;
/
