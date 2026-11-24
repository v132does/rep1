CREATE OR REPLACE PROCEDURE IT.PRP_GEN_ARC_INF_FOGAPY ( 
    P_TIP_EJECUCION IN VARCHAR2,
    P_FEC_CORTE     IN DATE DEFAULT NULL
) IS
    V_TIP_EJECUCION     VARCHAR2(1);
    V_FEC_ACTUAL        DATE;
    V_FEC_CORTE         DATE;
    V_FEC_ULT_EJECUCION DATE; 
    V_NOM_ARCHIVO       VARCHAR2(100);
    V_SQL               VARCHAR2(32767);
    V_PATH              VARCHAR2(200);
    V_RESPUESTA         VARCHAR2(4000);
    V_HINI_FTP          GE_RA_LOG_FTP.HOR_INICIO%TYPE;
    V_HFIN_FTP          GE_RA_LOG_FTP.HOR_FIN%TYPE;
    V_DIR_DESTINO       GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE;
    V_FEC_INI_PROCESO   DATE := SYSDATE;
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
            NVL(V_FEC_ACTUAL, TRUNC(SYSDATE)), 'PRP_GEN_ARC_INF_FOGAPY', NVL(TO_CHAR(V_COD_PROCESO), 'FOGAPY'),
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

    V_FEC_ACTUAL := TRUNC(pag_cal.FU_OBT_FEC_ACTUAL(6));

    IF P_FEC_CORTE IS NOT NULL THEN
        V_FEC_CORTE := TRUNC(P_FEC_CORTE);
    ELSE -- tomar solo si es ejecucion del dia
        SELECT MAX(FEC_INSERCION),
               MAX(FECHA) KEEP (DENSE_RANK LAST ORDER BY FEC_INSERCION)
          INTO V_FEC_ULT_EJECUCION, V_FEC_CORTE
          FROM IT.PR_INF_FOGAPY
         WHERE TIP_EJECUCION = V_TIP_EJECUCION;

        IF V_FEC_ULT_EJECUCION IS NULL OR TRUNC(V_FEC_ULT_EJECUCION) <> TRUNC(SYSDATE) THEN
            RAISE_APPLICATION_ERROR(-20030, 'La ultima ejecucion de PRP_GEN_DAT_INF_FOGAPY tipo ' || V_TIP_EJECUCION
                || ' (' || NVL(TO_CHAR(V_FEC_ULT_EJECUCION, 'DD/MM/YYYY HH24:MI:SS'), 'sin datos')
                || ') no corresponde a la fecha actual ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY') || '.');
        END IF;
    END IF;

    SELECT COUNT(*)
      INTO V_CAN_REGISTROS
      FROM IT.PR_INF_FOGAPY
     WHERE FECHA = V_FEC_CORTE
       AND TIP_EJECUCION = V_TIP_EJECUCION;

    IF V_CAN_REGISTROS = 0 THEN
        RAISE_APPLICATION_ERROR(-20037, 'No existen datos en IT.PR_INF_FOGAPY tipo ' || V_TIP_EJECUCION
            || ' al ' || TO_CHAR(V_FEC_CORTE, 'DD/MM/YYYY') || '.');
    END IF;

    V_NOM_ARCHIVO := 'InformeFogapy_' || TO_CHAR(V_FEC_CORTE, 'YYYYMMDD') || '_' || TO_CHAR(SYSDATE, 'HH24MISS') || '.xlsx';
    V_PATH        := FUG_OBT_PARDINAMICO('DIR_REP_FTP');

    V_SQL :=
        'SELECT ' ||
               'NVL(NRO_DOCUMENTO, '''') AS "beneficiario (RUC)", ' ||
               'NVL(NRO_CUENTA, '''') AS "operacion_garantizada", ' ||
               'NVL(NRO_DOC_GARANTIA, '''') AS "numero_garantia", ' ||
               'NVL(SAL_CAPITAL, 0) AS "saldo", ' ||
               'TO_CHAR(FEC_SIG_VTO_CAPITAL, ''DD/MM/YYYY'') AS "fecha_proximo_vencimiento_capital (dd/mm/aaaa)", ' ||
               'NVL(SIG_SAL_CAPITAL, 0) AS "sgte_saldo", ' ||
               'NVL(CAN_CUO_PAGADAS, 0) AS "numero_cuotas_pagadas_capital", ' ||
               'NVL(DIA_ATRASO, 0) AS "numero_dias_mora_capital", ' ||
               'NVL(CAN_CUO_ATRASADAS, 0) AS "numero_cuotas_mora_capital" ' ||
        'FROM IT.PR_INF_FOGAPY ' ||
        'WHERE FECHA = TO_DATE(''' || TO_CHAR(V_FEC_CORTE, 'DD/MM/YYYY') || ''', ''DD/MM/YYYY'') ' ||
          'AND TIP_EJECUCION = ''' || V_TIP_EJECUCION || ''' ' ||
        'ORDER BY NRO_CUENTA';

    AS_XLSX.CLEAR_WORKBOOK;
    AS_XLSX.NEW_SHEET('FOGAPY');
    AS_XLSX.QUERY2SHEET(
        P_SQL            => V_SQL,
        P_COLUMN_HEADERS => TRUE,
        P_DIRECTORY      => V_PATH,
        P_FILENAME       => V_NOM_ARCHIVO,
        P_SHEET          => 1
    );

    V_DIR_DESTINO := FUG_OBT_PARDINAMICO('DIR_SVR_REP_ARC_TXT');
    V_HINI_FTP    := TO_CHAR(SYSDATE, 'HH24:MI:SS');

    V_RESPUESTA   := PA_FILE_FTP.FU_PUT_BINARY(
                         PAG_EVO.G_IP, PAG_EVO.G_PORT, PAG_EVO.G_USER,
                         PAG_EVO.G_PASS, PAG_EVO.G_REPOSITORY,
                         V_NOM_ARCHIVO, V_DIR_DESTINO || V_NOM_ARCHIVO
                     );

    V_HFIN_FTP    := TO_CHAR(SYSDATE, 'HH24:MI:SS');

    IF NVL(V_RESPUESTA, 'X') != 'OK' THEN
        INSERT INTO GE_RA_LOG_FTP (FEC_ENVIO, NOM_ARCHIVO, DET_ERROR, HOR_INICIO, HOR_FIN)
        VALUES (SYSDATE, V_NOM_ARCHIVO, V_RESPUESTA, V_HINI_FTP, V_HFIN_FTP);
        COMMIT;
        RAISE_APPLICATION_ERROR(-20035, 'Error en envio FTP del archivo ' || V_NOM_ARCHIVO || ': ' || SUBSTR(V_RESPUESTA, 1, 300));
    END IF;

    LP_INS_LOG(0, NULL,
        'OK. Tipo ' || V_TIP_EJECUCION
        || ', calendario ' || TO_CHAR(V_FEC_ACTUAL, 'DD/MM/YYYY')
        || ', corte ' || TO_CHAR(V_FEC_CORTE, 'DD/MM/YYYY')
        || ', archivo ' || V_NOM_ARCHIVO
        || ', registros ' || V_CAN_REGISTROS);

EXCEPTION
    WHEN OTHERS THEN
        V_NRO_ERROR := SQLCODE;
        V_MEN_ERROR := SUBSTR(SQLERRM, 1, 500);
        LP_INS_LOG(V_NRO_ERROR, V_MEN_ERROR,
            'ERROR. Tipo ' || V_TIP_EJECUCION
            || ', calendario ' || TO_CHAR(V_FEC_ACTUAL, 'DD/MM/YYYY')
            || ', corte ' || TO_CHAR(V_FEC_CORTE, 'DD/MM/YYYY')
            || ', archivo ' || V_NOM_ARCHIVO
            || '. ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        IF V_NRO_ERROR <= -20000 THEN
            RAISE;
        END IF;
        RAISE_APPLICATION_ERROR(-20036, 'Error en PRP_GEN_ARC_INF_FOGAPY: ' || V_MEN_ERROR);
END PRP_GEN_ARC_INF_FOGAPY;
/
