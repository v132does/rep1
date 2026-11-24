CREATE OR REPLACE PROCEDURE IT.PRA_DEV_DIA_PRO_TMP IS

VG_COD_MODULO AH_CTA_VISTAS.COD_MODULO%TYPE := 3;
VG_LUGAR VARCHAR2(250);
VG_FEC_ACTUAL DATE;
VG_CAN_DEV_PARALELO   NUMBER(4);

/* Obtiene el Saldo Promedio de una Cuenta */
FUNCTION FL_OBT_SAL_PROMEDIO
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
PROCEDURE PL_INS_TMP_DEVENGADOS IS
  --Procedimiento autonomo--
  PRAGMA AUTONOMOUS_TRANSACTION;
  --Variables--
  V_COD_SEG_FUNCIONARIO GE_SEG_CLIENTES.COD_SEG_CLIENTE%TYPE;

BEGIN
  --Carga de Variables--
  VG_LUGAR := 'Tmp-Variables';
  --v_fec_actual := VG_FEC_ACTUAL;
  v_cod_seg_funcionario := fug_obt_pardinamico('SEG_FUNCIONARIOS');

  VG_LUGAR := 'Tmp-dev_diario';
  --Insertar Tabla Temporal de datos para Devengado diario--
  INSERT /*+APPEND*/ INTO AH_CTA_VIS_DEV_TMP
  (COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA, FEC_APERTURA, FEC_ULT_CAPITALIZACION,
   SAL_MINIMO, TAS_PERSONALIZADA, SAL_TOTAL, COD_TASA, SAL_DISPONIBLE, SAL_ULT_CAPITALIZACION,
   COD_PERSONA, FUNCIONARIO, COD_SUB_MODALIDAD, FEC_INICIO, FEC_FINAL, COD_PARALELO/*, SAL_MIN_PACTADO,
   SAL_ACUMULADO, SAL_PROMEDIO, CAN_DIA_ACUMULADO*/)

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
         'DEV'||TRIM(TO_CHAR((ROWNUM - (TRUNC(rownum / VG_CAN_DEV_PARALELO)*VG_CAN_DEV_PARALELO))+1)) COD_PARALELO/*,
         ---SALDO MINIMO--
         CASE WHEN A.SAL_MINIMO IS NULL THEN
             ---
             CASE WHEN
                (CASE WHEN NVL(U.CAN_USUARIO,0) > 0 THEN 'S'
                WHEN NVL(U.CAN_USUARIO,0) <= 0 AND C.COD_SEG_CLIENTE = V_COD_SEG_FUNCIONARIO THEN 'S'
                ELSE 'N' END) = 'S' then
                  to_number(FUG_OBT_PARDINAMICO('SAL_MIN_PAC_EMPLEADO',A.cod_modulo,A.cod_modalidad,A.cod_moneda,A.cod_oficina,A.cod_sub_modalidad))
             ELSE
                  to_number(FUG_OBT_PARDINAMICO('SAL_MIN_PACTADO',A.cod_modulo,A.cod_modalidad,A.cod_moneda,A.cod_oficina,A.cod_sub_modalidad))
             END
         ELSE
            A.SAL_MINIMO
         END SAL_MIN_PACTADO,
         -----
         FUG_OBT_SAL_PRO_FECHAS(A.NRO_CUENTA,
         CASE WHEN A.FEC_ULT_CAPITALIZACION IS NULL THEN A.FEC_APERTURA
             WHEN A.FEC_ULT_CAPITALIZACION >= A.FEC_APERTURA THEN A.FEC_ULT_CAPITALIZACION + 1
             ELSE TO_DATE(NULL)
        END,
         CASE
          WHEN D.FEC_ACTUAL = D.ULT_DIA_MES_HABIL THEN D.ULT_DIA_MES
          WHEN D.FEC_ACTUAL = D.PRI_DIA_MES_HABIL AND D.PRI_DIA_MES_HABIL != D.PRI_DIA_MES THEN D.FEC_PROXIMA - 1
         ELSE
            D.FEC_PROXIMA - 1
         END,
         'A'),
         FUG_OBT_SAL_PRO_FECHAS(A.NRO_CUENTA,
         CASE WHEN A.FEC_ULT_CAPITALIZACION IS NULL THEN A.FEC_APERTURA
             WHEN A.FEC_ULT_CAPITALIZACION >= A.FEC_APERTURA THEN A.FEC_ULT_CAPITALIZACION + 1
             ELSE TO_DATE(NULL)
        END,
         CASE
          WHEN D.FEC_ACTUAL = D.ULT_DIA_MES_HABIL THEN D.ULT_DIA_MES
          WHEN D.FEC_ACTUAL = D.PRI_DIA_MES_HABIL AND D.PRI_DIA_MES_HABIL != D.PRI_DIA_MES THEN D.FEC_PROXIMA - 1
         ELSE
            D.FEC_PROXIMA - 1
         END,
         'P'),
         FUG_OBT_SAL_PRO_FECHAS(A.NRO_CUENTA,
         CASE WHEN A.FEC_ULT_CAPITALIZACION IS NULL THEN A.FEC_APERTURA
             WHEN A.FEC_ULT_CAPITALIZACION >= A.FEC_APERTURA THEN A.FEC_ULT_CAPITALIZACION + 1
             ELSE TO_DATE(NULL)
        END,
         CASE
          WHEN D.FEC_ACTUAL = D.ULT_DIA_MES_HABIL THEN D.ULT_DIA_MES
          WHEN D.FEC_ACTUAL = D.PRI_DIA_MES_HABIL AND D.PRI_DIA_MES_HABIL != D.PRI_DIA_MES THEN D.FEC_PROXIMA - 1
         ELSE
            D.FEC_PROXIMA - 1
         END,
         'C')*/
         -----
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
       AND D.COD_MODULO = 3;

  --Calculo de Estadisticas posterior a la insercion--
  BEGIN dbms_stats.gather_table_stats('IT','AH_CTA_VIS_DEV_TMP'); END;

  --Confirmar ya que es independiente--
  COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, 'Error en PRA_GEN_DAT_DEV_VISTA - '||sqlerrm);
END;

PROCEDURE PL_TRU_TMP_DEVENGADOS IS
  v_msj VARCHAR2(2000);
BEGIN
  --Truncar tabla Temporal de Cuentas--
  VG_LUGAR := 'Tmp-truncar';
  v_msj := null;
  sql_util.ejecute_dml('TRUNCATE TABLE AH_CTA_VIS_DEV_TMP', v_msj);
  if v_msj is not null then
     RAISE_APPLICATION_ERROR(-20001, v_msj);
  end if;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, 'Error en PL_TRU_TAB_DEVENGADOS - '||sqlerrm);
END;

PROCEDURE PL_EJE_PRO_DEV_PARALELO IS
  --Variables--
  V_JOBS                   NUMBER;
  V_CAN_PRO_ACTIVOS        NUMBER;
  V_DATE                   DATE;
  --V_CAN_DEV_VIS_PARALELO   NUMBER(2);
  V_INDICE                 NUMBER(2);
  V_SENTENCIA              VARCHAR2(4000);
BEGIN
    --Busca parametro de cantidad de procesos en paralelo--
    --V_CAN_DEV_VIS_PARALELO := NVL(fug_obt_pardinamico('CAN_DEV_VIS_PARALELO'),'1');

    --Ciclo para habilitar los hilos de procesos en paralelo--
    FOR V_INDICE IN 1..VG_CAN_DEV_PARALELO LOOP
        V_SENTENCIA := NULL;
        V_SENTENCIA := 'begin begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 3; end; pra_dev_dia_par_tmp('||
                       CHR(39)||'DEV'||TRIM(TO_CHAR(V_INDICE,'99'))||CHR(39)||'); end;';
        DBMS_OUTPUT.put_line(V_SENTENCIA);

        --Inicia Hilos de Procesos--
        DBMS_JOB.submit(v_jobs,V_SENTENCIA);
        COMMIT;
    END LOOP;

    --Controla la finalizacion de los hilos de procesos--
    V_CAN_PRO_ACTIVOS := VG_CAN_DEV_PARALELO;
    WHILE V_CAN_PRO_ACTIVOS > 0 LOOP
      select count(*)
        into V_CAN_PRO_ACTIVOS
        from user_jobs
       where what like '%pra_dev_dia_par_tmp%';
       v_date := pai_int.smg_sleep('2');
    END LOOP;

END;

/* Devengar Captaciones */
BEGIN
  VG_LUGAR     := 'Obtener Variables';
  PAG_CAL.PR_OBT_DAT_CALENDAR(VG_COD_MODULO);
  VG_FEC_ACTUAL    := PAG_CAL.G_FEC_ACTUAL;
  VG_CAN_DEV_PARALELO := NVL(fug_obt_pardinamico('CAN_DEV_PARALELO'),'1');

  VG_LUGAR := 'Truncar datos Tabla Temporal';
  PL_TRU_TMP_DEVENGADOS;

  VG_LUGAR := 'Insercion de Tabla de Temporal';
  PL_INS_TMP_DEVENGADOS;

  VG_LUGAR := 'Ejecutar Devengamiento en Paralelo';
  PL_EJE_PRO_DEV_PARALELO;

  EXCEPTION
      WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20001,'Error en PRA_DEV_DIA_PROCESO-'||SQLERRM||'-'||VG_LUGAR);
END;
/

