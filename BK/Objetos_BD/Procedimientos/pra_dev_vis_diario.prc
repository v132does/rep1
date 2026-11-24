CREATE OR REPLACE PROCEDURE IT.PRA_DEV_VIS_DIARIO IS

VG_COD_MODULO BA_MODULOS.COD_MODULO%TYPE;
VG_LUGAR VARCHAR2(250);
VG_LUG_PROCESO VARCHAR2(250);
VG_FEC_ACTUAL DATE;
VG_FEC_ANTERIOR DATE;
VG_CAN_DEV_PARALELO   NUMBER(4);
VG_IND_ACT_DEV_GENERADOS GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE;
VG_HOR_INICIO       VARCHAR2(8);
VG_HOR_FIN          VARCHAR2(8);
VG_COD_PROGRAMA     GE_LOG_PROCESOS.COD_PROGRAMA%TYPE;
VG_NRO_ORDEN        GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
VG_NRO_ORD_AUX      GE_PRO_PARALELOS_DET.NRO_ORDEN%TYPE;
VG_COD_PRG_PARALELO GE_LOG_PROCESOS.COD_PROGRAMA%TYPE;
VG_REPROCESO   VARCHAR2(1);
VG_TIP_CONTROL VARCHAR2(1);
VG_BAS_DATOS        VARCHAR2(200);
VG_USU_BASE         VARCHAR2(10);
v_usu_mig_excluir varchar2(30);
V_ULT_DIA_MES     ge_calendarios.ult_dia_mes%TYPE;

PROCEDURE LP_VER_USU_BAS_DATOS IS
  V_BAS_PROD GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE;
BEGIN
  VG_LUG_PROCESO := 'LP_VER_USU_BAS_DATOS';
  VG_HOR_INICIO := TO_CHAR(SYSDATE,'HH24:MI:SS');
  V_BAS_PROD := fug_obt_pardinamico('BD_PROD');
  SELECT upper(sys_context('USERENV', 'DB_NAME'))
    INTO vg_bas_datos
    FROM dual;
  IF vg_bas_datos = V_BAS_PROD then
     vg_usu_base := 'IT';
  else
     vg_usu_base := 'DYDTEST';
  end if;
  VG_HOR_FIN := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_ACT_LOG_PROCESOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_FEC_ACTUAL, VG_HOR_INICIO, VG_HOR_FIN);
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, 'Error en LP_VER_USU_BAS_DATOS - '||sqlerrm);
END LP_VER_USU_BAS_DATOS;

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
  V_HAB_DEV_GRUPAL GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE;

BEGIN
  VG_LUG_PROCESO := 'LP_INS_TMP_DEVENGADOS';
  VG_HOR_INICIO := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_NRO_ORDEN, VG_FEC_ACTUAL,VG_TIP_CONTROL, VG_HOR_INICIO);
  --Carga de Variables--
  VG_LUGAR := 'Tmp-Variables';
  --v_fec_actual := VG_FEC_ACTUAL;
  v_cod_seg_funcionario := fug_obt_pardinamico('SEG_FUNCIONARIOS');
  V_HAB_DEV_GRUPAL := NVL(fug_obt_pardinamico('DEV_GRU_HAB_DEV_GRUPAL'),'N');

  VG_LUGAR := 'Tmp-dev_diario';
  --Insertar Tabla Temporal de datos para Devengado diario--
  INSERT /*+APPEND*/ INTO AH_CTA_VIS_DEV_TMP
  (COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA, FEC_APERTURA, FEC_ULT_CAPITALIZACION,
   SAL_MINIMO, TAS_PERSONALIZADA, SAL_TOTAL, COD_TASA, SAL_DISPONIBLE, SAL_ULT_CAPITALIZACION,
   COD_PERSONA, FUNCIONARIO, COD_SUB_MODALIDAD, FEC_INICIO, FEC_FINAL, COD_PARALELO)

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
         'DEV'||TRIM(TO_CHAR((ROWNUM - (TRUNC(rownum / VG_CAN_DEV_PARALELO)*VG_CAN_DEV_PARALELO))+1)) COD_PARALELO
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
       AND (v_usu_mig_excluir is null or a.usu_insercion <> v_usu_mig_excluir)
       --Proyecto Dev. Grupal Cta Tran. Bancard - CORECTRB-19--
       --Se excluyen detalles de los grupos--
       AND ((V_HAB_DEV_GRUPAL = 'N') OR (V_HAB_DEV_GRUPAL = 'S' AND NOT EXISTS (SELECT 1
                                                                                  FROM AH_DEV_GRU_CUENTAS Y
                                                                                 WHERE Y.NRO_CUENTA = B.NRO_CUENTA
                                                                                   AND Y.TIPO = 'D')));

  --Calculo de Estadisticas posterior a la insercion--
  --BEGIN dbms_stats.gather_table_stats(vg_usu_base,'AH_CTA_VIS_DEV_TMP'); END;

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
  sql_util.ejecute_dml('TRUNCATE TABLE AH_CTA_VIS_DEV_TMP', v_msj);
  if v_msj is not null then
     RAISE_APPLICATION_ERROR(-20001, v_msj);
  end if;

  --Truncar Tabla Temporal de Devengados--
  V_MSJ := NULL;
  SQL_UTIL.EJECUTE_DML('TRUNCATE TABLE AH_DEVENGADOS_TMP', V_MSJ);
  IF V_MSJ IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20001, V_MSJ);
  END IF;
  IF NVL(VG_IND_ACT_DEV_GENERADOS,'N') = 'N' THEN
    --Inserta Datos necesarios para calculo en Temporal--
    INSERT INTO AH_DEVENGADOS_TMP
    SELECT * FROM AH_DEVENGADOS X
     WHERE X.FECHA = VG_FEC_ANTERIOR;
  END IF;
  COMMIT;
  VG_HOR_FIN := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_NRO_ORDEN, VG_FEC_ACTUAL,'F', VG_HOR_FIN);
  PRG_ACT_LOG_PROCESOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_FEC_ACTUAL, VG_HOR_INICIO, VG_HOR_FIN);
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, 'Error en PL_TRU_TAB_DEVENGADOS - '||sqlerrm);
END;

PROCEDURE LP_ELI_DAT_ANTERIORES IS
BEGIN
  VG_LUG_PROCESO := 'LP_ELI_DAT_ANTERIORES';
  VG_HOR_INICIO := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_NRO_ORDEN, VG_FEC_ACTUAL,VG_TIP_CONTROL, VG_HOR_INICIO);
  IF VG_REPROCESO = 'N' THEN
     DELETE FROM GE_PRO_PARALELOS_DET C
      WHERE C.COD_PROGRAMA = VG_COD_PROGRAMA
        AND C.FECHA < VG_FEC_ACTUAL;
  END IF;
  VG_HOR_FIN := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_NRO_ORDEN, VG_FEC_ACTUAL,'F', VG_HOR_FIN);
  PRG_ACT_LOG_PROCESOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_FEC_ACTUAL, VG_HOR_INICIO, VG_HOR_FIN);
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, 'Error en LP_ELI_DAT_ANTERIORES - '||sqlerrm);
END;

PROCEDURE LP_ELI_JOB_PARALELOS IS
  CURSOR C_JOB_PARALELOS IS
        select a.job
          from user_jobs a
         where UPPER(what) like '%'||UPPER(VG_COD_PRG_PARALELO)||'%'
         order by job;
BEGIN
  VG_LUG_PROCESO := 'LP_ELI_JOB_PARALELOS';
  VG_HOR_INICIO := TO_CHAR(SYSDATE,'HH24:MI:SS');
  FOR DET IN C_JOB_PARALELOS LOOP
      BEGIN DBMS_JOB.REMOVE(DET.JOB); END;
  END LOOP;
  VG_HOR_FIN := TO_CHAR(SYSDATE,'HH24:MI:SS');
  PRG_ACT_LOG_PROCESOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_FEC_ACTUAL, VG_HOR_INICIO, VG_HOR_FIN);
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, 'Error en LP_ELI_JOB_PARALELOS - '||sqlerrm);
END;

FUNCTION LF_VER_REPROCESO RETURN VARCHAR2 IS
  V_REPROCESO VARCHAR2(1);
BEGIN
  --Verificar si es un reproceso--
  SELECT DECODE(NVL(COUNT(*),0),0,'N','S')
    INTO V_REPROCESO
    FROM GE_PRO_PARALELOS_DET C
   WHERE C.COD_PROGRAMA = VG_COD_PROGRAMA
     AND C.FECHA = VG_FEC_ACTUAL;
  RETURN V_REPROCESO;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, 'Error en LF_VER_REPROCESO - '||sqlerrm);
END;

PROCEDURE LP_EJE_PRO_DEV_PARALELO IS
  --Variables--
  V_JOBS                   NUMBER;
  V_CAN_PRO_ACTIVOS        NUMBER;
  V_CAN_PRO_ERROR          NUMBER;
  V_DATE                   DATE;
  V_INDICE                 NUMBER(4);
  V_SENTENCIA              VARCHAR2(4000);
  V_COD_PARALELO           VARCHAR2(8);
  V_HORA                   VARCHAR2(8);
  V_MSG_ERROR              VARCHAR2(8000);
  V_CAN_REG_ERROR          NUMBER;
  V_CAN_DET_ERROR          NUMBER;

  CURSOR C_DET_PRO_REP_PARALELO IS
     SELECT T.COD_PROGRAMA, T.COD_SUB_PROGRAMA, T.NRO_ORDEN, T.FECHA
       FROM GE_PRO_PARALELOS_DET t
      WHERE T.COD_PROGRAMA = VG_COD_PRG_PARALELO
        AND T.FECHA = VG_FEC_ACTUAL
        AND T.HOR_FIN IS NULL;

  CURSOR C_DET_PRO_REP_ERRORES IS
     SELECT T.COD_PROGRAMA, T.COD_SUB_PROGRAMA, T.NRO_ORDEN, T.FECHA,
            T.NRO_REFERENCIA, T.ERROR, T.HOR_INICIO
       FROM GE_PRO_PARALELOS_DET t
      WHERE T.COD_PROGRAMA = VG_COD_PRG_PARALELO
        AND T.FECHA = VG_FEC_ACTUAL
        AND T.HOR_FIN IS NULL
        AND T.ERROR IS NOT NULL;
BEGIN
     VG_LUG_PROCESO := 'LP_EJE_PRO_DEV_PARALELO';
     VG_HOR_INICIO := TO_CHAR(SYSDATE,'HH24:MI:SS');
     VG_NRO_ORD_AUX := VG_NRO_ORDEN;
     PAG_CAL.PR_OBT_DAT_CALENDAR(VG_COD_MODULO);
     V_ULT_DIA_MES      := PAG_CAL.G_ULT_DIA_MES_HABIL;
     PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_NRO_ORDEN, VG_FEC_ACTUAL, VG_TIP_CONTROL, VG_HOR_INICIO);
    IF VG_REPROCESO = 'N' THEN
        --Ciclo para habilitar los hilos de procesos en paralelo--
        FOR V_INDICE IN 1..VG_CAN_DEV_PARALELO LOOP
          --IF V_INDICE IN (2,4) THEN
            V_SENTENCIA := NULL;
            VG_NRO_ORDEN := NVL(VG_NRO_ORDEN,0) + 1;
            V_COD_PARALELO := 'DEV'||TRIM(TO_CHAR(V_INDICE,'99'));
            V_SENTENCIA := 'begin begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 3; end; '||VG_COD_PRG_PARALELO||'('||
                           CHR(39)||V_COD_PARALELO||CHR(39)||','||TO_CHAR(VG_NRO_ORDEN)||'); end;';
            --Inicia Hilos de Procesos--
            V_HORA := TO_CHAR(SYSDATE,'HH24:MI:SS');
            DBMS_JOB.submit(v_jobs,V_SENTENCIA);
            --Inserta aqui, y es controlado en el programa de calculo--
            PRG_CON_PRO_PARALELOS(VG_COD_PRG_PARALELO, V_COD_PARALELO, VG_NRO_ORDEN, VG_FEC_ACTUAL,'I', V_HORA, v_jobs);
            COMMIT;
          --END IF;
        END LOOP;
        V_CAN_PRO_ACTIVOS := VG_CAN_DEV_PARALELO;
        --Calculo de Estadisticas posterior a la insercion--
        --BEGIN dbms_stats.gather_table_stats(vg_usu_base,'GE_PRO_PARALELOS_DET'); END;
    ELSE --ES UN REPROCESO--
        V_INDICE := 0;
        FOR DET IN C_DET_PRO_REP_PARALELO LOOP
            V_INDICE := NVL(V_INDICE,0) + 1;
            V_SENTENCIA := NULL;
            V_COD_PARALELO := DET.COD_SUB_PROGRAMA;
            V_SENTENCIA := 'begin begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 3; end; '||VG_COD_PRG_PARALELO||'('||
                           CHR(39)||V_COD_PARALELO||CHR(39)||','||TO_CHAR(DET.NRO_ORDEN)||'); end;';
            --Inicia Hilos de Procesos--
            V_HORA := TO_CHAR(SYSDATE,'HH24:MI:SS');
            DBMS_JOB.submit(v_jobs,V_SENTENCIA);
            --Actualiza programa de control--
            PRG_CON_PRO_PARALELOS(VG_COD_PRG_PARALELO, V_COD_PARALELO, DET.NRO_ORDEN, VG_FEC_ACTUAL,'R', V_HORA, v_jobs);
            COMMIT;
        END LOOP;
        IF V_INDICE = 0 THEN
              FOR V_INDICE IN 1..VG_CAN_DEV_PARALELO LOOP
                  V_SENTENCIA := NULL;
                  VG_NRO_ORDEN := NVL(VG_NRO_ORDEN,0) + 1;
                  V_COD_PARALELO := 'DEV'||TRIM(TO_CHAR(V_INDICE,'99'));
                  V_SENTENCIA := 'begin begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 3; end; '||VG_COD_PRG_PARALELO||'('||
                                 CHR(39)||V_COD_PARALELO||CHR(39)||','||TO_CHAR(VG_NRO_ORDEN)||'); end;';
                  V_HORA := TO_CHAR(SYSDATE,'HH24:MI:SS');
                  DBMS_JOB.submit(v_jobs,V_SENTENCIA);
                  PRG_CON_PRO_PARALELOS(VG_COD_PRG_PARALELO, V_COD_PARALELO, VG_NRO_ORDEN, VG_FEC_ACTUAL,'I', V_HORA, v_jobs);
                  COMMIT;
              END LOOP;
              V_CAN_PRO_ACTIVOS := VG_CAN_DEV_PARALELO;
         ELSE
              V_CAN_PRO_ACTIVOS := V_INDICE;
         END IF;
    END IF;
  /*
   Se controla ejecucion unicamente en cierres de fin de mes,
   cierre diario se ejecuta en segundo plano.
  */
  /*IF VG_FEC_ACTUAL = V_ULT_DIA_MES THEN
    --Controla la finalizacion de los hilos de procesos--
    WHILE V_CAN_PRO_ACTIVOS > 0 LOOP
        select NVL(count(*),0)
          into V_CAN_PRO_ACTIVOS
          from user_jobs x
         where UPPER(what) like '%'||UPPER(VG_COD_PRG_PARALELO)||'%'
           and exists (select 1 from GE_PRO_PARALELOS_DET y
                        where y.nro_referencia = x.JOB
                          and y.fecha = VG_FEC_ACTUAL);
        select NVL(count(*),0)
          into V_CAN_PRO_ERROR
          from user_jobs x
         where UPPER(what) like '%'||UPPER(VG_COD_PRG_PARALELO)||'%'
           and failures > 0
           and exists (select 1 from GE_PRO_PARALELOS_DET y
                        where y.nro_referencia = x.JOB
                          and y.fecha = VG_FEC_ACTUAL);
         if V_CAN_PRO_ACTIVOS = V_CAN_PRO_ERROR then
            V_CAN_PRO_ACTIVOS := 0;
         end if;
         v_date := pai_int.smg_sleep('2');
      END LOOP;
    END IF;*/
    VG_HOR_FIN := TO_CHAR(SYSDATE,'HH24:MI:SS');
    PRG_ACT_LOG_PROCESOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_FEC_ACTUAL, VG_HOR_INICIO, VG_HOR_FIN);

    --Controla el error en los procesos--
    IF NVL(V_CAN_PRO_ERROR,0) = 0 THEN
       V_HORA := TO_CHAR(SYSDATE,'HH24:MI:SS');
       PRG_CON_PRO_PARALELOS(VG_COD_PROGRAMA, VG_LUG_PROCESO, VG_NRO_ORD_AUX, VG_FEC_ACTUAL,'F', V_HORA);
    ELSE
       --Desplegar los Errores--
       V_MSG_ERROR := NULL;
       V_CAN_REG_ERROR := 0;
       FOR DET IN C_DET_PRO_REP_ERRORES LOOP
           V_CAN_REG_ERROR := NVL(V_CAN_REG_ERROR,0) + 1;
           V_MSG_ERROR := V_MSG_ERROR||DET.COD_SUB_PROGRAMA||'-'||DET.ERROR||chr(10);
           IF DET.NRO_REFERENCIA IS NOT NULL THEN
              --Se eliminar jobs con error para no volver a ejecutar--
              BEGIN DBMS_JOB.REMOVE(DET.NRO_REFERENCIA); END;
              COMMIT;
           END IF;
       END LOOP;
       IF V_CAN_REG_ERROR > 0 THEN
          SELECT NVL(COUNT(*),0)
            INTO V_CAN_DET_ERROR
            FROM AH_CTA_VIS_DEV_TMP T
           WHERE T.COD_PARALELO LIKE '%ERROR%';
          V_MSG_ERROR := 'Error en LP_EJE_PRO_DEV_PARALELO - '||
                 'Ctas c/ Errores: ('||TO_CHAR(V_CAN_DET_ERROR)||') - **REPROCESE**'||chr(10)||V_MSG_ERROR;
          --Envio de emails con datos del error--
          LP_TRA_ENV_EMAIL(V_MSG_ERROR);
          RAISE_APPLICATION_ERROR(-20001, V_MSG_ERROR);
       END IF;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, 'Error en LP_EJE_PRO_DEV_PARALELO - '||sqlerrm);
END;

PROCEDURE LP_EJE_PRO_REPROCESO IS
  CURSOR C_DET_PRO_REPROCESO IS
     SELECT T.COD_PROGRAMA, T.COD_SUB_PROGRAMA, T.NRO_ORDEN, T.FECHA
       FROM GE_PRO_PARALELOS_DET t
      WHERE T.COD_PROGRAMA = VG_COD_PROGRAMA
        AND T.FECHA = VG_FEC_ACTUAL
        AND T.HOR_FIN IS NULL;
  v_pro_eli BOOLEAN := FALSE;
  v_pro_tru BOOLEAN := FALSE;
  v_pro_ins BOOLEAN := FALSE;
  v_pro_eje BOOLEAN := FALSE;
BEGIN
  FOR PRO IN C_DET_PRO_REPROCESO LOOP
      VG_NRO_ORDEN := PRO.NRO_ORDEN;
      IF PRO.COD_SUB_PROGRAMA = 'LP_ELI_DAT_ANTERIORES' THEN
         --Eliminar Datos Annteriores--
         LP_ELI_DAT_ANTERIORES;
         v_pro_eli := TRUE;
      END IF;

      IF PRO.COD_SUB_PROGRAMA = 'LP_TRU_TMP_DEVENGADOS' THEN
         --Truncar tabla temporal--
         LP_TRU_TMP_DEVENGADOS;
         v_pro_eli := TRUE;
         v_pro_tru := TRUE;
      END IF;

      IF PRO.COD_SUB_PROGRAMA = 'LP_INS_TMP_DEVENGADOS' THEN
         --Insertar Tabla Temporal--
         LP_INS_TMP_DEVENGADOS;
         v_pro_eli := TRUE;
         v_pro_tru := TRUE;
         v_pro_ins := TRUE;
      END IF;

      IF PRO.COD_SUB_PROGRAMA = 'LP_EJE_PRO_DEV_PARALELO' THEN
         --Ejecutar Devengamiento Paralelo--
         LP_EJE_PRO_DEV_PARALELO;
         v_pro_eli := TRUE;
         v_pro_tru := TRUE;
         v_pro_ins := TRUE;
         v_pro_eje := TRUE;
      END IF;
  END LOOP;
    ---DEBE EJECUTAR LOS PROCESOS RESTANTES QUE NO TRAEN EL CURSOR.
   --Eliminar Datos Anteriores--
   IF NOT v_pro_eli THEN
      VG_TIP_CONTROL := 'I';
      VG_NRO_ORDEN := 1;
      LP_ELI_DAT_ANTERIORES;
   END IF;
   --Truncar tabla temporal-- 
   IF NOT v_pro_tru THEN
         VG_TIP_CONTROL := 'I';
         VG_NRO_ORDEN := 2;
         LP_TRU_TMP_DEVENGADOS;
    END IF;
    --Insertar Tabla Temporal--
    IF NOT v_pro_ins THEN
      VG_TIP_CONTROL := 'I';
       VG_NRO_ORDEN := 3;
       LP_INS_TMP_DEVENGADOS;
    END IF;
    --Ejecutar Devengamiento Paralelo--
    IF NOT v_pro_eje THEN
       VG_TIP_CONTROL := 'I';
       VG_NRO_ORDEN := 4;
       LP_EJE_PRO_DEV_PARALELO;
     END IF;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, 'Error en LP_EJE_PRO_REPROCESO - '||sqlerrm);
END;

/* Devengar Captaciones */

BEGIN
  --Carga de Variables Globales--
  VG_LUGAR := 'LP_CAR_VARIABLES';
  VG_COD_MODULO       := 3;
  PAG_CAL.PR_OBT_DAT_CALENDAR(VG_COD_MODULO);
  VG_FEC_ACTUAL       := PAG_CAL.G_FEC_ACTUAL;
  VG_FEC_ANTERIOR     := PAG_CAL.G_FEC_ANTERIOR;
  VG_COD_PROGRAMA     := 'PRA_DEV_VIS_DIARIO';
  VG_COD_PRG_PARALELO := 'PRA_DEV_VIS_PARALELO';
  VG_NRO_ORDEN        := 0;
  VG_CAN_DEV_PARALELO := NVL(fug_obt_pardinamico('CAN_DEV_PARALELO'),'1');
  VG_IND_ACT_DEV_GENERADOS := NVL(fug_obt_pardinamico('IND_ACT_DEV_GENERADOS'),'N');
  VG_REPROCESO        := LF_VER_REPROCESO;
  v_usu_mig_excluir := fug_obt_pardinamico('COD_USU_MIG_EXCLUIR');

  --Verificar Base y Usuario--
  LP_VER_USU_BAS_DATOS;

  --Eliminar procesos paralelos--
  LP_ELI_JOB_PARALELOS;

  IF VG_REPROCESO = 'N' THEN
     VG_TIP_CONTROL := 'I'; --INSERCION--
     --Validar Reproceso--
     VG_NRO_ORDEN := NVL(VG_NRO_ORDEN,0) + 1;
     LP_ELI_DAT_ANTERIORES;

     --Truncar tabla temporal--
     VG_NRO_ORDEN := NVL(VG_NRO_ORDEN,0) + 1;
     LP_TRU_TMP_DEVENGADOS;

     --Insertar Tabla Temporal--
     VG_NRO_ORDEN := NVL(VG_NRO_ORDEN,0) + 1;
     LP_INS_TMP_DEVENGADOS;

     --Ejecutar Devengamiento Paralelo--
     VG_NRO_ORDEN := NVL(VG_NRO_ORDEN,0) + 1;
     LP_EJE_PRO_DEV_PARALELO;
  ELSE
     VG_TIP_CONTROL := 'R'; --Reproceso--
     --Ejecutar Reproceso--
     LP_EJE_PRO_REPROCESO;
  END IF;

  EXCEPTION
      WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20001,'Error en PRA_DEV_VIS_PROCESO-'||SQLERRM||'-'||VG_LUGAR);
END;
/
