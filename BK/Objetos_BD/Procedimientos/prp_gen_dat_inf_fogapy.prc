CREATE OR REPLACE PROCEDURE IT.PRP_GEN_DAT_INF_FOGAPY ( 
    P_TIP_EJECUCION IN VARCHAR2 DEFAULT NULL,
    P_FEC_CORTE     IN DATE     DEFAULT NULL
) IS

    V_TIP_EJECUCION    VARCHAR2(1);
    V_FEC_CORTE         DATE;
    V_FEC_INI_PERIODO   DATE;
    V_FEC_PROX_CIERRE   DATE;
    V_FEC_ACTUAL        DATE;
    V_FEC_INI_PROCESO   DATE := SYSDATE;
    V_CAN_HISTORICO     NUMBER;
    V_CAN_ELIMINADOS    NUMBER := 0;
    V_CAN_REGISTROS     NUMBER := 0;
    V_COD_PROCESO       NUMBER;
    V_NRO_ERROR         NUMBER;
    V_MEN_ERROR         VARCHAR2(500);

    PROCEDURE LP_INS_LOG (
        P_NRO_ERROR  IN NUMBER,
        P_MEN_ERROR  IN VARCHAR2,
        P_COMENTARIO IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO IT.GE_LOG_PROCESOS (
            FECHA, COD_PROGRAMA, COD_PROCESO, HOR_INICIO, HOR_FIN, OBSERVACION,
            USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION
        ) VALUES (
            NVL(V_FEC_ACTUAL, TRUNC(SYSDATE)), 'PRP_GEN_DAT_INF_FOGAPY', NVL(TO_CHAR(V_COD_PROCESO), 'FOGAPY'),
            TO_CHAR(V_FEC_INI_PROCESO, 'HH24:MI:SS'), TO_CHAR(SYSDATE, 'HH24:MI:SS'),
            SUBSTR(CASE WHEN P_NRO_ERROR <> 0 THEN P_MEN_ERROR || ' | ' END || P_COMENTARIO, 1, 400),
            SUBSTR(USER, 1, 10), SYSDATE, SUBSTR(USER, 1, 10), SYSDATE
        );
        COMMIT;
    END LP_INS_LOG;
BEGIN
    V_TIP_EJECUCION := UPPER(TRIM(P_TIP_EJECUCION));
    V_COD_PROCESO   := CASE V_TIP_EJECUCION WHEN 'A' THEN 930 WHEN 'C' THEN 931 END;

    IF V_TIP_EJECUCION IS NULL OR V_TIP_EJECUCION NOT IN ('A', 'C') THEN
        RAISE_APPLICATION_ERROR(-20031, 'Tipo de ejecucion invalido (' || P_TIP_EJECUCION || '). Valores permitidos: A, C.');
    END IF;

    V_FEC_ACTUAL := TRUNC(PAG_CAL.FU_OBT_FEC_ACTUAL(6));

    IF P_FEC_CORTE IS NOT NULL AND     TRUNC(P_FEC_CORTE, 'MM') <> TRUNC(V_FEC_ACTUAL, 'MM') THEN
        RAISE_APPLICATION_ERROR(-20038, 'La fecha de corte ' || TO_CHAR(P_FEC_CORTE, 'DD/MM/YYYY')
                || ' no corresponde al mes actual (' || TO_CHAR(V_FEC_ACTUAL, 'MM/YYYY')
            || '). Solo se puede generar para el mes actual.');
    END IF;

    IF V_TIP_EJECUCION = 'A' THEN
      V_FEC_CORTE := NVL(TRUNC(P_FEC_CORTE), TRUNC(PAG_CAL.FU_OBT_FEC_ANTERIOR(6)));

      SELECT MAX(fecha)
        INTO V_FEC_INI_PERIODO
        FROM (
            SELECT (TRUNC(V_FEC_CORTE, 'MM') - LEVEL) AS fecha
              FROM DUAL
            CONNECT BY LEVEL <= 31
        )
       WHERE TO_CHAR(fecha, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN') NOT IN ('SAT', 'SUN')
         AND fecha NOT IN (SELECT fecha FROM IT.BA_FERIADOS);

      V_FEC_PROX_CIERRE := LAST_DAY(ADD_MONTHS(TRUNC(V_FEC_CORTE), 1));
    ELSE
        IF P_FEC_CORTE IS NOT NULL THEN
            V_FEC_CORTE := TRUNC(P_FEC_CORTE);
        ELSE
            SELECT MAX(fecha)
              INTO V_FEC_CORTE
              FROM (
                  SELECT (LAST_DAY(ADD_MONTHS(V_FEC_ACTUAL, -1)) - LEVEL + 1) AS fecha
                    FROM DUAL
                  CONNECT BY LEVEL <= 31
              )
             WHERE fecha >= TRUNC(ADD_MONTHS(V_FEC_ACTUAL, -1), 'MM')
               AND TO_CHAR(fecha, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN') NOT IN ('SAT', 'SUN')
               AND fecha NOT IN (SELECT fecha FROM IT.BA_FERIADOS);
        END IF;

        SELECT MIN(fecha)
          INTO V_FEC_INI_PERIODO
          FROM (
              SELECT (TRUNC(V_FEC_CORTE, 'MM') + LEVEL - 1) AS fecha
                FROM DUAL
              CONNECT BY LEVEL <= 31
          )
         WHERE fecha <= LAST_DAY(V_FEC_CORTE)
           AND TO_CHAR(fecha, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN') NOT IN ('SAT', 'SUN')
           AND fecha NOT IN (SELECT fecha FROM IT.BA_FERIADOS);

        V_FEC_PROX_CIERRE := LAST_DAY(ADD_MONTHS(TRUNC(V_FEC_CORTE), 1));
    END IF;

    IF V_FEC_CORTE IS NULL OR V_FEC_INI_PERIODO IS NULL THEN
        RAISE_APPLICATION_ERROR(-20032, 'No se pudo determinar la fecha de corte para la fecha ' || TO_CHAR(V_FEC_ACTUAL, 'DD/MM/YYYY') || '.');
    END IF;

    SELECT COUNT(*)
      INTO V_CAN_HISTORICO
      FROM IT.PR_CTA_PRESTAMOS_HIS PCP
     WHERE PCP.FECHA >= V_FEC_CORTE
       AND PCP.FECHA <  V_FEC_CORTE + 1
       AND ROWNUM = 1;

    IF V_CAN_HISTORICO = 0 THEN
        RAISE_APPLICATION_ERROR(-20033, 'No existe historico de prestamos (PR_CTA_PRESTAMOS_HIS) al ' || TO_CHAR(V_FEC_CORTE, 'DD/MM/YYYY')
            || '. Fecha: ' || TO_CHAR(V_FEC_ACTUAL, 'DD/MM/YYYY') || '.');
    END IF;

    DELETE FROM IT.PR_INF_FOGAPY
     WHERE FECHA = V_FEC_CORTE
       AND TIP_EJECUCION = V_TIP_EJECUCION;

    V_CAN_ELIMINADOS := SQL%ROWCOUNT;

    LP_INS_LOG(0, NULL,
        'DELETE. Tipo ' || V_TIP_EJECUCION
        || ', corte ' || TO_CHAR(V_FEC_CORTE, 'DD/MM/YYYY')
        || ', registros eliminados ' || V_CAN_ELIMINADOS);

    INSERT INTO IT.PR_INF_FOGAPY (
        FECHA,
        TIP_EJECUCION,
        NRO_DOCUMENTO,
        NRO_CUENTA,
        SAL_CAPITAL,
        FEC_SIG_VTO_CAPITAL,
        SIG_SAL_CAPITAL,
        CAN_CUO_PAGADAS,
        DIA_ATRASO,
        CAN_CUO_ATRASADAS,
        COD_PERSONA,
        COD_GARANTIA,
        NRO_GARANTIA,
        NRO_DOC_GARANTIA,
        MTO_CAPITAL
    )
WITH P AS (
        SELECT
            V_FEC_CORTE       AS FEC_CORTE,
            V_FEC_INI_PERIODO AS FEC_INI_PERIODO,
            V_FEC_PROX_CIERRE AS FEC_PROX_CIERRE,
            V_TIP_EJECUCION   AS TIP_EJECUCION
        FROM DUAL
    ),
    GAR_FOGAPY AS (
        SELECT TO_NUMBER(TOKEN) AS COD_GARANTIA
          FROM (
              SELECT TRIM(REGEXP_SUBSTR(PDG.VAL_PARAMETRO, '[^,]+', 1, LEVEL)) AS TOKEN
                FROM IT.GE_PAR_DINAMICOS PDG
               WHERE PDG.PARAMETRO = 'PRE_GAR_INF_FOGAPY'
              CONNECT BY REGEXP_SUBSTR(PDG.VAL_PARAMETRO, '[^,]+', 1, LEVEL) IS NOT NULL
                  AND PRIOR SYS_GUID() IS NOT NULL
                  AND PRIOR PDG.ROWID = PDG.ROWID
          )
         WHERE REGEXP_LIKE(TOKEN, '^[0-9]+$')
    ),
    MAD_FOGAPY AS (
        SELECT COD_MODALIDAD, COD_SUB_MODALIDAD
          FROM IT.GE_PAR_DINAMICOS
         WHERE PARAMETRO = 'PRE_MAD_INF_FOGAPY'
           AND UPPER(TRIM(NVL(VAL_PARAMETRO, 'S'))) = 'S'
    ),
    CTA_GAR_FOGAPY AS (
        SELECT DISTINCT PG.NRO_CUENTA
          FROM IT.PR_CTA_GARANTIAS PG
          JOIN GAR_FOGAPY GF ON GF.COD_GARANTIA = PG.COD_GARANTIA
    ),
    CTAS_CANDIDATAS AS (
        SELECT
            PCP.NRO_CUENTA,
            PCP.ESTADO,
            PCP.DIA_ATRASO,
            PCP.COD_MODALIDAD,
            PCP.COD_SUB_MODALIDAD,
            PCP.MTO_CAPITAL,
            PCP.SAL_CAPITAL                              AS HIS_SAL_CAPITAL,
            UPPER(TRIM(NVL(AD_FLAG.VAL_PARAMETRO, 'X'))) AS FLAG_VAL,
            AD_EQ.VAL_PARAMETRO                          AS CTA_EQUIVALENTE
          FROM IT.PR_CTA_PRESTAMOS_HIS PCP
          LEFT JOIN IT.GE_CTA_DAT_ADICIONALES AD_FLAG
            ON AD_FLAG.NRO_CUENTA = PCP.NRO_CUENTA
           AND AD_FLAG.PARAMETRO  = 'PRE_INF_CTA_FOGAPY'
          LEFT JOIN IT.GE_CTA_DAT_ADICIONALES AD_EQ
            ON AD_EQ.NRO_CUENTA = PCP.NRO_CUENTA
           AND AD_EQ.PARAMETRO  = 'PRE_CTA_EQU_FOGAPY'
          CROSS JOIN P
         WHERE PCP.FECHA >= V_FEC_CORTE
           AND PCP.FECHA <  V_FEC_CORTE + 1
           AND (PCP.ESTADO <> 'N'
                OR (PCP.ESTADO = 'N'
                    AND PCP.FEC_CANCELACION BETWEEN P.FEC_INI_PERIODO AND P.FEC_CORTE))
    ),
    CTAS_FOGAPY AS (
        SELECT CC.NRO_CUENTA, CC.ESTADO, CC.DIA_ATRASO, CC.CTA_EQUIVALENTE, CC.MTO_CAPITAL, CC.HIS_SAL_CAPITAL
          FROM CTAS_CANDIDATAS CC
          LEFT JOIN MAD_FOGAPY MF
            ON MF.COD_MODALIDAD = CC.COD_MODALIDAD
           AND (MF.COD_SUB_MODALIDAD IS NULL OR MF.COD_SUB_MODALIDAD = CC.COD_SUB_MODALIDAD)
          LEFT JOIN CTA_GAR_FOGAPY CG
            ON CG.NRO_CUENTA = CC.NRO_CUENTA
         WHERE CC.FLAG_VAL = 'S'
            OR (
                CC.FLAG_VAL <> 'N'
                AND (
                    NULLIF(TRIM(CC.CTA_EQUIVALENTE), '') IS NOT NULL
                    OR MF.COD_MODALIDAD IS NOT NULL
                    OR CG.NRO_CUENTA IS NOT NULL
                )
            )
    ),
    CUOTAS_SALDO AS (
        SELECT
            PC.NRO_CUENTA,
            SUM(
                DECODE(
                    PC.ESTADO,
                    'N',
                        CASE
                            WHEN PC.FEC_ULT_PAGO > P.FEC_CORTE THEN PC.MTO_CAPITAL
                            ELSE 0
                        END,
                        CASE
                            WHEN PC.SAL_CAPITAL <= PC.MTO_CAPITAL AND PC.SAL_CAPITAL <> 0 THEN PC.SAL_CAPITAL
                            ELSE PC.MTO_CAPITAL
                        END
                )
            ) AS SALDO_CAPITAL,
            MIN(
                CASE
                    WHEN PC.FEC_VENCIMIENTO > P.FEC_CORTE
                     AND LAST_DAY(PC.FEC_VENCIMIENTO) <> LAST_DAY(P.FEC_CORTE) THEN TRUNC(PC.FEC_VENCIMIENTO)
                    ELSE P.FEC_PROX_CIERRE
                END
            ) AS FEC_VTO_CAPITAL
          FROM IT.PR_CUOTAS PC
          JOIN CTAS_FOGAPY CF0 ON CF0.NRO_CUENTA = PC.NRO_CUENTA
          CROSS JOIN P
         WHERE NVL(PC.MTO_CAPITAL, 0) <> 0
         GROUP BY PC.NRO_CUENTA
    ),
    CUOTAS_SGTE AS (
            SELECT
                NRO_CUENTA,
                SUM(CAPITAL_CUOTA) AS CAPITAL_CUOTA_PROX
            FROM (
                SELECT
                    PC2.NRO_CUENTA,
                    PC2.FEC_VENCIMIENTO,
                    CASE
                        WHEN PC2.ESTADO = 'N' THEN PC2.MTO_CAPITAL
                        WHEN PC2.SAL_CAPITAL > 0 AND PC2.SAL_CAPITAL < PC2.MTO_CAPITAL THEN PC2.SAL_CAPITAL
                        ELSE PC2.MTO_CAPITAL
                    END AS CAPITAL_CUOTA,
                    CS.FEC_VTO_CAPITAL
                FROM IT.PR_CUOTAS PC2
                JOIN CUOTAS_SALDO CS ON CS.NRO_CUENTA = PC2.NRO_CUENTA
                WHERE (PC2.ESTADO <> 'N'
                       OR PC2.FEC_ULT_PAGO > V_FEC_CORTE)
                  AND NVL(PC2.MTO_CAPITAL, 0) > 0
            )
            WHERE FEC_VENCIMIENTO <= FEC_VTO_CAPITAL
              AND (FEC_VENCIMIENTO < FEC_VTO_CAPITAL OR FEC_VTO_CAPITAL <> LAST_DAY(FEC_VTO_CAPITAL))
            GROUP BY NRO_CUENTA
    ),
    CUOTAS_PAG AS (
        SELECT
            PC3.NRO_CUENTA,
            COUNT(PC3.NRO_CUOTA) AS CUOTAS_PAGADAS
          FROM IT.PR_CUOTAS PC3
          JOIN CTAS_FOGAPY CF0 ON CF0.NRO_CUENTA = PC3.NRO_CUENTA
          CROSS JOIN P
         WHERE PC3.ESTADO       = 'N'
           AND PC3.FEC_ULT_PAGO <= P.FEC_CORTE
           AND NVL(PC3.MTO_CAPITAL, 0) > 0
         GROUP BY PC3.NRO_CUENTA
    ),
    CUOTAS_MOR AS (
        SELECT
            PC4.NRO_CUENTA,
            SUM(
                DECODE(
                    PC4.ESTADO,
                    'V', 1,
                    'G', 1,
                    'M', 1,
                    CASE
                        WHEN PC4.ESTADO = 'C' AND PC4.FEC_VENCIMIENTO <= P.FEC_CORTE THEN 1
                        WHEN PC4.ESTADO = 'N' AND PC4.FEC_ULT_PAGO > P.FEC_CORTE THEN 1
                        ELSE 0
                    END
                )
            ) AS CUOTAS_MORA_BASE
          FROM IT.PR_CUOTAS PC4
          JOIN CTAS_FOGAPY CF0 ON CF0.NRO_CUENTA = PC4.NRO_CUENTA AND NVL(CF0.DIA_ATRASO, 0) > 0
          CROSS JOIN P
         WHERE NVL(PC4.MTO_CAPITAL, 0) > 0
           AND PC4.FEC_VENCIMIENTO <= P.FEC_CORTE
         GROUP BY PC4.NRO_CUENTA
    ),
    CERT_AGR AS (
        SELECT
            PCG.NRO_CUENTA,
            MAX(PGD.NRO_DOCUMENTO) AS NRO_DOC_GARANTIA,
            MAX(PGD.NRO_GARANTIA)  AS NRO_GARANTIA,
            MAX(PCG.COD_GARANTIA) KEEP (DENSE_RANK LAST ORDER BY PGD.NRO_DOCUMENTO) AS COD_GARANTIA
          FROM IT.PR_CTA_GARANTIAS PCG
          JOIN GAR_FOGAPY GF
            ON GF.COD_GARANTIA = PCG.COD_GARANTIA
          JOIN IT.PR_GAR_DOCUMENTOS PGD
            ON PGD.NRO_GARANTIA = PCG.NRO_GARANTIA
           AND PGD.TIP_DOCUMENTO = 'CT'
          JOIN CTAS_FOGAPY CF0 ON CF0.NRO_CUENTA = PCG.NRO_CUENTA
         GROUP BY PCG.NRO_CUENTA
    )
    SELECT
        P.FEC_CORTE                                                           AS FECHA,
        P.TIP_EJECUCION                                                       AS TIPO_EJECUCION,
        PBP.NRO_DOCUMENTO                                                     AS RUC_CLIENTE,
        NVL(NULLIF(TRIM(CF.CTA_EQUIVALENTE), ''), CF.NRO_CUENTA)              AS NRO_CUENTA,
        CASE WHEN CF.ESTADO <> 'N' THEN NVL(CF.HIS_SAL_CAPITAL, 0)
             ELSE NVL(CS.SALDO_CAPITAL, 0)
        END                                                                   AS SALDO_CAPITAL,
        NVL(CS.FEC_VTO_CAPITAL, P.FEC_PROX_CIERRE)                            AS FEC_VTO_CAPITAL,
        GREATEST(NVL(CS.SALDO_CAPITAL, 0) - NVL(CX.CAPITAL_CUOTA_PROX, 0), 0) AS SIGUIENTE_SALDO,
        NVL(CP.CUOTAS_PAGADAS, 0)                                             AS CUOTAS_PAGADAS,
        CASE
            WHEN NVL(CF.DIA_ATRASO, 0) = 0        THEN 0
            WHEN NVL(CM.CUOTAS_MORA_BASE, 0) = 0  THEN 0
            ELSE NVL(CF.DIA_ATRASO, 0)
        END                                                                   AS DIAS_MORA,
        CASE
            WHEN NVL(CF.DIA_ATRASO, 0) = 0 THEN 0
            ELSE NVL(CM.CUOTAS_MORA_BASE, 0)
        END                                                                   AS CUOTAS_MORA,
        GCC.COD_PERSONA                                                       AS COD_PERSONA,
        CA.COD_GARANTIA                                                       AS COD_GARANTIA,
        CA.NRO_GARANTIA                                                       AS NRO_GARANTIA,
        CA.NRO_DOC_GARANTIA                                                   AS NRO_DOC_GARANTIA,
        CF.MTO_CAPITAL                                                        AS MTO_CAPITAL
    FROM CTAS_FOGAPY CF
    LEFT JOIN CUOTAS_SALDO CS ON CS.NRO_CUENTA = CF.NRO_CUENTA
    LEFT JOIN CUOTAS_SGTE  CX ON CX.NRO_CUENTA = CF.NRO_CUENTA
    LEFT JOIN CUOTAS_PAG   CP ON CP.NRO_CUENTA = CF.NRO_CUENTA
    LEFT JOIN CUOTAS_MOR   CM ON CM.NRO_CUENTA = CF.NRO_CUENTA
    LEFT JOIN CERT_AGR     CA ON CA.NRO_CUENTA = CF.NRO_CUENTA
    JOIN IT.GE_CTA_CLIENTES GCC
      ON GCC.NRO_CUENTA = CF.NRO_CUENTA
     AND UPPER(TRIM(GCC.RELACION)) = 'P'
    JOIN IT.BA_PERSONAS PBP
      ON PBP.COD_PERSONA = GCC.COD_PERSONA
    CROSS JOIN P;

    V_CAN_REGISTROS := SQL%ROWCOUNT;

    IF V_CAN_REGISTROS = 0 THEN
        RAISE_APPLICATION_ERROR(-20034, 'No se generaron registros FOGAPY al ' || TO_CHAR(V_FEC_CORTE, 'DD/MM/YYYY') || ' tipo ' || V_TIP_EJECUCION || '.');
    END IF;

    LP_INS_LOG(0, NULL,
        'OK. Tipo ' || V_TIP_EJECUCION
        || ', calendario ' || TO_CHAR(V_FEC_ACTUAL, 'DD/MM/YYYY')
        || ', corte ' || TO_CHAR(V_FEC_CORTE, 'DD/MM/YYYY')
        || ', inicio ' || TO_CHAR(V_FEC_INI_PERIODO, 'DD/MM/YYYY')
        || ', prox. cierre ' || TO_CHAR(V_FEC_PROX_CIERRE, 'DD/MM/YYYY')
        || ', registros eliminados ' || V_CAN_ELIMINADOS
        || ', registros insertados ' || V_CAN_REGISTROS);

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        V_NRO_ERROR := SQLCODE;
        V_MEN_ERROR := SUBSTR(SQLERRM, 1, 500);
        ROLLBACK;
        V_CAN_REGISTROS := 0;
        LP_INS_LOG(V_NRO_ERROR, V_MEN_ERROR,
            'ERROR. Tipo ' || V_TIP_EJECUCION
            || ', calendario ' || TO_CHAR(V_FEC_ACTUAL, 'DD/MM/YYYY')
            || ', corte ' || TO_CHAR(V_FEC_CORTE, 'DD/MM/YYYY')
            || '. ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;
END PRP_GEN_DAT_INF_FOGAPY;
/
