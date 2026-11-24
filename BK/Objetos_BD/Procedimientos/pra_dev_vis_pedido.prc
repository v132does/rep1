CREATE OR REPLACE PROCEDURE IT.PRA_DEV_VIS_PEDIDO(P_NRO_CUENTA IN VARCHAR2) IS

VG_COD_MODULO AH_CTA_VISTAS.COD_MODULO%TYPE := 3;
VG_NRO_CUENTA VARCHAR2(15);
VG_LUGAR VARCHAR2(250);
VG_COD_TASA GE_TASAS.COD_TASA%TYPE;
VG_COD_MODALIDAD AH_CTA_VISTAS.COD_MODALIDAD%TYPE;
VG_COD_OFICINA AH_CTA_VISTAS.COD_OFICINA%TYPE;
VG_SAL_MIN_PACTADO AH_CTA_VISTAS.SAL_MINIMO%TYPE;
VG_COD_MONEDA BA_MONEDAS.COD_MONEDA%TYPE;
VG_MON_LOCAL BA_MONEDAS.COD_MONEDA%TYPE := PAG_GEN.FU_OBT_MON_LOCAL;
VG_SAL_PROMEDIO AH_CTA_VISTAS.SAL_TOTAL%TYPE;
VG_SAL_ULT_CAPITALIZACION AH_CTA_VISTAS.SAL_ULT_CAPITALIZACION%TYPE;
VG_FEC_FINAL DATE;
VG_FEC_ACTUAL DATE;
VG_ULT_MES_HABIL AH_DEVENGADOS.FECHA%TYPE;
VG_IND_ERROR VARCHAR2(1);
-----
VG_SAL_ACUMULADO AH_CTA_VISTAS.SAL_TOTAL%TYPE;
VG_DIA_ACUMULADO AH_DEVENGADOS.CAN_DIA_INTERES%TYPE;
VG_SECUENCIA NUMBER(3);
VG_TAS_PERSONALIZADA AH_CTA_VISTAS.TAS_PERSONALIZADA%TYPE;
VG_SAL_DISPONIBLE AH_DEVENGADOS.SAL_ACUMULADO%TYPE;
VG_FEC_APERTURA AH_CTA_PLAZOS.FEC_APERTURA%TYPE;
VG_FEC_ULT_CAPITALIZACION AH_CTA_PLAZOS.FEC_ULT_CAPITALIZACION%TYPE;
VG_FEC_INICIO AH_DEVENGADOS.FEC_INICIO%TYPE;
VG_COD_PROGRAMA     GE_LOG_PROCESOS.COD_PROGRAMA%TYPE;
------
VG_LUG_PROCESO VARCHAR2(250);
VG_FEC_ANTERIOR DATE;
VG_CAN_DEV_PARALELO   NUMBER(4);
VG_HOR_INICIO       VARCHAR2(8);
VG_HOR_FIN          VARCHAR2(8);
VG_NRO_ORDEN        GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
VG_TIP_CONTROL VARCHAR2(1);
------
VG_COD_PARALELO VARCHAR2(20);
VG_ORDEN NUMBER(6);

PROCEDURE LP_TRA_ENV_EMAIL(P_ERROR VARCHAR2) IS
  --Variables para mail--
  v_para       VARCHAR2(4000);
  v_asunto     VARCHAR2(2000);
  v_texto      VARCHAR2(8000) := p_error;
  v_hin_mail ge_ra_log_mail.hor_inicio%type;
  v_hfi_mail ge_ra_log_mail.hor_fin%type;
  v_det_error ge_ra_log_mail.det_error%type;
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   v_asunto   := 'Error en Proceso Deveng. Diario Vista '||VG_COD_PROGRAMA||' - '||to_char(VG_FEC_ACTUAL, 'DD/MM/YYYY');
   BEGIN
     v_hin_mail := to_char(sysdate, 'hh24:mi:ss');
     v_para := fug_obt_pardinamico('ENV_EMA_GUA_CIERRE');
     it_mail.mail(fug_obt_dir_correo, v_para, v_asunto, substr(v_texto,1,4000));
     v_hfi_mail := to_char(sysdate, 'hh24:mi:ss');
   EXCEPTION
     when others then
       v_det_error := substr(sqlerrm, 1, 4000);
       INSERT INTO ge_ra_log_mail
       (fec_envio, nom_archivo, dir_correo,
        mensaje, det_error, hor_inicio, hor_fin)
       VALUES
       (SYSDATE, null, v_para,
        substr(v_asunto||'-'||v_texto,1,2000), v_det_error, v_hin_mail, v_hfi_mail);
     commit;
   END;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, 'Error en LP_TRA_ENV_EMAIL - '||sqlerrm);
END LP_TRA_ENV_EMAIL;

/* Obtiene el Saldo Promedio de una Cuenta */
FUNCTION LF_OBT_SAL_PROMEDIO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FEC_INI IN DATE
 ,P_FEC_FIN IN DATE
 ,P_TIPO IN VARCHAR2
 ,P_SAL_ACUMULADO IN OUT NUMBER
 ,P_SAL_PROMEDIO IN OUT NUMBER
 ,P_CAN_DIA_ACUMULADO IN OUT AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 ) RETURN NUMBER IS
V_FEC_ACTUAL DATE;
V_ANIO_ACTUAL AH_SAL_MENSUALES.ANO%TYPE;
V_MES_ACTUAL AH_SAL_MENSUALES.MES%TYPE;
V_SAL_ACU_DIARIO AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE;
V_CAN_DIA_ACUMULADO AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
g_lugar varchar2(250);
V_SALDO AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE;
---Optimizar el codigo para que obtenga el saldo promedio
---de todas las cuentas cc, ah, pr, ta
---Pedido por Agustin, 16-04-2004
---Ver si se puede utilizar Parametros Diferenciados
CURSOR saldo_promedio IS
   SELECT nvl(sal_acu_diario,0), nvl(can_dia_acumulado,0)
   FROM AH_SAL_MENSUALES
   WHERE nro_cuenta = p_nro_cuenta AND
         ano = v_anio_actual AND
         mes = v_mes_actual;
BEGIN
   g_lugar := 'Calcula_saldo_promedio_av';
   p_can_dia_acumulado:= 0;
   p_sal_acumulado := 0;
   p_sal_promedio := 0;
   v_fec_actual  := p_fec_ini;
   v_anio_actual := TO_NUMBER(TO_CHAR(p_fec_ini,'YYYY'));
   v_mes_actual := TO_NUMBER(TO_CHAR(p_fec_ini,'MM'));
   /* La fecha  actual se va incrementando en 1 mes. Mientras que sea menor que la fecha final
      recibida como parametros. Calcula el acumulado de saldo y el saldo promedio */
   WHILE TO_NUMBER(TO_CHAR(v_fec_actual,'YYYYMM')) <= TO_NUMBER(TO_CHAR(p_fec_fin,'YYYYMM')) LOOP
      IF saldo_promedio%ISOPEN THEN
         CLOSE saldo_promedio;
      END IF;
      OPEN saldo_promedio;
         FETCH saldo_promedio
         INTO v_sal_acu_diario, v_can_dia_acumulado;

         g_lugar := 'acumula saldo acumulado y cantidad de dias';
         p_sal_acumulado:= p_sal_acumulado + NVL(v_sal_acu_diario,0);
         p_can_dia_acumulado:= p_can_dia_acumulado + NVL(v_can_dia_acumulado,0);
         v_fec_actual:= ADD_MONTHS(v_fec_actual, 1);
         v_anio_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'YYYY'));
         v_mes_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'MM'));
   END LOOP;
   IF saldo_promedio%ISOPEN THEN
      CLOSE saldo_promedio;
   END IF;
   g_lugar := 'calcula saldo promedio';
   IF NVL(p_can_dia_acumulado,0) > 0 THEN
     p_sal_promedio := p_sal_acumulado / p_can_dia_acumulado;
   END IF;
   IF P_TIPO = 'A' then
      v_saldo := P_SAL_ACUMULADO;
   elsif P_TIPO = 'P' then
      v_saldo := P_SAL_PROMEDIO;
   else
      v_saldo :=  P_CAN_DIA_ACUMULADO;
   end if;
   return v_saldo;
EXCEPTION
  WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20022,SQLERRM||' -  '||g_lugar);
END;

/*Cargar Tabla Auxiliar*/
PROCEDURE LP_INS_TMP_DEVENGADOS IS
  --Procedimiento autonomo--
  PRAGMA AUTONOMOUS_TRANSACTION;
  --Variables--
  V_COD_SEG_FUNCIONARIO GE_SEG_CLIENTES.COD_SEG_CLIENTE%TYPE;

BEGIN
  VG_LUG_PROCESO := 'LP_INS_TMP_DEVENGADOS';
  VG_HOR_INICIO := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_NRO_ORDEN, VG_FEC_ACTUAL,VG_TIP_CONTROL, VG_HOR_INICIO);
  --Carga de Variables--
  VG_LUGAR := 'Tmp-Variables';
  --v_fec_actual := VG_FEC_ACTUAL;
  v_cod_seg_funcionario := fug_obt_pardinamico('SEG_FUNCIONARIOS');

  VG_LUGAR := 'Tmp-dev_diario';
  --Insertar Tabla Temporal de datos para Devengado diario--
  INSERT /*+APPEND*/ INTO AH_DEV_GRU_PEDIDOS_TMP
  (COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA, FEC_APERTURA, FEC_ULT_CAPITALIZACION,
   SAL_MINIMO, TAS_PERSONALIZADA, SAL_TOTAL, COD_TASA, SAL_DISPONIBLE, SAL_ULT_CAPITALIZACION,
   COD_PERSONA, FUNCIONARIO, COD_SUB_MODALIDAD, FEC_INICIO, FEC_FINAL, COD_PARALELO, REFERENCIA) --nomar--

  SELECT A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA, A.NRO_CUENTA, COD_MONEDA, FEC_APERTURA,
        FEC_ULT_CAPITALIZACION, SAL_MINIMO, TAS_PERSONALIZADA, SAL_TOTAL, COD_TASA,
       (SAL_TOTAL + MTO_CRE_A_CONFIRMAR) - (SAL_BLOQUEADO + SAL_RETENIDO + MTO_CRE_PENDIENTES + MTO_DEB_PENDIENTES) SAL_DISPONIBLE,
        SAL_ULT_CAPITALIZACION, B.COD_PERSONA,
        CASE WHEN NVL(U.CAN_USUARIO,0) > 0 THEN 'S'
             WHEN NVL(U.CAN_USUARIO,0) <= 0 AND C.COD_SEG_CLIENTE = V_COD_SEG_FUNCIONARIO THEN 'S'
             ELSE 'N'
        END FUNCIONARIO, A.COD_SUB_MODALIDAD,
        --Fecha de Inicio--
        CASE WHEN A.FEC_ULT_CAPITALIZACION IS NULL THEN A.FEC_APERTURA
             WHEN A.FEC_ULT_CAPITALIZACION >= A.FEC_APERTURA THEN A.FEC_ULT_CAPITALIZACION + 1
             ELSE TO_DATE(NULL)
        END FEC_INICIO,
        --Fecha Final--
        CASE
          WHEN D.FEC_ACTUAL = D.ULT_DIA_MES_HABIL THEN D.ULT_DIA_MES
          WHEN D.FEC_ACTUAL = D.PRI_DIA_MES_HABIL AND D.PRI_DIA_MES_HABIL != D.PRI_DIA_MES THEN D.FEC_PROXIMA - 1
         ELSE
            D.FEC_PROXIMA - 1
         END FEC_FINAL,
         'DEV'||TRIM(TO_CHAR((ROWNUM - (TRUNC(rownum / VG_CAN_DEV_PARALELO)*VG_CAN_DEV_PARALELO))+1)) COD_PARALELO,
         'AH_CTA_VIS_PEDIDOS'  --nomar--
      FROM AH_CTA_VISTAS A, GE_CTA_CLIENTES B, GE_CLIENTES C, GE_CALENDARIOS D,
     (SELECT T.COD_PERSONA, NVL(COUNT(*),0) CAN_USUARIO
        FROM BA_USUARIOS T
       WHERE T.ESTADO = 'A'
         AND T.COD_PERSONA IS NOT NULL
       GROUP BY T.COD_PERSONA) U
     WHERE ESTADO NOT IN ('C','A','P','X')
       AND FEC_APERTURA <= VG_FEC_ACTUAL
       AND B.NRO_CUENTA = A.NRO_CUENTA
       AND B.RELACION = 'P'
       AND U.COD_PERSONA(+) = B.COD_PERSONA
       AND C.COD_PERSONA = B.COD_PERSONA
       AND D.COD_MODULO = 3
       AND A.NRO_CUENTA = P_NRO_CUENTA;

  --Confirmar ya que es independiente--
  COMMIT;
  VG_HOR_FIN := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_NRO_ORDEN, VG_FEC_ACTUAL,'F', VG_HOR_FIN);
  PRG_ACT_LOG_PROCESOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_FEC_ACTUAL, VG_HOR_INICIO, VG_HOR_FIN);
  EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, 'Error en PRA_GEN_DAT_DEV_VISTA - '||sqlerrm);
END;

PROCEDURE LP_TRU_TMP_DEVENGADOS IS
  v_msj VARCHAR2(2000);
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  --Truncar tabla Temporal de Cuentas--
  VG_LUG_PROCESO := 'LP_TRU_TMP_DEVENGADOS';
  VG_HOR_INICIO := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_NRO_ORDEN, VG_FEC_ACTUAL,VG_TIP_CONTROL, VG_HOR_INICIO);
  VG_LUGAR := 'Tmp-truncar';
  v_msj := null;
  sql_util.ejecute_dml('TRUNCATE TABLE AH_DEV_GRU_PEDIDOS_TMP', v_msj);
  if v_msj is not null then
     RAISE_APPLICATION_ERROR(-20001, v_msj);
  end if;
  /*--Truncar Tabla Temporal de Devengados--
  V_MSJ := NULL;
  SQL_UTIL.EJECUTE_DML('TRUNCATE TABLE AH_DEV_PEDIDOS', V_MSJ); --rbpa--
  IF V_MSJ IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20001, V_MSJ);
  END IF;*/
    --Inserta Datos necesarios para calculo en Temporal--
    INSERT INTO /*AH_DEV_PEDIDOS*/ AH_DEV_GRU_PEDIDOS_TMP  --rbpa--
    (nro_cuenta, fecha, cod_moneda, val_tasa, fec_tasa, can_dia_interes,
     sal_acumulado, mto_interes, dia_dev_anterior, mto_dev_anterior, fec_inicio, mto_dev_acumulado,
     usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, mto_ajuste, referencia

    )
    SELECT x.*, 'AH_DEV_PEDIDOS' --rbpa--
      FROM AH_DEVENGADOS X
     WHERE X.FECHA = VG_FEC_ANTERIOR
       AND X.NRO_CUENTA = P_NRO_CUENTA;
  COMMIT;
  VG_HOR_FIN := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_NRO_ORDEN, VG_FEC_ACTUAL,'F', VG_HOR_FIN);
  PRG_ACT_LOG_PROCESOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_FEC_ACTUAL, VG_HOR_INICIO, VG_HOR_FIN);
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, 'Error en PL_TRU_TAB_DEVENGADOS - '||sqlerrm);
END;

/* Obtiene el Saldo Promedio de una Cuenta */
PROCEDURE PR_OBT_SAL_PROMEDIO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FEC_INI IN DATE
 ,P_FEC_FIN IN DATE
 ,P_SAL_ACUMULADO IN OUT NUMBER
 ,P_SAL_PROMEDIO IN OUT NUMBER
 ,P_CAN_DIA_ACUMULADO IN OUT AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 )
 IS
V_FEC_ACTUAL DATE;
V_ANIO_ACTUAL AH_SAL_MENSUALES.ANO%TYPE;
V_MES_ACTUAL AH_SAL_MENSUALES.MES%TYPE;
V_SAL_ACU_DIARIO AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE;
V_CAN_DIA_ACUMULADO AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
g_lugar varchar2(250);
---Optimizar el codigo para que obtenga el saldo promedio
---de todas las cuentas cc, ah, pr, ta
---Pedido por Agustin, 16-04-2004
---Ver si se puede utilizar Parametros Diferenciados
CURSOR saldo_promedio IS
   SELECT nvl(sal_acu_diario,0), nvl(can_dia_acumulado,0)
   FROM AH_SAL_MENSUALES
   WHERE nro_cuenta = p_nro_cuenta AND
         ano = v_anio_actual AND
         mes = v_mes_actual;
BEGIN
   g_lugar := 'Calcula_saldo_promedio_av';
   p_can_dia_acumulado:= 0;
   p_sal_acumulado := 0;
   p_sal_promedio := 0;
   v_fec_actual  := p_fec_ini;
   v_anio_actual := TO_NUMBER(TO_CHAR(p_fec_ini,'YYYY'));
   v_mes_actual := TO_NUMBER(TO_CHAR(p_fec_ini,'MM'));
   /* La fecha  actual se va incrementando en 1 mes. Mientras que sea menor que la fecha final
      recibida como parametros. Calcula el acumulado de saldo y el saldo promedio */
   WHILE TO_NUMBER(TO_CHAR(v_fec_actual,'YYYYMM')) <= TO_NUMBER(TO_CHAR(p_fec_fin,'YYYYMM')) LOOP
      IF saldo_promedio%ISOPEN THEN
         CLOSE saldo_promedio;
      END IF;
      OPEN saldo_promedio;
         FETCH saldo_promedio
         INTO v_sal_acu_diario, v_can_dia_acumulado;

         g_lugar := 'acumula saldo acumulado y cantidad de dias';
         p_sal_acumulado:= p_sal_acumulado + NVL(v_sal_acu_diario,0);
         p_can_dia_acumulado:= p_can_dia_acumulado + NVL(v_can_dia_acumulado,0);
         v_fec_actual:= ADD_MONTHS(v_fec_actual, 1);
         v_anio_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'YYYY'));
         v_mes_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'MM'));
   END LOOP;
   IF saldo_promedio%ISOPEN THEN
      CLOSE saldo_promedio;
   END IF;
   g_lugar := 'calcula saldo promedio';
   IF NVL(p_can_dia_acumulado,0) > 0 THEN
     p_sal_promedio := p_sal_acumulado / p_can_dia_acumulado;
   END IF;
EXCEPTION
  WHEN OTHERS THEN
     VG_IND_ERROR := 'S';
     PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_COD_PARALELO, VG_ORDEN, VG_FEC_ACTUAL,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||G_LUGAR);
     RAISE_APPLICATION_ERROR(-20022,SQLERRM||' -  '||g_lugar);
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
      VG_LUGAR := 'INSERTAR AH_DEVENGADOS';
         --INSERT INTO AH_DEV_PEDIDOS(NRO_CUENTA, --rbpa--
         INSERT INTO AH_DEV_GRU_PEDIDOS_TMP(NRO_CUENTA,
                                COD_MONEDA,
                                FECHA,
                                VAL_TASA,
                                FEC_TASA,
                                CAN_DIA_INTERES,
                                SAL_ACUMULADO,
                                MTO_INTERES,
                                FEC_INICIO,
                                MTO_DEV_ACUMULADO,
                                MTO_AJUSTE,
                                REFERENCIA)
                         VALUES(VG_NRO_CUENTA,
                                VG_COD_MONEDA,
                                VG_FEC_ACTUAL,
                                p_VAL_TASA,
                                P_FEC_TASA,
                                P_NRO_DIAS,
                                P_MTO_CAPITAL,
                                P_MTO_INTERES,
                                P_FEC_INICIO,
                                P_MTO_INTERES,
                                P_MTO_AJUSTE,
                                'AH_DEV_PEDIDOS');  --rbpa--
      --END IF;
   EXCEPTION
      WHEN OTHERS THEN
         VG_IND_ERROR := 'S';
         PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_COD_PARALELO, VG_ORDEN, VG_FEC_ACTUAL,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||' / '||VG_LUGAR||' / '||VG_NRO_CUENTA, VG_NRO_CUENTA);
         RAISE_APPLICATION_ERROR(-20000, SQLERRM||' / '||VG_LUGAR||' / '||VG_NRO_CUENTA);
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
      VG_LUGAR := 'ACTUALIZA AH_DEVENGADOS';
      V_INT_HOY := NVL(P_MTO_INTERES,0) - NVL(P_DEV_ACUMULADO,0);
          --UPDATE AH_DEV_PEDIDOS  --rbpa--
          UPDATE AH_DEV_GRU_PEDIDOS_TMP
             SET CAN_DIA_INTERES = P_NRO_DIAS,
                 MTO_DEV_ANTERIOR = P_INT_ANTERIOR,
                 DIA_DEV_ANTERIOR = P_DIA_ANTERIORES,
                 MTO_INTERES = V_INT_HOY,
                 MTO_DEV_ACUMULADO = NVL(MTO_DEV_ACUMULADO,0) + NVL(V_INT_HOY,0),
                 FECHA = VG_FEC_ACTUAL,
                 SAL_ACUMULADO = P_MTO_CAPITAL,
                 VAL_TASA = P_VAL_TASA,
                 MTO_AJUSTE = P_MTO_AJUSTE
           WHERE NRO_CUENTA = P_NRO_CUENTA
             AND FEC_INICIO = P_FEC_INICIO
             AND REFERENCIA = 'AH_DEV_PEDIDOS';  --rbpa--
   --
   VG_LUGAR := 'PR_PRO_AH_DEVENGADOS_HIS(update_AH_DEVENGADOS)';

EXCEPTION
  WHEN OTHERS THEN
     VG_IND_ERROR := 'S';
     PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_COD_PARALELO, VG_ORDEN, VG_FEC_ACTUAL,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||' - '||VG_LUGAR||' - '||P_NRO_CUENTA||' - '||
                            'Interes '||TO_CHAR(V_INT_HOY)||' - '||'P_MTO_CAPITAL '||TO_CHAR(P_MTO_CAPITAL),P_NRO_CUENTA);
     RAISE_APPLICATION_ERROR(-20000, SQLERRM||' - '||VG_LUGAR||' - '||P_NRO_CUENTA||' - '||
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
    WHERE NRO_CUENTA  = VG_NRO_CUENTA
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
         --IF VG_COD_MODALIDAD = 31 AND VG_SAL_PROMEDIO < VG_SAL_MIN_PACTADO THEN
         if p_nro_dias > 0 then
           IF VG_COD_MODALIDAD = 31 AND (NVL(P_MTO_CAPITAL,0)/NVL(P_NRO_DIAS,1)) < VG_SAL_MIN_PACTADO THEN
              V_INT_HOY := 0;
           END IF;
         else
           v_int_hoy := 0;
         end if;
         VG_LUGAR := 'Insertar AH_DEVENGADDOS';
--dbms_output.put_line('Tasa ins '||p_val_tasa);
         IF V_INT_HOY >= 0 THEN
            PR_INS_AH_DEVENGADOS(P_FEC_DEV_INICIO, P_NRO_DIAS, V_INT_HOY, P_MTO_CAPITAL, P_VAL_TASA, P_FEC_TASA, P_MTO_AJUSTE);
         END IF;
      ELSE
         V_INT_HOY := NVL(P_MTO_INTERES,0);
         IF VG_COD_MODALIDAD = 31 AND VG_SAL_PROMEDIO < VG_SAL_MIN_PACTADO THEN
            V_INT_HOY:= 0;
         END IF;
         VG_LUGAR := 'Acturalizar AH_DEVENGADDOS';
         PR_ACT_AH_DEVENGADOS(V_ID.NRO_CUENTA, P_FEC_DEV_INICIO, P_VAL_TASA, P_MTO_CAPITAL,
                              V_ID.MTO_INTERES, V_ID.CAN_DIA_INTERES, V_ID.MTO_DEV_ACUMULADO,
                              P_NRO_DIAS, V_INT_HOY,P_MTO_AJUSTE);
      END IF;
   EXCEPTION
       WHEN OTHERS THEN
          VG_IND_ERROR := 'S';
          PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_COD_PARALELO, VG_ORDEN, VG_FEC_ACTUAL,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||' - '||VG_LUGAR||' - '||VG_NRO_CUENTA, VG_NRO_CUENTA);
          RAISE_APPLICATION_ERROR(-20000, SQLERRM||' - '||VG_LUGAR||' - '||VG_NRO_CUENTA);
   END;

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
         VG_LUGAR := 'Sumariza en AH_DEVENGADOS el MTO_DEV_ACUMULADO Actualizado entre P_FEC_ULT_CAPITALIZACION - P_FEC_ULT_DEVENGAMIENTO';
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
         VG_LUGAR := 'Reversar Devengado 1 (Devengado del Dia)';
              --UPDATE AH_DEV_PEDIDOS  --rbpa--
              UPDATE AH_DEV_GRU_PEDIDOS_TMP
                SET MTO_INTERES = 0
              WHERE NRO_CUENTA = P_NRO_CUENTA
                AND FECHA = P_FEC_PROCESO
                AND FEC_INICIO BETWEEN P_FEC_ULT_CAPITALIZACION AND P_FEC_ULT_DEVENGAMIENTO
                AND REFERENCIA = 'AH_DEV_PEDIDOS';  --rbpa--
              --
              VG_LUGAR := 'Reversar Devengado 2 (Reversado del Dia)';
              --UPDATE AH_DEV_PEDIDOS  --rbpa--
              UPDATE AH_DEV_GRU_PEDIDOS_TMP
                 SET MTO_INTERES = V_INT_HOY,
                     FECHA = P_FEC_PROCESO,
                     MTO_DEV_ANTERIOR = V_DEV_ACU_REVERSADO,
                     MTO_DEV_ACUMULADO = 0
               WHERE NRO_CUENTA = P_NRO_CUENTA
                 AND FEC_INICIO = V_REVERSAR.FEC_INICIO
                 AND VAL_TASA = V_REVERSAR.VAL_TASA
                 AND CAN_DIA_INTERES = V_REVERSAR.CAN_DIA_INTERES
                 AND REFERENCIA = 'AH_DEV_PEDIDOS';  --rbpa--
                IF SQL%FOUND THEN
                 VG_LUGAR := 'Procesar AH_DEVENGADOS_HIS (Rervesado Devengado)';
                 --
                 VG_LUGAR := 'Actualiza los demas registros a cero diferentes a la fecha de hoy';
                 --UPDATE AH_DEV_PEDIDOS  --rbpa--
                 UPDATE AH_DEV_GRU_PEDIDOS_TMP
                    SET MTO_INTERES = 0,
                        FECHA = P_FEC_PROCESO,
                        MTO_DEV_ACUMULADO = 0
                  WHERE NRO_CUENTA = P_NRO_CUENTA
                    AND FECHA = P_FEC_PROCESO
                    AND FEC_INICIO BETWEEN P_FEC_ULT_CAPITALIZACION AND P_FEC_ULT_DEVENGAMIENTO
                    AND REFERENCIA = 'AH_DEV_PEDIDOS';  --rbpa--
                END IF;
         --
         END IF;
      --
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         VG_IND_ERROR := 'S';
         PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_COD_PARALELO, VG_ORDEN, VG_FEC_ACTUAL,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||' '||VG_LUGAR||' '||'NRO_CUENTA: '||P_NRO_CUENTA||
                                 'Fecha '||TO_CHAR(V_REVERSAR.FEC_INICIO + V_REVERSAR.CAN_DIA_INTERES,'DD/MM/YYYY'),P_NRO_CUENTA);
         RAISE_APPLICATION_ERROR(-20000,SQLERRM||' '||VG_LUGAR||' '||'NRO_CUENTA: '||P_NRO_CUENTA||
                                 'Fecha '||TO_CHAR(V_REVERSAR.FEC_INICIO + V_REVERSAR.CAN_DIA_INTERES,'DD/MM/YYYY'));
   END;
   --;
/* Calcular AH_DEVENGADOS. */
PROCEDURE PR_CAL_AH_DEV_GRUPAL
 (P_FEC_INICIAL IN OUT AH_DEVENGADOS.FEC_INICIO%TYPE
 ,P_FEC_FINAL IN OUT AH_DEVENGADOS.FECHA%TYPE
 ,P_SALDO IN OUT AH_DEVENGADOS.SAL_ACUMULADO%TYPE
 ,P_SAL_PROMEDIO IN AH_DEVENGADOS.SAL_ACUMULADO%TYPE
 ,P_CAN_DIA_ACUMULADO IN OUT AH_DEVENGADOS.CAN_DIA_INTERES%TYPE
 )
 IS
-- Variables del procedimiento principal
v_redondeo number(5);

/* Calcula el Saldo Acumulado */
PROCEDURE LP_CAL_SAL_ACU_GRUPAL
 (P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FINAL IN DATE
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
PROCEDURE LP_CAL_SAL_ACU_GRUPAL
 (P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_FEC_INICIAL IN DATE
 ,P_FEC_FINAL IN DATE
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
V_FECHA DATE;
V_HORA  VARCHAR2(8);
V_COD_USUARIO BA_USUARIOS.COD_USUARIO%TYPE;
V_NRO_SECUENCIA GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE;
-------------------------------------------------------------------
--------- Acumula credito y debito que se encuentra en el  --------
--------- rango de fechas                                  --------
-------------------------------------------------------------------
CURSOR c_mov_historicos IS
   SELECT FEC_VALOR,
          ----------
          fub_con_mon_a_moneda(d.cod_moneda,pp.cod_moneda,m.MONTO) monto,
          ----------
          T.COD_TRANSACCION, DECODE(T.COD_TRANSACCION,515,'C',560,'C',565,'C',T.TIPO) TIPO,
          M.FECHA, M.HORA, M.COD_USUARIO, M.NRO_SECUENCIA
     FROM GE_TRANSACCIONES T, AH_MOVIMIENTOS_HIS M, AH_DEV_GRU_CUENTAS B, AH_CTA_VISTAS D,
          ---oilisab--
          (select distinct m.cod_persona, m.cod_grupo, m.nro_cuenta, l.cod_moneda
            from ah_dev_gru_cuentas m, ah_cta_vistas l
           where m.nro_cuenta = P_NRO_CUENTA
             and m.tipo = 'P' --Principal--
             and l.nro_cuenta = m.nro_cuenta) pp
          ---
    WHERE T.COD_MODULO = d.cod_modulo
      AND T.COD_MODALIDAD = d.cod_modalidad
      AND M.NRO_CUENTA = d.nro_cuenta
      AND T.COD_TRANSACCION = M.COD_TRANSACCION
      AND T.COD_MODULO = M.COD_MODULO
      AND T.COD_MODALIDAD = M.COD_MODALIDAD
      AND FEC_VALOR >= p_fec_inicial
      AND FEC_VALOR <= p_fec_final
      AND T.TIPO IN ('C','D')
      AND AFECTA <> 'N'
      AND VE_CLIENTE = 'S'
      -------
      and b.cod_persona = pp.cod_persona
      and b.cod_grupo = pp.cod_grupo
      and b.nro_cuenta = d.nro_cuenta
 /*UNION ALL
    SELECT FEC_VALOR,
           ---
           fub_con_mon_a_moneda(d.cod_moneda,pp.cod_moneda,m.MONTO) monto,
           ---
           T.COD_TRANSACCION, DECODE(T.COD_TRANSACCION,515,'C',560,'C',565,'C',T.TIPO)
      FROM GE_TRANSACCIONES T, GE_MOVIMIENTOS M, AH_DEV_GRU_CUENTAS B, AH_CTA_VISTAS D,
      ----
      (select distinct m.cod_persona, m.cod_grupo, m.nro_cuenta, l.cod_moneda
            from ah_dev_gru_cuentas m, ah_cta_vistas l
           where m.nro_cuenta = P_NRO_CUENTA
             and m.tipo = 'P' --Principal--
             and l.nro_cuenta = m.nro_cuenta) pp
     ---
     WHERE T.COD_MODULO = d.cod_modulo
       AND T.COD_MODALIDAD = d.cod_modalidad
       AND M.NRO_CUENTA = d.nro_cuenta
       AND T.COD_TRANSACCION = M.COD_TRANSACCION
       AND T.COD_MODULO = M.COD_MODULO
       AND T.COD_MODALIDAD = M.COD_MODALIDAD
       AND FEC_VALOR >= p_fec_inicial
       AND FEC_VALOR <= p_fec_final
       AND T.TIPO IN ('C','D')
       AND VE_CLIENTE = 'S'
       AND AFECTA <> 'N'
       -------
       and b.cod_persona = pp.cod_persona
       and b.cod_grupo = pp.cod_grupo
       and b.nro_cuenta = d.nro_cuenta*/
    ORDER  BY 1;
BEGIN
--dbms_output.put_line('Entre a acumulado');
    --Obtiene la moneda local
    v_cod_mon_local:= VG_MON_LOCAL;
    If p_fec_inicial = to_date('01'||to_char(p_fec_inicial, 'MMYYYY'), 'DDMMYYYY') and
       (p_fec_final = last_day(p_fec_final) or p_fec_final = VG_ULT_MES_HABIL) Then
       --- Busca el saldo promedio ---
       --IF V_TIE_DEV_GRUPAL = 'S' then
         PRA_OBT_SAL_PRO_GRUPAL (p_nro_cuenta,
                                 p_fec_inicial,
                                 p_fec_final,
                                 p_sal_acumulado,
                                 p_sal_promedio,
                                 p_can_dia_acumulado);
       
       -- Obtiene el Saldo Final por si tenga que utilizar para el proximo sub-periodo
       begin
         Select sum(nvl(fub_con_mon_a_moneda(d.cod_moneda,pp.cod_moneda,m.sal_ini_mes),0)) sal_ini_mes
           into p_saldo
           from ah_sal_mensuales M, AH_DEV_GRU_CUENTAS B, AH_CTA_VISTAS D,
           (select distinct m.cod_persona, m.cod_grupo, m.nro_cuenta, l.cod_moneda
            from ah_dev_gru_cuentas m, ah_cta_vistas l
           where m.nro_cuenta = P_NRO_CUENTA
             and m.tipo = 'P' --Principal--
             and l.nro_cuenta = m.nro_cuenta) pp
          where m.nro_cuenta = D.NRO_CUENTA
            and m.mes = to_number(to_char(add_months(p_fec_final,1), 'MM'))
            and m.ano = to_number(to_char(add_months(p_fec_final,1), 'YYYY'))
            ---
            and b.cod_persona = pp.cod_persona
            and b.cod_grupo = pp.cod_grupo
            and b.nro_cuenta = d.nro_cuenta;
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
             INTO v_fec_valor, v_monto, v_cod_transaccion, v_tip_detalle,
                   V_FECHA, V_HORA, V_COD_USUARIO, V_NRO_SECUENCIA;
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
   v_cod_mon_local:= VG_MON_LOCAL;
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
      paa_cta.pr_tas_sig_vigencia(VG_cod_tasa,3,31,VG_cod_oficina,
                                  VG_cod_moneda, VG_nro_cuenta,
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
       lp_cal_sal_acu_grupal(VG_nro_cuenta,
                            v_fec_inicial,
                            v_fec_final,
                            --- OUT
                            p_saldo,
                            v_sal_promedio,
                            v_sal_acumulado,
                            v_can_dia_acumulado);
      -- si hay sub periodo que calcular
      if v_can_dia_acumulado > 0 then
         --
         pag_gen.pr_obt_val_tasa(VG_cod_modulo,  VG_cod_modalidad,
                                 VG_cod_oficina, VG_nro_cuenta,
                                 VG_cod_moneda,  v_sal_promedio,
                                 VG_tas_personalizada, VG_cod_tasa,
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
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',3,VG_COD_MODALIDAD,VG_cod_moneda);
      v_mto_interes := round(v_mto_interes,v_redondeo);
      --- Insertar devengado
      VG_LUGAR := 'Procesar AH_DEVENGADOS (PR_CAL_AH_DEVENGADOS)';
---dbms_output.put_line('Devengado '||v_mto_interes);
      PR_PRO_AH_DEVENGADOS(v_fec_inicial, v_can_dia_acumulado, V_MTO_INTERES,
                                   v_sal_acumulado, v_val_tasa, v_fec_inicial, 0);
      --
      v_mto_int_acumulado := v_mto_int_acumulado + v_mto_interes;
      -----------------------------------------------------------------------
      -- v_tas_vigente := v_sig_val_tasa;
      v_fec_inicial := v_sig_fec_vigencia;
   END LOOP;
exception
   when others then
      VG_IND_ERROR := 'S';
      PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_COD_PARALELO, VG_ORDEN, VG_FEC_ACTUAL,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, 'Dev. Cta. '||VG_nro_cuenta||' '||sqlerrm, VG_nro_cuenta);
      raise_application_error(-20020,'Dev. Cta. '||VG_nro_cuenta||' '||sqlerrm);
END;

PROCEDURE LP_DEV_AH_CTA_VISTAS
 IS
-- Selecciona ahorros a la vista para devengar
   CURSOR C_AH_CTA_VIS_GRUPAL IS
      SELECT COD_MODULO, COD_MODALIDAD, COD_OFICINA, X.NRO_CUENTA, COD_MONEDA, FEC_APERTURA,
        FEC_ULT_CAPITALIZACION, SAL_MINIMO, TAS_PERSONALIZADA, SAL_TOTAL, COD_TASA,
        SAL_DISPONIBLE, u.sal_ult_capitalizacion, FEC_FINAL, FEC_INICIO, SAL_MIN_PACTADO,
        SAL_ACUMULADO, SAL_PROMEDIO, CAN_DIA_ACUMULADO
      FROM AH_DEV_GRU_PEDIDOS_TMP X,
      --Para recuperar saldo ultima capitalizacion grupal--
      (select pp.nro_cuenta nro_cuenta,
              sum(nvl(fub_con_mon_a_moneda(k.cod_moneda, pp.cod_moneda,k.sal_ult_capitalizacion),0)) sal_ult_capitalizacion
              --oilisab--
         from ah_dev_gru_cuentas z, ah_cta_vistas k,
         (select distinct m.cod_persona, m.cod_grupo, m.nro_cuenta, l.cod_moneda
            from ah_dev_gru_cuentas m, ah_cta_vistas l
           where m.nro_cuenta = P_NRO_CUENTA
             and m.tipo = 'P' --Principal--
             and l.nro_cuenta = m.nro_cuenta) pp
        where z.cod_persona = pp.cod_persona
          and z.cod_grupo = pp.cod_grupo
          and k.nro_cuenta = z.nro_cuenta
        group by pp.nro_cuenta) u
      ---
      WHERE X.COD_PARALELO = VG_COD_PARALELO
        and x.nro_cuenta = P_NRO_CUENTA
        and u.nro_cuenta = x.nro_cuenta
        and x.referencia = 'AH_CTA_VIS_PEDIDOS';  --nomar--
BEGIN
      VG_LUGAR := 'Empieza el ciclo';
      FOR CTA_A_DEV IN C_AH_CTA_VIS_GRUPAL  LOOP
         VG_LUGAR             := 'INICIALIZA VARIABLE ';
         VG_SECUENCIA         := 0;
         VG_COD_MODULO        := CTA_A_DEV.COD_MODULO;
         VG_COD_MODALIDAD     := CTA_A_DEV.COD_MODALIDAD;
         VG_COD_OFICINA       := CTA_A_DEV.COD_OFICINA;
         VG_NRO_CUENTA        := CTA_A_DEV.NRO_CUENTA;
         VG_COD_MONEDA        := CTA_A_DEV.COD_MONEDA;
         VG_FEC_ULT_CAPITALIZACION := CTA_A_DEV.FEC_ULT_CAPITALIZACION;
         VG_FEC_APERTURA      := CTA_A_DEV.FEC_APERTURA;
         VG_COD_TASA          := CTA_A_DEV.COD_TASA;
         VG_SAL_DISPONIBLE    := CTA_A_DEV.SAL_DISPONIBLE;
         VG_TAS_PERSONALIZADA := CTA_A_DEV.TAS_PERSONALIZADA;
         VG_FEC_FINAL := CTA_A_DEV.FEC_FINAL;
         VG_LUGAR := 'Inicializa la fecha inicio del Devengado';
         VG_FEC_INICIO := CTA_A_DEV.FEC_INICIO;         --
         VG_LUGAR := 'Inicializa Saldo Minimo Pactado';
         VG_SAL_MIN_PACTADO := CTA_A_DEV.SAL_MIN_PACTADO;
         VG_LUGAR := 'Obtener Saldo Promedio AH_CTA_VISTAS';

         VG_SAL_ACUMULADO := CTA_A_DEV.SAL_ACUMULADO;
         VG_SAL_PROMEDIO := CTA_A_DEV.SAL_PROMEDIO;
         VG_DIA_ACUMULADO := CTA_A_DEV.CAN_DIA_ACUMULADO;
         VG_SAL_ULT_CAPITALIZACION := CTA_A_DEV.SAL_ULT_CAPITALIZACION;
         VG_LUGAR := 'Calcular devengado AH_CTA_VISTAS';
         --- Esta rutina debe coincidir con la capitalización de ahorro a la vista
         PR_CAL_AH_DEV_GRUPAL(VG_FEC_INICIO, VG_FEC_FINAL, VG_SAL_ULT_CAPITALIZACION,
                              VG_SAL_ACUMULADO, VG_DIA_ACUMULADO);
         VG_LUGAR := 'Reversion de devengamiento AH_CTA_VISTAS';
         PR_REV_AH_DEVENGADOS(VG_NRO_CUENTA, VG_FEC_INICIO, VG_FEC_FINAL,VG_FEC_ACTUAL);
      END LOOP;
   END;

PROCEDURE LP_ACT_DAT_DEV_TMP IS
  --Procedimiento autonomo--
  PRAGMA AUTONOMOUS_TRANSACTION;
  --Variables--
  V_SAL_MINIMO AH_CTA_VISTAS.SAL_MINIMO%TYPE;
  V_SAL_ACUMULADO AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE;
  V_SAL_PROMEDIO AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE;
  V_CAN_DIA_ACUMULADO AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;

  --Cursor para traer los datos--
  CURSOR C_DET_DEV_GRUPAL IS
    SELECT X.NRO_CUENTA, X.FUNCIONARIO, X.COD_MODULO,
           X.COD_MODALIDAD, X.COD_MONEDA, X.COD_OFICINA, X.COD_SUB_MODALIDAD,
           X.SAL_MINIMO, X.FEC_INICIO, X.FEC_FINAL, X.ROWID REGISTRO
      FROM AH_DEV_GRU_PEDIDOS_TMP X
     WHERE X.COD_PARALELO = VG_COD_PARALELO
       AND X.NRO_CUENTA = P_NRO_CUENTA
       AND x.referencia = 'AH_CTA_VIS_PEDIDOS';  --nomar--
BEGIN
  --Calculo de Estadisticas posterior a la insercion--
  --BEGIN dbms_stats.gather_table_stats('IT','AH_CTA_VIS_PEDIDOS1'); END;
  VG_LUGAR := 'Tmp-dev_datos';
  --Trae y actualiza los datos de Minimo Pactado--
  for cue in C_DET_DEV_GRUPAL LOOP
      --Limpieza de Variables--
      V_SAL_MINIMO := NULL;
      V_SAL_ACUMULADO := NULL;
      V_SAL_PROMEDIO := NULL;
      V_CAN_DIA_ACUMULADO := NULL;

      --Calculo del Saldo Minimo--
      IF CUE.SAL_MINIMO IS NULL THEN
         If  cue.funcionario = 'S' then
             v_sal_minimo :=  FUG_OBT_PARDINAMICO('SAL_MIN_PAC_EMPLEADO',cue.cod_modulo,cue.cod_modalidad,cue.cod_moneda,cue.cod_oficina,cue.cod_sub_modalidad);
         else
             v_sal_minimo  := FUG_OBT_PARDINAMICO('SAL_MIN_PACTADO',cue.cod_modulo,cue.cod_modalidad,cue.cod_moneda,cue.cod_oficina,cue.cod_sub_modalidad);
         End  if;
      ELSE
        v_sal_minimo := CUE.SAL_MINIMO;
      END IF;

      PRA_OBT_SAL_PRO_GRUPAL (CUE.NRO_CUENTA, CUE.FEC_INICIO, CUE.FEC_FINAL,
                              V_SAL_ACUMULADO, V_SAL_PROMEDIO, V_CAN_DIA_ACUMULADO);

      VG_LUGAR := 'Tmp-upd tabla';
      --Actualizacion de Datos--
      UPDATE AH_DEV_GRU_PEDIDOS_TMP Y
        SET Y.SAL_MIN_PACTADO = v_sal_minimo,
            Y.SAL_ACUMULADO = V_SAL_ACUMULADO,
            Y.SAL_PROMEDIO = V_SAL_PROMEDIO,
            Y.CAN_DIA_ACUMULADO = V_CAN_DIA_ACUMULADO
      WHERE Y.ROWID = CUE.REGISTRO
        AND Y.COD_PARALELO = VG_COD_PARALELO
        AND Y.REFERENCIA = 'AH_CTA_VIS_PEDIDOS'; --nomar--

  END LOOP;

  --Generacion de Estadisticas--
  --BEGIN dbms_stats.gather_table_stats('IT','GE_ARQ_SAL_MEN_AHORROS'); END;
  --Confirmar ya que es independiente--
  COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
         VG_IND_ERROR := 'S';
         PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_COD_PARALELO, VG_ORDEN, VG_FEC_ACTUAL,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, 'Error en PRA_GEN_DAT_DEV_VISTA - '||sqlerrm);
         RAISE_APPLICATION_ERROR(-20001, 'Error en PRA_GEN_DAT_DEV_VISTA - '||sqlerrm);
END;

PROCEDURE LP_MAR_FIN_PROCESO IS
  V_HOR_FIN         VARCHAR2(8);
BEGIN
  --Marca con la hora de finalizacion del proceso--
  V_HOR_FIN := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_COD_PARALELO, VG_ORDEN, VG_FEC_ACTUAL,'F', V_HOR_FIN);

  EXCEPTION
    WHEN OTHERS THEN
         VG_IND_ERROR := 'S';
         PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_COD_PARALELO, VG_ORDEN, VG_FEC_ACTUAL,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, 'LP_MAR_FIN_PROCESO - '||sqlerrm);
         RAISE_APPLICATION_ERROR(-20001, 'LP_MAR_FIN_PROCESO - '||sqlerrm);
END;


/* Devengar Captaciones */
BEGIN
  ------
  VG_LUGAR := 'LP_CAR_VARIABLES';
  VG_COD_MODULO       := 3;
  PAG_CAL.PR_OBT_DAT_CALENDAR(VG_COD_MODULO);
  VG_FEC_ACTUAL       := PAG_CAL.G_FEC_ACTUAL;
  VG_FEC_ANTERIOR     := PAG_CAL.G_FEC_ANTERIOR;
  --VG_FEC_ANTERIOR     := TO_DATE('30/08/2018','DD/MM/YYYY');
  VG_COD_PROGRAMA     := 'PRA_DEV_VIS_PEDIDO';
  VG_NRO_ORDEN        := 0;
  VG_CAN_DEV_PARALELO := '1';
  VG_MON_LOCAL := PAG_GEN.FU_OBT_MON_LOCAL;
  VG_ULT_MES_HABIL := PAG_CAL.G_ULT_DIA_MES_HABIL;
  VG_IND_ERROR := 'N';
  VG_TIP_CONTROL := 'I'; --INSERCION--
  VG_COD_PARALELO := 'DEV1';
  VG_ORDEN := 1;

  --Truncar tabla temporal--
  VG_NRO_ORDEN := NVL(VG_NRO_ORDEN,0) + 1;
  LP_TRU_TMP_DEVENGADOS;

  --Insertar Tabla Temporal--
  VG_NRO_ORDEN := NVL(VG_NRO_ORDEN,0) + 1;
  LP_INS_TMP_DEVENGADOS;

  VG_LUGAR := 'Actualiza Tabla Temporal';
  LP_ACT_DAT_DEV_TMP;

  VG_LUGAR := 'Devengamiento Ahorro a la vista';
  LP_DEV_AH_CTA_VISTAS;

  VG_LUGAR := 'Marca como finalizado con la hora del proceso';
  IF VG_IND_ERROR = 'N' THEN
     LP_MAR_FIN_PROCESO;
  END IF;

  EXCEPTION
      WHEN OTHERS THEN
        VG_IND_ERROR := 'S';
        PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_COD_PARALELO, VG_ORDEN, VG_FEC_ACTUAL,'E', TO_CHAR(SYSDATE,'HH24:MI:SS'), NULL, NULL, NULL, SQLERRM||'-'||VG_LUGAR);
        RAISE_APPLICATION_ERROR(-20001,'Error en PRA_DEV_DIA_PARALELO-'||VG_COD_PARALELO||'-'||SQLERRM||'-'||VG_LUGAR);
END;
/

