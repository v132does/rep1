create or replace PACKAGE BODY                                                                IT.PAG_TAS IS

  -------------------------------------------------------------------------------
  -- FN_CALC_CODCTA: Retorna el codigo de cuenta contable segun los parametros
  --                 Loguea advertencias/errores en GE_LOG_TAS_INT_SEM_DET
  -------------------------------------------------------------------------------
  FUNCTION FN_CALC_CODCTA (
    I_ID_EJECUCION  IN NUMBER,
    I_COD_MODULO    IN VARCHAR2,
    I_COD_MODALIDAD IN VARCHAR2,
    I_NRO_CUENTA    IN VARCHAR2
  ) RETURN VARCHAR2 IS
    V_CODCTA     VARCHAR2(10);
    V_CODCTA_INV VARCHAR2(10);
    V_TMP        VARCHAR2(20);
    V_ORI_FONDO  VARCHAR2(10);
    V_MONEDA     VARCHAR2(10);
    V_INFO_ADIC  VARCHAR2(100);
  BEGIN
    V_INFO_ADIC := ' | MOD:' || NVL(I_COD_MODULO,'NULL')
                          || ', MODAL:' || NVL(I_COD_MODALIDAD,'NULL');

    -------------------------------------------------------------------
    -- 0) PRIORIDAD: CODCTA DESDE INVENTARIO / HISTÓRICO
    -------------------------------------------------------------------
    BEGIN
      -- Inventario vigente
      SELECT DECODE(
               SUBSTR(P.COD_RUBRO,6,3),
               '209', SUBSTR(P.COD_RUBRO,6,3)||'0'||SUBSTR(P.COD_RUBRO,9,2),
               '405', SUBSTR(P.COD_RUBRO,6,3)||'0'||SUBSTR(P.COD_RUBRO,9,2),
                      SUBSTR(P.COD_RUBRO,6,3)||'000'
             )
        INTO V_CODCTA_INV
        FROM CB_SAL_INVENTARIOS P
        JOIN CB_SAL_INVENTARIOS_DET B
          ON P.NRO_REFERENCIA = B.NRO_REFERENCIA
       WHERE B.NRO_CUENTA = I_NRO_CUENTA
         AND P.TIP_SALDO IN ('C','F')
         AND ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        BEGIN
          -- Histórico
          SELECT DECODE(
                   SUBSTR(C.COD_RUBRO,6,3),
                   '209', SUBSTR(C.COD_RUBRO,6,3)||'0'||SUBSTR(C.COD_RUBRO,9,2),
                   '405', SUBSTR(C.COD_RUBRO,6,3)||'0'||SUBSTR(C.COD_RUBRO,9,2),
                          SUBSTR(C.COD_RUBRO,6,3)||'000'
                 )
            INTO V_CODCTA_INV
            FROM CB_SAL_INVENTARIOS_DET_HIS D
            JOIN CB_SAL_INVENTARIOS_HIS       C
              ON D.NRO_REFERENCIA = C.NRO_REFERENCIA
             AND D.FECHA          = C.FECHA
           WHERE D.NRO_CUENTA = I_NRO_CUENTA
             AND C.TIP_SALDO IN ('C','F')
             AND C.COD_RUBRO IS NOT NULL
             AND D.FECHA = (
                   SELECT MAX(DD.FECHA)
                     FROM CB_SAL_INVENTARIOS_DET_HIS DD
                     JOIN CB_SAL_INVENTARIOS_HIS CC
                       ON DD.NRO_REFERENCIA = CC.NRO_REFERENCIA
                      AND DD.FECHA          = CC.FECHA
                    WHERE DD.NRO_CUENTA = I_NRO_CUENTA
                      AND CC.TIP_SALDO IN ('C','F')
                      AND CC.COD_RUBRO IS NOT NULL
                 ) AND ROWNUM = 1;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            -- No hay inventario ni histórico: lo dejamos NULL y seguimos con la lógica vieja
            V_CODCTA_INV := NULL;
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION,
              'ADVERTENCIA',
              I_NRO_CUENTA,
              'FN_CALC_CODCTA',
              'NO_DATA_FOUND en CB_SAL_INVENTARIOS / HIS.' || V_INFO_ADIC
            );
          WHEN OTHERS THEN
            V_CODCTA_INV := NULL;
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION,
              'ERROR',
              I_NRO_CUENTA,
              'FN_CALC_CODCTA',
              'Error inesperado en CB_SAL_INVENTARIOS_HIS: ' || SQLERRM || V_INFO_ADIC
            );
        END;
      WHEN OTHERS THEN
        V_CODCTA_INV := NULL;
        PRC_LOG_TAS_INT_SEM_DET(
          I_ID_EJECUCION,
          'ERROR',
          I_NRO_CUENTA,
          'FN_CALC_CODCTA',
          'Error inesperado en CB_SAL_INVENTARIOS: ' || SQLERRM || V_INFO_ADIC
        );
    END;

    IF TO_NUMBER(V_CODCTA_INV) != 0 THEN
      RETURN V_CODCTA_INV;
    END IF;

    -------------------------------------------------------------------
    -- 1) LÓGICA ORIGINAL (MODALIDAD / MÓDULO / ORIGEN DE FONDOS)
    --    Se usa sólo si inventario no devolvió CODCTA
    -------------------------------------------------------------------

    -- 1. CASOS FIJOS POR MODALIDAD
    IF I_COD_MODALIDAD = '31' THEN
      RETURN '138000';
    ELSIF I_COD_MODALIDAD = '34' THEN
      RETURN '214000';
    ELSIF I_COD_MODALIDAD = '38' THEN
      RETURN '152000';
    ELSIF I_COD_MODALIDAD = '41' THEN
      RETURN '189000';

    -- 2. TARJETAS
    ELSIF I_COD_MODULO = '5' THEN
      RETURN '205002';
    elsif fug_obt_pardinamico('MDD_MAD_EMI_CALLMONEY',
                              I_COD_MODULO,
                              I_COD_MODALIDAD,
                              null,
                              null,
                              null) = 'S' then
      V_CODCTA := '391000'; 
    elsif fug_obt_pardinamico('MDD_MAD_REC_CALLMONEY',
                              I_COD_MODULO,
                              I_COD_MODALIDAD,
                              null,
                              null,
                              null) = 'S' then
      V_CODCTA := '304000';
    -- 4. PReSTAMOS
    ELSIF I_COD_MODULO = '6' THEN
      BEGIN
        V_TMP     := FUG_OBT_MOD_SUP_RUBRO(I_COD_MODULO, I_NRO_CUENTA);
        V_CODCTA  := RPAD(SUBSTR(V_TMP, 1, 3), 6, '0');

        IF NVL(FUP_OBT_TIP_DESCUENTO(I_COD_MODALIDAD), 'X') IN ('F','C') THEN
          RETURN '405001';
        ELSIF FUP_OBT_TIP_DESCUENTO(I_COD_MODALIDAD) = 'D' THEN
          RETURN '351000';
        END IF;

        -- CASOS CON ORIGEN DE FONDOS AFD/BCP
        BEGIN
          SELECT COD_MONEDA, COD_ORI_FONDO
            INTO V_MONEDA, V_ORI_FONDO
            FROM PR_CTA_PRESTAMOS
           WHERE NRO_CUENTA = I_NRO_CUENTA;

          IF V_ORI_FONDO = FUG_OBT_PARDINAMICO('COD_ORI_FON_AFD', NULL, NULL, V_MONEDA, NULL, NULL) THEN
            RETURN '209004';
          ELSIF V_ORI_FONDO = FUG_OBT_PARDINAMICO('COD_ORI_FON_BCP', NULL, NULL, V_MONEDA, NULL, NULL) THEN
            RETURN '209002';
          END IF;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            BEGIN
              PRC_LOG_TAS_INT_SEM_DET(
                I_ID_EJECUCION,
                'ADVERTENCIA',
                I_NRO_CUENTA,
                'FN_CALC_CODCTA',
                'NO_DATA_FOUND en origen de fondos PR_CTA_PRESTAMOS.' || V_INFO_ADIC
              );
            EXCEPTION
              WHEN OTHERS THEN NULL;
            END;
          WHEN OTHERS THEN
            BEGIN
              PRC_LOG_TAS_INT_SEM_DET(
                I_ID_EJECUCION,
                'ERROR',
                I_NRO_CUENTA,
                'FN_CALC_CODCTA',
                'Error inesperado en origen de fondos PR_CTA_PRESTAMOS: ' || SQLERRM || V_INFO_ADIC
              );
            EXCEPTION
              WHEN OTHERS THEN NULL;
            END;
        END;
      EXCEPTION
        WHEN OTHERS THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION,
              'ERROR',
              I_NRO_CUENTA,
              'FN_CALC_CODCTA',
              'Error inesperado en bloque PReSTAMOS: ' || SQLERRM || V_INFO_ADIC
            );
          EXCEPTION
            WHEN OTHERS THEN NULL;
          END;
          V_CODCTA := NULL;
      END;
    END IF;

    RETURN V_CODCTA;
  END FN_CALC_CODCTA;
  -------------------------------------------------------------------------------
  -- FN_CALC_ACOD: Determina el codigo de area BCP (ACOD) para la cuenta y condiciones dadas
  --               Loguea advertencias/errores en GE_LOG_TAS_INT_SEM_DET
  -------------------------------------------------------------------------------
  FUNCTION FN_CALC_ACOD (
    I_ID_EJECUCION  IN NUMBER,
    I_CODCTA        IN VARCHAR2,
    I_PLAZO         IN NUMBER,
    I_COD_MODULO    IN VARCHAR2,
    I_COD_MODALIDAD IN VARCHAR2,
    I_NRO_CUENTA    IN VARCHAR2,
    I_COD_RUBRO     IN VARCHAR2,
    I_TIP_SALDO     IN VARCHAR2
  ) RETURN VARCHAR2 IS
    V_ACOD           VARCHAR2(5);
    V_COD_RUBRO      CB_SAL_INVENTARIOS.COD_RUBRO%TYPE;
    V_TIP_SALDO      CB_SAL_INVENTARIOS.TIP_SALDO%TYPE;
    V_DESCRIPCION    GE_EST_CUENTAS.DESCRIPCION%TYPE;
    V_PERIODO        NUMBER;
    V_INFO_ADIC      VARCHAR2(300);

    -- Variables heredadas de FUS_OBT_ARE_BCP_CTA
    V_TIP_DESTINO_ESP BA_COD_REFERENCIAS.VAL_MINIMO%TYPE;
    V_DIAS_R          NUMBER(8);
    R_PCPRE           PR_CTA_PRESTAMOS%ROWTYPE;
    R_PCMES           MD_CTA_DOCUMENTOS%ROWTYPE;
  BEGIN
    V_INFO_ADIC := ' | MOD:' || NVL(I_COD_MODULO,'NULL')
                   || ', MODAL:' || NVL(I_COD_MODALIDAD,'NULL')
                   || ', CODCTA:' || NVL(I_CODCTA,'NULL')
                   || ', PLAZO:' || NVL(TO_CHAR(I_PLAZO),'NULL');

    ---------------------------------------------------------------------------
    -- OBTENER RUBRO Y TIP_SALDO
    ---------------------------------------------------------------------------
    IF I_COD_RUBRO IS NULL AND I_TIP_SALDO IS NULL THEN
    BEGIN
      SELECT P.COD_RUBRO,
             P.TIP_SALDO,
             TRIM(D.DESCRIPCION)
        INTO V_COD_RUBRO,
             V_TIP_SALDO,
             V_DESCRIPCION
        FROM CB_SAL_INVENTARIOS P
        JOIN CB_SAL_INVENTARIOS_DET B
          ON P.NRO_REFERENCIA = B.NRO_REFERENCIA
        JOIN PR_CTA_PRESTAMOS C
          ON C.NRO_CUENTA = B.NRO_CUENTA
        JOIN GE_EST_CUENTAS D
          ON D.COD_MODULO    = C.COD_MODULO
         AND D.COD_MODALIDAD = C.COD_MODALIDAD
         AND D.ESTADO        = C.ESTADO
       WHERE B.NRO_CUENTA     = I_NRO_CUENTA
         AND P.TIP_SALDO      IN ('C','F')
         AND ROWNUM           = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        BEGIN
          SELECT C.COD_RUBRO,
                 C.TIP_SALDO
            INTO V_COD_RUBRO,
                 V_TIP_SALDO
            FROM CB_SAL_INVENTARIOS_DET_HIS D
            JOIN CB_SAL_INVENTARIOS_HIS       C
              ON D.NRO_REFERENCIA = C.NRO_REFERENCIA
             AND D.FECHA          = C.FECHA
           WHERE D.NRO_CUENTA     = I_NRO_CUENTA
             AND C.TIP_SALDO      IN ('C','F')
             AND C.COD_RUBRO      IS NOT NULL
             AND D.FECHA = (
               SELECT MAX(DD.FECHA)
                 FROM CB_SAL_INVENTARIOS_DET_HIS DD
                 JOIN CB_SAL_INVENTARIOS_HIS CC
                   ON DD.NRO_REFERENCIA = CC.NRO_REFERENCIA
                  AND DD.FECHA          = CC.FECHA
                WHERE DD.NRO_CUENTA = I_NRO_CUENTA
                  AND CC.TIP_SALDO IN ('C','F')
                  AND CC.COD_RUBRO IS NOT NULL
             ) AND ROWNUM           = 1;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            V_COD_RUBRO   := NULL;
            V_TIP_SALDO   := NULL;
            V_DESCRIPCION := NULL;
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION,
              'ADVERTENCIA',
              I_NRO_CUENTA,
              'FN_CALC_ACOD',
              'NO_DATA_FOUND en CB_SAL_INVENTARIOS_HIS.' || V_INFO_ADIC
            );
          WHEN OTHERS THEN
            V_COD_RUBRO   := NULL;
            V_TIP_SALDO   := NULL;
            V_DESCRIPCION := NULL;
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION,
              'ERROR',
              I_NRO_CUENTA,
              'FN_CALC_ACOD',
              'Error inesperado en CB_SAL_INVENTARIOS_HIS: ' || SQLERRM || V_INFO_ADIC
            );
        END;
      WHEN OTHERS THEN
        V_COD_RUBRO   := NULL;
        V_TIP_SALDO   := NULL;
        V_DESCRIPCION := NULL;
        PRC_LOG_TAS_INT_SEM_DET(
          I_ID_EJECUCION,
          'ERROR',
          I_NRO_CUENTA,
          'FN_CALC_ACOD',
          'Error inesperado en CB_SAL_INVENTARIOS: ' || SQLERRM || V_INFO_ADIC
        );
    END;


    ELSE
    V_COD_RUBRO := I_COD_RUBRO;
    V_TIP_SALDO := I_TIP_SALDO;
    END IF;
        V_DIAS_R := TO_NUMBER(SUBSTR(NVL(V_COD_RUBRO,'000000'),3,1));
    ---------------------------------------------------------------------------
    -- OBTENER TIP_DESTINO_ESP PARA PReSTAMOS
    ---------------------------------------------------------------------------
    IF I_COD_MODULO = '6' THEN
      BEGIN
        SELECT CD.TIP_DES_ESPECIFICO
          INTO V_TIP_DESTINO_ESP
          FROM PR_CTA_DESTINOS CD
         WHERE CD.NRO_CUENTA = I_NRO_CUENTA;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          BEGIN
            SELECT A.VAL_MINIMO
              INTO V_TIP_DESTINO_ESP
              FROM PR_CTA_PRESTAMOS P
              JOIN PR_RUB_ECONOMICOS R
                ON R.COD_RUB_ECONOMICO = P.COD_RUB_ECONOMICO
              JOIN BA_COD_REFERENCIAS A
                ON A.VAL_MINIMO = P.TIP_DESTINO
             WHERE A.DOMINIO    = 'TIP_DES_ESPECIFICO'
               AND P.NRO_CUENTA = I_NRO_CUENTA;
          EXCEPTION
            WHEN OTHERS THEN
              V_TIP_DESTINO_ESP := NULL;
          END;
        WHEN OTHERS THEN
          V_TIP_DESTINO_ESP := NULL;
      END;
    END IF;

    ---------------------------------------------------------------------------
    -- CASOS POR COD_MODALIDAD / CODCTA
    ---------------------------------------------------------------------------
    IF I_COD_MODALIDAD = '31' THEN
      V_ACOD := '2021';
    ELSIF I_COD_MODALIDAD = '33' THEN
      BEGIN
        SELECT FEC_VENCIMIENTO - FEC_APERTURA
          INTO V_PERIODO
          FROM AH_CTA_CERTIFICADOS
         WHERE NRO_CUENTA = I_NRO_CUENTA;
      EXCEPTION
        WHEN OTHERS THEN
          V_PERIODO := I_PLAZO;
      END;
      IF V_PERIODO <= 180 THEN
        V_ACOD := '2075';
      ELSIF V_PERIODO <= 365 THEN
        V_ACOD := '2076';
      ELSE
        V_ACOD := '2077';
      END IF;
    ELSIF I_COD_MODALIDAD = '38' THEN
      BEGIN
        SELECT FEC_VENCIMIENTO - FEC_APERTURA
          INTO V_PERIODO
          FROM AH_CTA_PLAZOS
         WHERE NRO_CUENTA = I_NRO_CUENTA;
      EXCEPTION
        WHEN OTHERS THEN
          V_PERIODO := I_PLAZO;
      END;
      IF V_PERIODO <= 90 THEN
        V_ACOD := '2034';
      ELSIF V_PERIODO <= 180 THEN
        V_ACOD := '2035';
      ELSIF V_PERIODO <= 365 THEN
        V_ACOD := '2036';
      ELSE
        V_ACOD := '2037';
      END IF;
    ELSIF I_CODCTA = '156000' THEN
      IF I_PLAZO <= 6 THEN
        V_ACOD := '2034';
      ELSIF I_PLAZO <= 29 THEN
        V_ACOD := '2035';
      ELSIF I_PLAZO <= 59 THEN
        V_ACOD := '2036';
      ELSE
        V_ACOD := '2037';
      END IF;
    ELSIF I_CODCTA = '116000' THEN
      IF I_PLAZO <= 29 THEN
        V_ACOD := '2075';
      ELSIF I_PLAZO <= 59 THEN
        V_ACOD := '2076';
      ELSE
        V_ACOD := '2077';
      END IF;
    ELSIF I_CODCTA = '152000' THEN
      IF I_PLAZO <= 29 THEN
        V_ACOD := '2075';
      ELSIF I_PLAZO <= 59 THEN
        V_ACOD := '2076';
      ELSE
        V_ACOD := '2077';
      END IF;
    ELSIF I_CODCTA = '209008' THEN
      IF I_PLAZO <= 365 THEN
        V_ACOD := '1146';
      ELSE
        V_ACOD := '1147';
      END IF;
    ELSIF I_CODCTA = '209004' THEN
      IF I_PLAZO <= 365 THEN
        V_ACOD := '1156';
      ELSE
        V_ACOD := '1157';
      END IF;
    ELSIF I_CODCTA = '153000' THEN
      V_ACOD := '1046';
    ELSIF I_CODCTA = '172000' THEN
      V_ACOD := '1166';
    ELSIF I_CODCTA = '160000' THEN
      V_ACOD := '1167';
    ELSIF I_CODCTA = '109000' THEN
      V_ACOD := '1080';
    ELSIF I_CODCTA = '107000' THEN
      V_ACOD := '1070';
    ELSIF I_CODCTA = '106000' THEN
      V_ACOD := '1060';
    ELSIF I_CODCTA = '102000' THEN
      V_ACOD := '1026';
    ELSIF I_CODCTA = '103000' THEN
      V_ACOD := '1027';
    ELSIF I_CODCTA = '101000' THEN
      V_ACOD := '1016';
    ELSIF I_CODCTA = '117000' THEN
      V_ACOD := '1176';
    ELSIF I_CODCTA = '391000' THEN
      V_ACOD := '1046';
    END IF;

    ---------------------------------------------------------------------------
    -- CASOS POR MoDULO
    ---------------------------------------------------------------------------
    IF I_COD_MODULO = '3' THEN
      -- Ahorros
      IF I_COD_MODALIDAD = '33'
         AND SUBSTR(V_COD_RUBRO,1,2) IN ('21','22')
      THEN
        V_PERIODO := NVL(V_PERIODO,I_PLAZO);
        IF SUBSTR(V_COD_RUBRO,6,3) IN ('104','152') THEN
          IF V_PERIODO <= 90 THEN
            V_ACOD := '2034';
          ELSIF V_PERIODO <= 180 THEN
            V_ACOD := '2035';
          ELSIF V_PERIODO <= 365 THEN
            V_ACOD := '2036';
          ELSE
            V_ACOD := '2037';
          END IF;
        ELSIF SUBSTR(V_COD_RUBRO,6,3) IN ('156','298','306') THEN
          IF V_PERIODO <= 180 THEN
            V_ACOD := '2075';
          ELSIF V_PERIODO <= 365 THEN
            V_ACOD := '2076';
          ELSE
            V_ACOD := '2077';
          END IF;
        END IF;
      END IF;

    ELSIF I_COD_MODULO = '4' THEN
      V_ACOD := '1080';

    ELSIF I_COD_MODULO = '6' THEN
      PAP_PRE.PR_OBT_DAT_PRESTAMO(I_NRO_CUENTA, R_PCPRE);
      V_PERIODO := R_PCPRE.FEC_VENCIMIENTO - R_PCPRE.FEC_INICIO;

      -- BANCA CORPORATIVA
      IF V_TIP_DESTINO_ESP IN (1,2,5)
         AND SUBSTR(V_COD_RUBRO,1,2) = '14'
         AND SUBSTR(V_COD_RUBRO,6,3) IN ('169','173','351','405','443','453','449')
      THEN
        IF V_PERIODO <= 365 AND V_DIAS_R BETWEEN 2 AND 6 THEN
          V_ACOD := '1016';
        ELSIF V_DIAS_R >= 7 THEN
          V_ACOD := '1017';
        END IF;
      END IF;

      -- VIVIENDA AFD
--      IF SUBSTR(V_COD_RUBRO,6,3) = '209'
--         AND R_PCPRE.COD_MODALIDAD IN (628,629,630,615,618,617,209,668)
--      THEN
--        IF V_PERIODO <= 365 THEN
--          V_ACOD := '1146';
--        ELSE
--          V_ACOD := '1147';
--        END IF;
--      ELSIF SUBSTR(V_COD_RUBRO,6,3) = '209'
--            AND R_PCPRE.COD_MODALIDAD = 631
--      THEN
--        IF V_PERIODO <= 365 THEN
--          V_ACOD := '1156';
--        ELSE
--          V_ACOD := '1157';
--        END IF;
--      END IF;

      -- CONSUMO
      IF V_TIP_DESTINO_ESP IN (3,6,8)
         AND SUBSTR(V_COD_RUBRO,1,2) = '14'
         AND SUBSTR(V_COD_RUBRO,6,3) IN ('169','173','443','453','449','302')
      THEN
        IF V_PERIODO <= 365 AND V_DIAS_R BETWEEN 2 AND 6 THEN
          V_ACOD := '1026';
        ELSIF V_DIAS_R >= 7 THEN
          V_ACOD := '1027';
        END IF;
      END IF;

      IF V_TIP_DESTINO_ESP = 4 THEN
        IF SUBSTR(V_COD_RUBRO,6,3) IN ('169','173','443','453','449')
           AND UPPER(R_PCPRE.DESCRIPCION) NOT LIKE '%CONSUMO%'
        THEN
          IF V_PERIODO <= 365 AND V_DIAS_R BETWEEN 2 AND 6 THEN
            V_ACOD := '1036';
          ELSIF SUBSTR(V_COD_RUBRO,3,1) IN ('7','8') THEN
            V_ACOD := '1037';
          END IF;
        END IF;
      END IF;

      -- PReSTAMOS PERSONALES
      IF V_TIP_DESTINO_ESP = 3
         AND V_TIP_SALDO = 'C'
         AND SUBSTR(V_COD_RUBRO,6,3) IN ('169','173','443','453','449')
      THEN
        IF V_PERIODO <= 90 AND V_DIAS_R BETWEEN 2 AND 4 THEN
          V_ACOD := '1166';
        ELSIF V_PERIODO > 90 AND V_PERIODO <= 180 AND V_DIAS_R = 5 THEN
          V_ACOD := '1167';
        END IF;
      END IF;

      -- COMPRAS CARTERA
      --IF FUG_OBT_PARDINAMICO('SIB_MAD_COM_CARTERA',
      --                       R_PCPRE.COD_MODULO,
      --                       R_PCPRE.COD_MODALIDAD) = 'S'
      --   AND
      IF SUBSTR(V_COD_RUBRO,6,3) = '433'
      THEN
        IF V_PERIODO <= 365 AND V_DIAS_R BETWEEN 2 AND 6 THEN
          V_ACOD := '1176';
        ELSIF V_DIAS_R >= 7 THEN
          V_ACOD := '1177';
        END IF;
      END IF;

      -- COLOCACIONES PLAZA LOCAL
      IF SUBSTR(V_COD_RUBRO,1,2) = '13'
         AND SUBSTR(V_COD_RUBRO,6,3) = '131'
      THEN
        IF V_PERIODO <= 365 AND V_DIAS_R <= 6 THEN
          V_ACOD := '1126';
        ELSE
          V_ACOD := '1127';
        END IF;
      END IF;

      -- RUBROS ESPECIALES
      IF SUBSTR(V_COD_RUBRO,6,3) = '100'
         AND V_DIAS_R BETWEEN 1 AND 8
      THEN
        V_ACOD := '2170';
      END IF;
      IF SUBSTR(V_COD_RUBRO,6,3) = '100'
         AND SUBSTR(V_COD_RUBRO,9,2) = '02'
      THEN
        V_ACOD := '2160';
      END IF;

    ELSIF I_COD_MODULO in (5, 15) THEN
      IF SUBSTR(V_COD_RUBRO,6,3) = '205' THEN
        V_ACOD := '1066';
      END IF;

    ELSIF I_COD_MODULO = '10' THEN
      PAM_DOC.PR_OBT_DATOS(I_NRO_CUENTA, R_PCMES);
      V_PERIODO := R_PCMES.FEC_VENCIMIENTO - R_PCMES.FEC_INICIO;

      -- BONOS DEL TESORO
      IF SUBSTR(V_COD_RUBRO,1,2) = '12'
         AND SUBSTR(V_COD_RUBRO,6,3) = '123'
      THEN
        IF V_PERIODO <= 365 AND V_DIAS_R <= 6 THEN
          V_ACOD := '1106';
        ELSE
          V_ACOD := '1107';
        END IF;
      END IF;

      -- PReSTAMOS RECIBIDOS BCOS LOCALES
      IF SUBSTR(V_COD_RUBRO,1,2) = '21'
         AND SUBSTR(V_COD_RUBRO,6,3) = '390'
      THEN
        V_ACOD := '2150';
      END IF;

      -- COLOCACIONES PLAZA LOCAL
      IF SUBSTR(V_COD_RUBRO,1,2) = '13'
         AND SUBSTR(V_COD_RUBRO,6,3) = '131'
      THEN
        IF V_PERIODO <= 365 AND V_DIAS_R <= 6 THEN
          V_ACOD := '1126';
        ELSE
          V_ACOD := '1127';
        END IF;
      END IF;

      -- BONOS PRIVADOS
      IF R_PCMES.COD_MODALIDAD = 124 OR
         SUBSTR(V_COD_RUBRO,6,3) IN ('210','214','216','218','222','266') THEN
        IF V_PERIODO <= 90 THEN
          V_ACOD := '2104';
        ELSIF V_PERIODO <= 180 THEN
          V_ACOD := '2105';
        ELSIF V_PERIODO <= 365 THEN
          V_ACOD := '2106';
        ELSE
          V_ACOD := '2107';
        END IF;
      END IF;
    END IF;

    ---------------------------------------------------------------------------
    -- FALLBACKS
    ---------------------------------------------------------------------------
    IF V_ACOD IS NULL THEN
        IF V_TIP_DESTINO_ESP = 3 THEN
            IF V_PERIODO <= 90 THEN
                V_ACOD := '1166';
            ELSIF V_PERIODO > 90 AND V_PERIODO <= 180 THEN
                V_ACOD := '1167';
            ELSE
                IF V_PERIODO <= 365 THEN
                    V_ACOD := '1026';
                ELSE
                    V_ACOD := '1027';
                END IF;
            END IF;
        ELSE
            IF I_PLAZO <= 365 THEN
                V_ACOD := '1016';
            ELSE
                V_ACOD := '1017';
            END IF;
        END IF;
    END IF;

    ---------------------------------------------------------------------------
    -- ASIGNACIoN ACOD POR COD_CTA + RANGO DE PLAZO + TIP_DESTINO_ESP
    ---------------------------------------------------------------------------
    IF I_CODCTA = '209001' THEN
      IF I_PLAZO BETWEEN 1 AND 365 THEN
        V_ACOD := '1056';
      ELSIF I_PLAZO >= 366 THEN
        V_ACOD := '1057';
      END IF;

    ELSIF I_CODCTA = '209002' THEN
      IF I_PLAZO BETWEEN 1 AND 365 THEN
        V_ACOD := '1056';
      ELSIF I_PLAZO >= 366 THEN
        V_ACOD := '1057';
      END IF;

    ELSIF I_CODCTA = '209004' THEN
      IF V_TIP_DESTINO_ESP = 2 THEN
        -- AFD OTROS
        IF I_PLAZO BETWEEN 1 AND 365 THEN
          V_ACOD := '1156';
        ELSIF I_PLAZO >= 366 THEN
          V_ACOD := '1157';
        END IF;
      ELSIF V_TIP_DESTINO_ESP = 4 THEN
        -- VIVIENDA AFD
        IF I_PLAZO BETWEEN 1 AND 365 THEN
          V_ACOD := '1146';
        ELSIF I_PLAZO >= 366 THEN
          V_ACOD := '1147';
        END IF;
      END IF;

    ELSIF I_CODCTA = '209008' THEN
      IF I_PLAZO BETWEEN 1 AND 365 THEN
        V_ACOD := '1146';
      ELSIF I_PLAZO >= 366 THEN
        V_ACOD := '1147';
      END IF;
    END IF;


    IF I_CODCTA IN ('210000',  -- OBLIGACIONES / DEBENTURES NO REAJUSTABLES
                    '214000',  -- PAGARES EMITIDOS
                    '216000',  -- LETRAS EMITIDAS
                    '266001',  -- OBLIG. PAGO SUBORDINADO NO REAJUSTABLES
                    '266000',
                    '222000',  -- BONOS CALLABLE
                    '218001'   -- BONOS EMITIDOS Y EN CIRCULACIÓN NO REAJ
                   ) THEN

      IF I_PLAZO <= 90 THEN
        V_ACOD := '2104';
      ELSIF I_PLAZO <= 180 THEN
        V_ACOD := '2105';
      ELSIF I_PLAZO <= 365 THEN
        V_ACOD := '2106';
      ELSE
        V_ACOD := '2107';
      END IF;
    END IF;
    ---------------------------------------------------------------------------
    -- ASIGNACIoN FIJA DE ACOD SEGuN COD_CTA (PRIORIDAD FINAL)
    ---------------------------------------------------------------------------
    CASE
      WHEN I_CODCTA = '100002' THEN V_ACOD := '2160';
      WHEN I_CODCTA = '100004' THEN V_ACOD := '2170';
      WHEN I_CODCTA = '100006' THEN V_ACOD := '2170';
      WHEN I_CODCTA = '100008' THEN V_ACOD := '2170';
      WHEN I_CODCTA = '100010' THEN V_ACOD := '2170';
      WHEN I_CODCTA = '100012' THEN V_ACOD := '2170';
      WHEN I_CODCTA = '100014' THEN V_ACOD := '2170';
      WHEN I_CODCTA = '100016' THEN V_ACOD := '2170';
      WHEN I_CODCTA = '102000' THEN V_ACOD := '2021';
      WHEN I_CODCTA = '114000' THEN V_ACOD := '2180';
      WHEN I_CODCTA = '116000' THEN V_ACOD := '2180';
      WHEN I_CODCTA = '136000' THEN V_ACOD := '2019';
      WHEN I_CODCTA = '138000' THEN V_ACOD := '2021';
      WHEN I_CODCTA = '142000' THEN V_ACOD := '2140';
      WHEN I_CODCTA = '144000' THEN V_ACOD := '2140';
      WHEN I_CODCTA = '146000' THEN V_ACOD := '2140';
      WHEN I_CODCTA = '148000' THEN V_ACOD := '2140';
      WHEN I_CODCTA = '150000' THEN V_ACOD := '2140';
      WHEN I_CODCTA = '160000' THEN V_ACOD := '2140';
      WHEN I_CODCTA = '162000' THEN V_ACOD := '2140';
      WHEN I_CODCTA = '164000' THEN V_ACOD := '2140';
      WHEN I_CODCTA = '166000' THEN V_ACOD := '2140';
      WHEN I_CODCTA = '168000' THEN V_ACOD := '2190';
      WHEN I_CODCTA = '170000' THEN V_ACOD := '2190';
      WHEN I_CODCTA = '174000' THEN V_ACOD := '2200';
      WHEN I_CODCTA = '187000' THEN V_ACOD := '1080';
      WHEN I_CODCTA = '189000' THEN V_ACOD := '1080';
      WHEN I_CODCTA = '196000' THEN V_ACOD := '2021';
      --WHEN I_CODCTA = '205002' THEN V_ACOD := '1066';
      WHEN I_CODCTA = '236000' THEN V_ACOD := '2021';
      WHEN I_CODCTA = '238000' THEN V_ACOD := '2021';
      WHEN I_CODCTA = '268000' THEN V_ACOD := '2210';
      WHEN I_CODCTA = '284000' THEN V_ACOD := '2019';
      WHEN I_CODCTA = '290000' THEN V_ACOD := '2019';
      WHEN I_CODCTA = '292000' THEN V_ACOD := '2021';
      WHEN I_CODCTA = '304000' THEN V_ACOD := '2150';
      WHEN I_CODCTA = '390000' THEN V_ACOD := '2150';
      WHEN I_CODCTA = '391000' THEN V_ACOD := '1046';
      WHEN I_CODCTA = '397000' THEN V_ACOD := '1080';
      --WHEN I_CODCTA = '441000' THEN V_ACOD := '1066';
      --WHEN I_CODCTA = '449000' THEN V_ACOD := '1080';
      ELSE
        NULL;
    END CASE;

    RETURN V_ACOD;
  END FN_CALC_ACOD;
  ------------------------------------------------------------------------------
  -- FN_CALC_PLAZO: Calcula el plazo de la operacion en dias, con manejo de errores y logging.
  ------------------------------------------------------------------------------
  FUNCTION FN_CALC_PLAZO (
    I_ID_EJECUCION     IN NUMBER,
    I_COD_MODULO       IN VARCHAR2,
    I_COD_MODALIDAD    IN VARCHAR2,
    I_FEC_APERTURA     IN DATE,
    I_FEC_VENCIMIENTO  IN DATE,
    I_NRO_CUENTA       IN VARCHAR2
  ) RETURN NUMBER IS
    V_PLAZO     NUMBER;
    V_FEC_INICIO DATE;
    R_MCDOC     MD_CTA_DOCUMENTOS%ROWTYPE;
    V_INFO_ADIC VARCHAR2(200);
  BEGIN
    V_INFO_ADIC :=
      ' | MOD:'    || NVL(I_COD_MODULO,'NULL')    ||
      ', MODAL:'   || NVL(I_COD_MODALIDAD,'NULL') ||
      ', F_AP:'    || NVL(TO_CHAR(I_FEC_APERTURA,'YYYY-MM-DD'),'NULL') ||
      ', F_VENC:'  || NVL(TO_CHAR(I_FEC_VENCIMIENTO,'YYYY-MM-DD'),'NULL');

    -- DOCUMENTOS (MoDULO 10)
    IF I_COD_MODULO = '10' THEN
      BEGIN
        PAM_DOC.PR_OBT_DATOS(I_NRO_CUENTA, R_MCDOC);
        IF (R_MCDOC.FEC_VENCIMIENTO - R_MCDOC.FEC_INICIO) = 0 THEN
          V_PLAZO := 1;
        ELSE
          V_PLAZO := R_MCDOC.FEC_VENCIMIENTO - R_MCDOC.FEC_INICIO;
        END IF;
        RETURN V_PLAZO;
      EXCEPTION
        WHEN OTHERS THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION,
              'ERROR',
              I_NRO_CUENTA,
              'FN_CALC_PLAZO',
              'Error en obtencion de datos de documento (PAM_DOC.PR_OBT_DATOS): ' || SQLERRM || V_INFO_ADIC
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;
    END IF;

    -- RESTO DE LOS CASOS
    BEGIN
      V_PLAZO := NVL(I_FEC_VENCIMIENTO, I_FEC_APERTURA + 1) - I_FEC_APERTURA;
      RETURN V_PLAZO;
    EXCEPTION
      WHEN OTHERS THEN
        BEGIN
          PRC_LOG_TAS_INT_SEM_DET(
            I_ID_EJECUCION,
            'ERROR',
            I_NRO_CUENTA,
            'FN_CALC_PLAZO',
            'Error en calculo de plazo generico: ' || SQLERRM || V_INFO_ADIC
          );
        EXCEPTION WHEN OTHERS THEN NULL; END;
        RETURN NULL;
    END;
  END FN_CALC_PLAZO;
  ------------------------------------------------------------------------------
  -- FN_CALC_MONTO: Calcula el monto segun modulo, modalidad y moneda, con logging
  ------------------------------------------------------------------------------
  FUNCTION FN_CALC_MONTO (
    I_ID_EJECUCION   IN NUMBER,
    I_COD_MODULO     IN NUMBER,
    I_COD_MODALIDAD  IN NUMBER,
    I_NRO_CUENTA     IN VARCHAR2,
    I_SAL_CONTABLE   IN NUMBER,
    I_COD_MONEDA     IN VARCHAR2,
    I_FEC_APERTURA   IN DATE
  ) RETURN NUMBER IS
    v_valor_cambio   NUMBER;
    v_monto_result   NUMBER := 0;
    v_monto_aux      NUMBER := 0;
    v_moneda_local   VARCHAR2(10);
    v_info_adic      VARCHAR2(250);
    r_mcdoc          md_cta_documentos%rowtype;
  BEGIN
    v_moneda_local := PAG_GEN.FU_OBT_MON_LOCAL;
    v_info_adic := ' | MOD:'    || NVL(TO_CHAR(I_COD_MODULO),'NULL')
                || ', MODAL:'   || NVL(TO_CHAR(I_COD_MODALIDAD),'NULL')
                || ', MON:'     || NVL(I_COD_MONEDA,'NULL')
                || ', F_AP:'    || NVL(TO_CHAR(I_FEC_APERTURA,'YYYY-MM-DD'),'NULL');

    -- PReSTAMOS
    IF I_COD_MODULO = 6 THEN
      BEGIN
        SELECT MTO_CAPITAL INTO v_monto_result
          FROM PR_CTA_PRESTAMOS
         WHERE NRO_CUENTA = I_NRO_CUENTA;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_monto_result := 0;
        WHEN OTHERS THEN
          v_monto_result := NULL;
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_MONTO',
              'Error en obtencion de monto PReSTAMOS: ' || SQLERRM || v_info_adic
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;

    -- CERTIFICADOS / PLAZO FIJO
    ELSIF I_COD_MODULO = 3 AND I_COD_MODALIDAD = 33 THEN
      BEGIN
        SELECT NVL(SAL_TOT_BATCH,0) - NVL(SAL_RET_BATCH,0)
          INTO v_monto_result
          FROM AH_CTA_CERTIFICADOS
         WHERE NRO_CUENTA = I_NRO_CUENTA;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_monto_result := 0;
        WHEN OTHERS THEN
          v_monto_result := NULL;
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_MONTO',
              'Error en obtencion de monto CERTIFICADOS: ' || SQLERRM || v_info_adic
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;

    ELSIF I_COD_MODULO = 3 AND I_COD_MODALIDAD IN (37, 38) THEN
      BEGIN
        SELECT NVL(SAL_TOT_BATCH,0) - NVL(SAL_RET_BATCH,0), capital
          INTO v_monto_result, v_monto_aux
          FROM AH_CTA_PLAZOS
         WHERE NRO_CUENTA = I_NRO_CUENTA;

         IF v_monto_result <= 0 THEN
           v_monto_result := v_monto_aux;
         END IF;

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_monto_result := 0;
        WHEN OTHERS THEN
          v_monto_result := NULL;
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_MONTO',
              'Error en obtencion de monto PLAZOS: ' || SQLERRM || v_info_adic
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;

    -- TARJETAS
    ELSIF I_COD_MODULO = 5 THEN
      BEGIN
        SELECT NVL(SUM(D.SAL_ACTUAL),0)
          INTO v_monto_result
          FROM CB_SAL_INVENTARIOS_DET_HIS D
               JOIN CB_SAL_INVENTARIOS_HIS C ON D.NRO_REFERENCIA = C.NRO_REFERENCIA
         WHERE C.FECHA = TRUNC(I_FEC_APERTURA)
           AND D.NRO_CUENTA = I_NRO_CUENTA
           AND C.COD_MODULO = 5
           AND C.COD_MODALIDAD != 55
           AND NVL(C.SAL_TOTAL,0) != 0
           AND SUBSTR(C.COD_RUBRO,6,3) IN ('205','265','275','269')
           AND C.COD_RUBRO IS NOT NULL;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_monto_result := 0;
        WHEN OTHERS THEN
          v_monto_result := NULL;
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_MONTO',
              'Error en obtencion de monto TARJETAS: ' || SQLERRM || v_info_adic
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;

    -- SOBREGIROS
    ELSIF I_COD_MODULO = 4 AND I_COD_MODALIDAD = 41 THEN
      BEGIN
        SELECT NVL(SUM(D.SAL_ACTUAL),0)
          INTO v_monto_result
          FROM CB_SAL_INVENTARIOS_DET_HIS D
               JOIN CB_SAL_INVENTARIOS_HIS C ON D.NRO_REFERENCIA = C.NRO_REFERENCIA
         WHERE C.FECHA = TRUNC(I_FEC_APERTURA)
           AND D.NRO_CUENTA = I_NRO_CUENTA
           AND C.COD_MODULO = 4
           AND C.COD_MODALIDAD = 41
           AND NVL(C.SAL_TOTAL,0) != 0
           AND (SUBSTR(C.COD_RUBRO,6,3) IN ('187','189')
             OR SUBSTR(C.COD_RUBRO,6,5) IN ('21508','39702'))
           AND C.COD_RUBRO IS NOT NULL;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_monto_result := 0;
        WHEN OTHERS THEN
          v_monto_result := NULL;
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_MONTO',
              'Error en obtencion de monto SOBREGIROS: ' || SQLERRM || v_info_adic
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;

    -- CALL MONEY / DOCUMENTOS (MoDULO 10)
    ELSIF I_COD_MODULO = 10 THEN
      BEGIN
        PAM_DOC.PR_OBT_DATOS(I_NRO_CUENTA, r_mcdoc);
        v_monto_result := NVL(r_mcdoc.MONTO, 0);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_monto_result := 0;
        WHEN OTHERS THEN
          v_monto_result := NULL;
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_MONTO',
              'Error en obtencion de datos de documento (PAM_DOC.PR_OBT_DATOS) para CALL MONEY: '
              || SQLERRM || v_info_adic
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;

    ELSE    -- DEFAULT: SALDO CONTABLE
      v_monto_result := NVL(I_SAL_CONTABLE, 0);
    END IF;

    -- AJUSTE POR MONEDA
    IF I_COD_MONEDA <> v_moneda_local THEN
      BEGIN
        v_valor_cambio := PAG_GEN.FU_OBT_COTIZACION(I_COD_MONEDA, TRUNC(I_FEC_APERTURA));
        v_monto_result := NVL(v_monto_result, 0) * NVL(v_valor_cambio, 0) / 1000;
      EXCEPTION
        WHEN OTHERS THEN
          v_monto_result := NULL;
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_MONTO',
              'Error en obtencion de cotizacion/ajuste de moneda: ' || SQLERRM || v_info_adic
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;
    ELSE
      v_monto_result := NVL(v_monto_result, 0) / 1000;
    END IF;

    IF v_monto_result < 1 THEN
      v_monto_result := 1;
    END IF;

    RETURN v_monto_result;

  EXCEPTION
    WHEN OTHERS THEN
      BEGIN
        PRC_LOG_TAS_INT_SEM_DET(
          I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_MONTO',
          'Error general inesperado: ' || SQLERRM || v_info_adic
        );
      EXCEPTION WHEN OTHERS THEN NULL; END;
      RETURN NULL;
  END FN_CALC_MONTO;
  -------------------------------------------------------------------------------
  -- FN_CALC_PERIODO: Calcula el periodo informativo correspondiente para la operacion, con logging
  -------------------------------------------------------------------------------
  FUNCTION FN_CALC_PERIODO (
    I_ID_EJECUCION  IN NUMBER,
    I_COD_MODULO    IN VARCHAR2,
    I_COD_MODALIDAD IN VARCHAR2,
    I_NRO_CUENTA    IN VARCHAR2
  ) RETURN NUMBER IS
    V_TIP_CAPITALIZACION  NUMBER;
    V_PERIODO             NUMBER;
    V_FEC_INICIO          DATE;
    V_FEC_VENCIMIENTO     DATE;
    V_CAN_CUOTAS          NUMBER;
    V_PLAZO               NUMBER;
    V_AUX                 NUMBER;
    V_COD_MODALIDAD_PREST VARCHAR2(10);
    V_INFO_ADIC           VARCHAR2(100);
  BEGIN
    V_INFO_ADIC := ' | MOD:' || NVL(I_COD_MODULO,'NULL')
                || ', MODAL:' || NVL(I_COD_MODALIDAD,'NULL');

    -- AHORRO VISTA (MOD 3, MODALIDAD 31)
    IF I_COD_MODALIDAD = '31' THEN
      RETURN 30;
    END IF;

    -- CDA (MODALIDAD 33)
    IF I_COD_MODALIDAD = '33' THEN
      BEGIN
        SELECT FEC_VENCIMIENTO, FEC_APERTURA, TIP_CAPITALIZACION
          INTO V_FEC_VENCIMIENTO, V_FEC_INICIO, V_TIP_CAPITALIZACION
          FROM AH_CTA_CERTIFICADOS
         WHERE NRO_CUENTA = I_NRO_CUENTA;
        V_PLAZO := V_FEC_VENCIMIENTO - V_FEC_INICIO;
        IF V_PLAZO > 365 THEN
          V_PLAZO := 365;
        END IF;
        IF V_TIP_CAPITALIZACION = 1 THEN
          V_PERIODO := 30;
        ELSIF V_TIP_CAPITALIZACION = 2 THEN
          V_PERIODO := 60;
        ELSIF V_TIP_CAPITALIZACION = 3 THEN
          V_PERIODO := 90;
        ELSIF V_TIP_CAPITALIZACION = 4 THEN
          V_PERIODO := 120;
        ELSIF V_TIP_CAPITALIZACION = 6 THEN
          V_PERIODO := 180;
        ELSIF V_TIP_CAPITALIZACION = 12 THEN
          V_PERIODO := 365;
        ELSIF V_TIP_CAPITALIZACION = 99 THEN
          V_PERIODO := V_PLAZO;
        ELSE
          V_PERIODO := NULL;
        END IF;
        RETURN V_PERIODO;
      EXCEPTION
        WHEN OTHERS THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_PERIODO',
              'Error en periodo de CDA: ' || SQLERRM || V_INFO_ADIC
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;
    END IF;

    -- PLAZO FIJO (MODALIDAD 38)
    IF I_COD_MODALIDAD IN ('37','38') THEN
      BEGIN
        SELECT FEC_VENCIMIENTO, FEC_APERTURA, TIP_CAPITALIZACION
          INTO V_FEC_VENCIMIENTO, V_FEC_INICIO, V_TIP_CAPITALIZACION
          FROM AH_CTA_PLAZOS
         WHERE NRO_CUENTA = I_NRO_CUENTA;
        V_PLAZO := V_FEC_VENCIMIENTO - V_FEC_INICIO;
        IF V_PLAZO > 365 THEN
          V_PLAZO := 365;
        END IF;
        IF V_TIP_CAPITALIZACION = 1 THEN
          V_PERIODO := 30;
        ELSIF V_TIP_CAPITALIZACION = 2 THEN
          V_PERIODO := 60;
        ELSIF V_TIP_CAPITALIZACION = 3 THEN
          V_PERIODO := 90;
        ELSIF V_TIP_CAPITALIZACION = 4 THEN
          V_PERIODO := 120;
        ELSIF V_TIP_CAPITALIZACION = 6 THEN
          V_PERIODO := 180;
        ELSIF V_TIP_CAPITALIZACION = 12 THEN
          V_PERIODO := 365;
        ELSIF V_TIP_CAPITALIZACION = 99 THEN
          V_PERIODO := V_PLAZO;
        ELSE
          V_PERIODO := NULL;
        END IF;
        RETURN V_PERIODO;
      EXCEPTION
        WHEN OTHERS THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_PERIODO',
              'Error en periodo de PLAZO FIJO: ' || SQLERRM || V_INFO_ADIC
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;
    END IF;

    -- PRESTAMOS (MODULO 6)
    IF I_COD_MODULO = '6' THEN
      BEGIN
        SELECT FEC_INICIO, FEC_VENCIMIENTO, PER_VTO_CAPITAL, CAN_CUOTAS, COD_MODALIDAD
          INTO V_FEC_INICIO, V_FEC_VENCIMIENTO, V_PERIODO, V_CAN_CUOTAS, V_COD_MODALIDAD_PREST
          FROM PR_CTA_PRESTAMOS
         WHERE NRO_CUENTA = I_NRO_CUENTA;

        IF FUP_OBT_TIP_DESCuento(V_COD_MODALIDAD_PREST) IN ('D','C','F') THEN
          SELECT AVG(FEC_VENCIMIENTO - V_FEC_INICIO)
            INTO V_AUX
            FROM PR_CUOTAS
           WHERE NRO_CUENTA = I_NRO_CUENTA
             AND NRO_CUOTA > 0;
          V_PERIODO := V_AUX;
        ELSE
          IF V_CAN_CUOTAS = 1 THEN
            V_PERIODO := V_FEC_VENCIMIENTO - V_FEC_INICIO;
          END IF;
        END IF;
        IF V_PERIODO > 365 THEN
          V_PERIODO := 365;
        END IF;
        RETURN V_PERIODO;
      EXCEPTION
        WHEN OTHERS THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_PERIODO',
              'Error en periodo de PRESTAMOS: ' || SQLERRM || V_INFO_ADIC
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;
    END IF;

    -- TARJETAS, SOBREGIROS, DOCUMENTOS (MOD 4, 5, 10)
    IF I_COD_MODULO IN ('4', '5', '10') THEN
      RETURN 30;
    END IF;

    RETURN NULL;
  END FN_CALC_PERIODO;
  ------------------------------------------------------------------------------
  -- FN_CALC_TASREG: Calcula la tasa registrada o pactada para la operacion, con logging
  ------------------------------------------------------------------------------
  FUNCTION FN_CALC_TASREG (
    I_ID_EJECUCION  IN NUMBER,
    I_COD_MODULO    IN VARCHAR2,
    I_COD_MODALIDAD IN VARCHAR2,
    I_NRO_CUENTA    IN VARCHAR2
  ) RETURN VARCHAR2 IS
    v_tasreg   VARCHAR2(1);
    v_info_adic VARCHAR2(100);
  BEGIN
    v_info_adic := ' | MOD:' || NVL(I_COD_MODULO, 'NULL')
                || ', MODAL:' || NVL(I_COD_MODALIDAD, 'NULL');

    IF I_COD_MODALIDAD IN ('31','33','37','38') THEN
      RETURN 'V';
    ELSIF I_COD_MODULO = '6' THEN
      BEGIN
        SELECT TIP_INTERES INTO v_tasreg
          FROM PR_CTA_PRESTAMOS
         WHERE NRO_CUENTA = I_NRO_CUENTA;
        RETURN v_tasreg;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ADVERTENCIA', I_NRO_CUENTA, 'FN_CALC_TASREG',
              'NO_DATA_FOUND en TIP_INTERES (PR_CTA_PRESTAMOS).' || v_info_adic
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN 'V';
        WHEN OTHERS THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_TASREG',
              'Error inesperado en TIP_INTERES (PR_CTA_PRESTAMOS): ' || SQLERRM || v_info_adic
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;
    ELSIF I_COD_MODULO = '10' THEN
      BEGIN
        SELECT TIP_CALCULO INTO v_tasreg
          FROM MD_CTA_DOCUMENTOS
         WHERE NRO_CUENTA = I_NRO_CUENTA;
        RETURN v_tasreg;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ADVERTENCIA', I_NRO_CUENTA, 'FN_CALC_TASREG',
              'NO_DATA_FOUND en TIP_CALCULO (MD_CTA_DOCUMENTOS).' || v_info_adic
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN 'V';
        WHEN OTHERS THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_TASREG',
              'Error inesperado en TIP_CALCULO (MD_CTA_DOCUMENTOS): ' || SQLERRM || v_info_adic
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;
    ELSIF I_COD_MODULO IN ('4','5') THEN
      RETURN 'V';
    ELSE
      RETURN 'V';
    END IF;

  END FN_CALC_TASREG;
  -------------------------------------------------------------------------------
  -- FN_CALC_TASA_NOMINAL: Calcula la tasa nominal para la cuenta, con logging
  -------------------------------------------------------------------------------
  FUNCTION FN_CALC_TASA_NOMINAL (
    I_ID_EJECUCION      IN NUMBER,
    I_COD_MODULO        IN VARCHAR2,
    I_COD_MODALIDAD     IN VARCHAR2,
    I_COD_OFICINA       IN VARCHAR2,
    I_NRO_CUENTA        IN VARCHAR2,
    I_COD_MONEDA        IN VARCHAR2,
    I_MONTO             IN NUMBER,
    I_TAS_PERSONALIZADA IN VARCHAR2,
    I_COD_TASA          IN VARCHAR2,
    I_VAL_TASA          IN NUMBER,
    I_FEC_APERTURA      IN DATE
  ) RETURN NUMBER IS
    V_TASA_NOMINAL    NUMBER := 0;
    V_VAL_TASA        NUMBER := I_VAL_TASA;
    V_NRO_SOLICITUD   PR_CTA_PRESTAMOS.NRO_SOLICITUD%TYPE;
    V_MTO_CAPITAL     PR_CTA_PRESTAMOS.MTO_CAPITAL%TYPE;
    V_TASA_EFECTIVA   NUMBER;
    R_MCDOC           MD_CTA_DOCUMENTOS%ROWTYPE;
    V_INFO_ADIC       VARCHAR2(200);
  BEGIN
    V_INFO_ADIC := ' | MOD:'    || NVL(I_COD_MODULO,'NULL')
                || ', MODAL:'   || NVL(I_COD_MODALIDAD,'NULL')
                || ', OF:'      || NVL(I_COD_OFICINA,'NULL')
                || ', MON:'     || NVL(I_COD_MONEDA,'NULL')
                || ', F_AP:'    || NVL(TO_CHAR(I_FEC_APERTURA,'YYYY-MM-DD'),'NULL');

    IF I_COD_MODULO = '4' THEN
      RETURN 0;

    ELSIF I_COD_MODULO = '10' THEN
      BEGIN
        SELECT VAL_TASA INTO V_TASA_NOMINAL
          FROM MD_CTA_DOCUMENTOS
         WHERE NRO_CUENTA = I_NRO_CUENTA;
        RETURN V_TASA_NOMINAL;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ADVERTENCIA', I_NRO_CUENTA, 'FN_CALC_TASA_NOMINAL',
              'NO_DATA_FOUND en MD_CTA_DOCUMENTOS.' || V_INFO_ADIC
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN 0;
        WHEN OTHERS THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_TASA_NOMINAL',
              'Error inesperado en MD_CTA_DOCUMENTOS: ' || SQLERRM || V_INFO_ADIC
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;

    ELSIF I_COD_MODULO = '6' THEN
      BEGIN
        -- Intento obtener la solicitud (puede ser NULL)
        BEGIN
          SELECT NRO_SOLICITUD, MTO_CAPITAL INTO V_NRO_SOLICITUD, V_MTO_CAPITAL
            FROM PR_CTA_PRESTAMOS
           WHERE NRO_CUENTA = I_NRO_CUENTA;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            V_NRO_SOLICITUD := NULL;
            V_MTO_CAPITAL   := NULL;
          WHEN OTHERS THEN
            V_NRO_SOLICITUD := NULL;
            V_MTO_CAPITAL   := NULL;
            BEGIN
              PRC_LOG_TAS_INT_SEM_DET(
                I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_TASA_NOMINAL',
                'Error inesperado en obtencion de solicitud/prestamo: ' || SQLERRM || V_INFO_ADIC
              );
            EXCEPTION WHEN OTHERS THEN NULL; END;
        END;
        -- Llamada a PAS_BCP.PR_OBT_TAS_PRESTAMO (tasa nominal por OUT)
        BEGIN
          IF V_NRO_SOLICITUD IS NOT NULL THEN
            PAS_BCP.PR_OBT_TAS_PRESTAMO(V_NRO_SOLICITUD, NULL, V_TASA_EFECTIVA, V_TASA_NOMINAL);
          ELSE
            PAS_BCP.PR_OBT_TAS_PRESTAMO(NULL, I_NRO_CUENTA, V_TASA_EFECTIVA, V_TASA_NOMINAL);
          END IF;
          RETURN V_TASA_NOMINAL;
        EXCEPTION
          WHEN OTHERS THEN
            BEGIN
              PRC_LOG_TAS_INT_SEM_DET(
                I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_TASA_NOMINAL',
                'Error en PAS_BCP.PR_OBT_TAS_PRESTAMO: ' || SQLERRM || V_INFO_ADIC
              );
            EXCEPTION WHEN OTHERS THEN NULL; END;
            RETURN NULL;
        END;
      END;

    ELSIF V_VAL_TASA IS NULL THEN
      BEGIN
        RETURN FUG_OBT_VAL_TASA(
          I_COD_MODULO, I_COD_MODALIDAD, I_COD_OFICINA,
          I_NRO_CUENTA, I_COD_MONEDA, I_MONTO, I_TAS_PERSONALIZADA,
          I_COD_TASA, NULL, I_FEC_APERTURA);
      EXCEPTION
        WHEN OTHERS THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_TASA_NOMINAL',
              'Error en FUG_OBT_VAL_TASA: ' || SQLERRM || V_INFO_ADIC
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;

    ELSE
      RETURN V_VAL_TASA;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      BEGIN
        PRC_LOG_TAS_INT_SEM_DET(
          I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_TASA_NOMINAL',
          'Error general inesperado: ' || SQLERRM || V_INFO_ADIC
        );
      EXCEPTION WHEN OTHERS THEN NULL; END;
      RETURN NULL;
  END FN_CALC_TASA_NOMINAL;
  -------------------------------------------------------------------------------
  -- FN_CALC_TASA_EFECTIVA: Calcula la tasa efectiva para la cuenta, con logging
  -------------------------------------------------------------------------------
  FUNCTION FN_CALC_TASA_EFECTIVA (
    I_ID_EJECUCION   IN NUMBER,
    I_TASA_NOMINAL   IN NUMBER,
    I_PLAZO_DIAS     IN NUMBER,
    I_COD_MODULO     IN VARCHAR2,
    I_COD_MODALIDAD  IN VARCHAR2,
    I_NRO_CUENTA     IN VARCHAR2,
    I_CAPITAL        IN NUMBER DEFAULT NULL
  ) RETURN NUMBER IS
    V_TASA_EFECTIVA    NUMBER := NULL;
    V_TIP_CAP          AH_CTA_CERTIFICADOS.TIP_CAPITALIZACION%TYPE;
    V_CAPITAL          AH_CTA_CERTIFICADOS.CAPITAL%TYPE;
    V_NRO_SOLICITUD    PR_CTA_PRESTAMOS.NRO_SOLICITUD%TYPE;
    V_TASA_NOMINAL_AUX NUMBER := I_TASA_NOMINAL;
    V_INFO_ADIC        VARCHAR2(200);
  BEGIN
    V_INFO_ADIC := ' | MOD:'    || NVL(I_COD_MODULO,'NULL')
                || ', MODAL:'   || NVL(I_COD_MODALIDAD,'NULL')
                || ', PLAZO:'   || NVL(TO_CHAR(I_PLAZO_DIAS),'NULL')
                || ', TNOM:'    || NVL(TO_CHAR(I_TASA_NOMINAL),'NULL');

    -- PReSTAMOS (MODULO 6)
    IF I_COD_MODULO = '6' THEN
      BEGIN
        SELECT NRO_SOLICITUD
          INTO V_NRO_SOLICITUD
          FROM PR_CTA_PRESTAMOS
         WHERE NRO_CUENTA = I_NRO_CUENTA;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          V_NRO_SOLICITUD := NULL;
        WHEN OTHERS THEN
          V_NRO_SOLICITUD := NULL;
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_TASA_EFECTIVA',
              'Error inesperado obteniendo NRO_SOLICITUD (PR_CTA_PRESTAMOS): ' || SQLERRM || V_INFO_ADIC
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
      END;
      BEGIN
        IF V_NRO_SOLICITUD IS NOT NULL THEN
          PAS_BCP.PR_OBT_TAS_PRESTAMO(V_NRO_SOLICITUD, NULL, V_TASA_EFECTIVA, V_TASA_NOMINAL_AUX);
        ELSE
          PAS_BCP.PR_OBT_TAS_PRESTAMO(NULL, I_NRO_CUENTA, V_TASA_EFECTIVA, V_TASA_NOMINAL_AUX);
        END IF;
        RETURN V_TASA_EFECTIVA;
      EXCEPTION
        WHEN OTHERS THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_TASA_EFECTIVA',
              'Error ejecutando PR_OBT_TAS_PRESTAMO: ' || SQLERRM || V_INFO_ADIC
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;
    END IF;

    -- TARJETAS Y DOCUMENTOS
    IF I_COD_MODULO = '10' THEN
      BEGIN
        RETURN PAS_BCP.FU_OBT_TAE(I_TASA_NOMINAL, I_PLAZO_DIAS);
      EXCEPTION
        WHEN OTHERS THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_TASA_EFECTIVA',
              'Error en FU_OBT_TAE (MOD 10): ' || SQLERRM || V_INFO_ADIC
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;
    ELSIF I_COD_MODULO IN ('4', '5') THEN
      BEGIN
        RETURN PAS_BCP.FU_OBT_TAE(I_TASA_NOMINAL, 30);
      EXCEPTION
        WHEN OTHERS THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_TASA_EFECTIVA',
              'Error en FU_OBT_TAE (MOD 4/5): ' || SQLERRM || V_INFO_ADIC
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;
    END IF;

    -- CDA (MODALIDAD 33)
    IF I_COD_MODALIDAD = '33' THEN
      BEGIN
        SELECT TIP_CAPITALIZACION, CAPITAL
          INTO V_TIP_CAP, V_CAPITAL
          FROM AH_CTA_CERTIFICADOS
         WHERE NRO_CUENTA = I_NRO_CUENTA;
        RETURN PAS_BCP.FU_OBT_TAE_CDA(V_TIP_CAP, I_TASA_NOMINAL, I_PLAZO_DIAS, V_CAPITAL);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ADVERTENCIA', I_NRO_CUENTA, 'FN_CALC_TASA_EFECTIVA',
              'NO_DATA_FOUND en AH_CTA_CERTIFICADOS.' || V_INFO_ADIC
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
        WHEN OTHERS THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_TASA_EFECTIVA',
              'Error en obtencion de TAE_CDA (CDA): ' || SQLERRM || V_INFO_ADIC
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;
    END IF;

    -- PLAZO FIJO (MODALIDAD 37, 38)
    IF I_COD_MODALIDAD IN ('37', '38') THEN
      BEGIN
        SELECT TIP_CAPITALIZACION, CAPITAL
          INTO V_TIP_CAP, V_CAPITAL
          FROM AH_CTA_PLAZOS
         WHERE NRO_CUENTA = I_NRO_CUENTA;
        RETURN PAS_BCP.FU_OBT_TAE_CDA(V_TIP_CAP, I_TASA_NOMINAL, I_PLAZO_DIAS, V_CAPITAL);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ADVERTENCIA', I_NRO_CUENTA, 'FN_CALC_TASA_EFECTIVA',
              'NO_DATA_FOUND en AH_CTA_PLAZOS.' || V_INFO_ADIC
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
        WHEN OTHERS THEN
          BEGIN
            PRC_LOG_TAS_INT_SEM_DET(
              I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_TASA_EFECTIVA',
              'Error en obtencion de TAE_CDA (PLAZOS): ' || SQLERRM || V_INFO_ADIC
            );
          EXCEPTION WHEN OTHERS THEN NULL; END;
          RETURN NULL;
      END;
    END IF;

    RETURN NULL;
  EXCEPTION
    WHEN OTHERS THEN
      BEGIN
        PRC_LOG_TAS_INT_SEM_DET(
          I_ID_EJECUCION, 'ERROR', I_NRO_CUENTA, 'FN_CALC_TASA_EFECTIVA',
          'Error general inesperado: ' || SQLERRM || V_INFO_ADIC
        );
      EXCEPTION WHEN OTHERS THEN NULL; END;
      RETURN NULL;
  END FN_CALC_TASA_EFECTIVA;
  ------------------------------------------------------------------------------
  -- INS_LOG_TAS_INT_SEM: Inserta registro de log de inicio (COMMIT AUToNOMO)
  ------------------------------------------------------------------------------
  PROCEDURE INS_LOG_TAS_INT_SEM(
    O_ID_LOG       OUT NUMBER,
    I_ID_EJECUCION IN  NUMBER,
    I_TIPO_INF     IN  VARCHAR2
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO IT.GE_LOG_TAS_INT_SEM (
      ID_EJECUCION,
      TIPO_INFORME,
      USU_INSERCION
    ) VALUES (
      I_ID_EJECUCION,
      I_TIPO_INF,
      USER
    )
    RETURNING ID_LOG INTO O_ID_LOG;
    COMMIT;
  END INS_LOG_TAS_INT_SEM;
  ------------------------------------------------------------------------------
  -- UPD_LOG_TAS_INT_SEM: Actualiza el registro de log al finalizar la ejecucion (COMMIT AUToNOMO)
  ------------------------------------------------------------------------------
  PROCEDURE UPD_LOG_TAS_INT_SEM(
    I_ID_LOG        IN NUMBER,
    I_CANT_CUENTAS  IN NUMBER,
    I_CANT_ERRORES  IN NUMBER,
    I_ESTADO        IN VARCHAR2,
    I_MENSAJE       IN VARCHAR2
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    UPDATE IT.GE_LOG_TAS_INT_SEM
       SET CANT_CUENTAS      = I_CANT_CUENTAS,
           CANT_ERRORES      = I_CANT_ERRORES,
           ESTADO            = I_ESTADO,
           MENSAJE           = SUBSTR(I_MENSAJE, 1, 1000),
           FEC_FIN_EJECUCION = SYSDATE
     WHERE ID_LOG = I_ID_LOG;
    COMMIT;
  END UPD_LOG_TAS_INT_SEM;
-------------------------------------------------------------------------------
-- Procedure para registrar eventos en IT.GE_LOG_TAS_INT_SEM_DET
-- Controlado por el parametro dinamico:
--   VAL_LOG_TAS_INT_SEM_DET_HAB = 'S' (default) / 'N' (deshabilita logging)
-- Commit autonomo; levanta RAISE_APPLICATION_ERROR si falla la insercion.
-------------------------------------------------------------------------------
PROCEDURE PRC_LOG_TAS_INT_SEM_DET (
    I_ID_EJECUCION  IN NUMBER,
    I_TIPO_EVENTO   IN VARCHAR2,
    I_NRO_CUENTA    IN VARCHAR2,
    I_PROCESO       IN VARCHAR2,
    I_MENSAJE       IN VARCHAR2
) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  v_flag  VARCHAR2(1);
BEGIN
  -- Lee el flag desde parametros dinamicos; default 'S' si no esta seteado
  BEGIN
    v_flag := UPPER(TRIM(fug_obt_pardinamico('VAL_LOG_TAS_INT_SEM_DET_HAB')));
  EXCEPTION
    WHEN OTHERS THEN
      v_flag := NULL;
  END;
  IF v_flag IS NULL THEN
    v_flag := 'S';
  END IF;

  -- Si esta deshabilitado, salir sin insertar
  IF v_flag = 'N' THEN
    ROLLBACK;  -- limpia la transaccion autonoma (por prolijidad)
    RETURN;
  END IF;

  -- Insert del log (habilitado)
  INSERT INTO IT.GE_LOG_TAS_INT_SEM_DET (
      ID_EJECUCION,
      TIPO_EVENTO,
      NRO_CUENTA,
      PROCESO,
      MENSAJE,
      FECHA_EVENTO
  ) VALUES (
      I_ID_EJECUCION,
      SUBSTR(I_TIPO_EVENTO, 1, 20),
      SUBSTR(I_NRO_CUENTA, 1, 20),
      SUBSTR(I_PROCESO, 1, 100),
      SUBSTR(I_MENSAJE, 1, 1000),
      SYSDATE
  );
  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    -- Solo si intentamos insertar y fallo: exponer el error
    RAISE_APPLICATION_ERROR(
      -20010,
      'Error al registrar en GE_LOG_TAS_INT_SEM_DET: ' ||
      'ID_EJECUCION=' || NVL(TO_CHAR(I_ID_EJECUCION),'NULL') || ', ' ||
      'TIPO_EVENTO='  || NVL(I_TIPO_EVENTO,'NULL')  || ', ' ||
      'NRO_CUENTA='   || NVL(I_NRO_CUENTA,'NULL')   || ', ' ||
      'PROCESO='      || NVL(I_PROCESO,'NULL')      || ', ' ||
      'MENSAJE='      || NVL(SUBSTR(I_MENSAJE,1,100),'NULL') ||
      '. ORA-ERR: '   || SQLERRM
    );
END PRC_LOG_TAS_INT_SEM_DET;

  ------------------------------------------------------------------------------
  -- PRC_GEN_TAS_INT: Calcula e inserta datos de tasas semanales en GE_INF_TAS_INT_SEM
  ------------------------------------------------------------------------------
  PROCEDURE PRC_GEN_TAS_INT IS
    V_CODIGO_SEMANA   GE_FEC_TAS_INT.CODIGO_SEMANA%TYPE;
    V_FEC_DESDE       DATE;
    V_FEC_HASTA       DATE;
    V_MES             VARCHAR2(20);
    V_NRO_SEMANA      NUMBER;
    V_ULTIMA_SEMANA   VARCHAR2(1);
    V_FECHA_EJECUCION DATE;
    V_ACOD            VARCHAR2(10);
    V_PLAZO           NUMBER(5);
    V_COD_PLAZO       NUMBER;
    V_CODCTA          VARCHAR2(10);
    V_MONTO           NUMBER;
    V_PERIODO         NUMBER;
    V_TASREG          VARCHAR2(1);
    V_TASA_NOMINAL    NUMBER(15,5);
    V_TASA_EFECTIVA   NUMBER(15,5);
    V_ID_LOG          NUMBER;
    V_ID_EJECUCION    NUMBER;
    V_CANT_CUENTAS    NUMBER;
    V_CANT_ERRORES    NUMBER;
    V_ESTADO          VARCHAR2(20);
    V_MENSAJE         VARCHAR2(1000);
    V_BATCH_COUNT     NUMBER := 0;
    V_HOR_FIN_CIERRE  GE_PROCESOS.HOR_FIN%TYPE;

    -- Flag para inicialización real de corrida (validación cierre + truncate REP)
    V_INIT_CORRIDA_DONE BOOLEAN := FALSE;

    CURSOR C_FECHAS IS
      SELECT CODIGO_SEMANA, FEC_DESDE, FEC_HASTA, MES, NRO_SEMANA,
             ULTIMA_SEMANA, FECHA_EJECUCION
        FROM IT.GE_FEC_TAS_INT
       WHERE NVL(ID_EJECUCION,0) = 0
         AND FECHA_EJECUCION <= SYSDATE
       ORDER BY FECHA_EJECUCION;

    CURSOR C_CUENTAS(
        P_FEC_DESDE    DATE,
        P_FEC_HASTA    DATE,
        P_COD_SEMANA   VARCHAR2,
        P_ID_EJECUCION NUMBER
    ) IS
      SELECT A.COD_MODULO,
             A.COD_MODALIDAD,
             A.COD_OFICINA,
             A.COD_MONEDA,
             A.NRO_CUENTA,
             A.SAL_CONTABLE,
             NVL(P.FEC_INI_RRR, A.FEC_APERTURA) AS FEC_APERTURA,
             A.FEC_VENCIMIENTO,
             A.VAL_TASA,
             A.TAS_PERSONALIZADA,
             A.COD_TASA
        FROM GE_CUENTAS A
        JOIN GE_EST_CUENTAS B
          ON A.COD_MODULO    = B.COD_MODULO
         AND A.COD_MODALIDAD = B.COD_MODALIDAD
         AND A.ESTADO        = B.ESTADO
        LEFT JOIN PR_CTA_PRESTAMOS P
          ON A.NRO_CUENTA = P.NRO_CUENTA
       WHERE (
               A.COD_MODULO = 6
            OR (A.COD_MODULO = 3 AND A.ESTADO <> 'A')
            OR A.COD_MODALIDAD IN (37,38)
            OR (
                 A.COD_MODULO = 10
                 AND (
                   FUG_OBT_PARDINAMICO('MDD_MAD_EMI_CALLMONEY',
                                      A.COD_MODULO,
                                      A.COD_MODALIDAD, NULL,NULL,NULL) = 'S'
                OR FUG_OBT_PARDINAMICO('MDD_MAD_REC_CALLMONEY',
                                      A.COD_MODULO,
                                      A.COD_MODALIDAD, NULL,NULL,NULL) = 'S'
                 )
               )
             )
         AND (
               (NVL(A.VAL_TASA,0) > 0 AND A.COD_MODULO = 6)
            OR (NVL(A.VAL_TASA,0) = 0 AND A.COD_MODALIDAD = 33)
            OR (NVL(A.VAL_TASA,0) > 0 AND A.COD_MODALIDAD IN (37,38))
            OR (
                 A.COD_MODULO = 10
                 AND (
                   FUG_OBT_PARDINAMICO('MDD_MAD_EMI_CALLMONEY',
                                      A.COD_MODULO,
                                      A.COD_MODALIDAD, NULL,NULL,NULL) = 'S'
                OR FUG_OBT_PARDINAMICO('MDD_MAD_REC_CALLMONEY',
                                      A.COD_MODULO,
                                      A.COD_MODALIDAD, NULL,NULL,NULL) = 'S'
                 )
               )
             )
         AND (
               NVL(P.FEC_INI_RRR, A.FEC_APERTURA) BETWEEN P_FEC_DESDE AND P_FEC_HASTA
            OR (
                 TRUNC(A.FEC_INSERCION) BETWEEN P_FEC_DESDE AND P_FEC_HASTA
                 AND A.COD_MODALIDAD = 675
               )
             )
         AND NOT EXISTS (
               SELECT 1
                 FROM IT.GE_INF_TAS_INT_SEM D
                WHERE D.NRO_CUENTA   = A.NRO_CUENTA
                  AND D.CORCOD       = P_COD_SEMANA
                  AND D.ID_EJECUCION = P_ID_EJECUCION
             )
         AND NOT (A.COD_MODULO = 3 AND A.COD_MODALIDAD = 33 AND A.ESTADO <> 'N');

  BEGIN

    FOR R IN C_FECHAS LOOP

      IF NOT V_INIT_CORRIDA_DONE THEN

        IF TO_CHAR(TRUNC(SYSDATE), 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') != 'MON' THEN

          SELECT MAX(HOR_FIN)
            INTO V_HOR_FIN_CIERRE
            FROM GE_PROCESOS
           WHERE COD_PROCESO = 11;

          IF V_HOR_FIN_CIERRE IS NULL THEN
            -- Cierre diario no finalizado: condicion esperada, salir sin error (NOR-655 / SRER-5770)
            RETURN;
          END IF;

        END IF;

        BEGIN
          EXECUTE IMMEDIATE 'TRUNCATE TABLE IT.GE_REP_TAS_INT_SEM';
        EXCEPTION
          WHEN OTHERS THEN
            PRC_LOG_TAS_INT_SEM_DET(NULL,'ERROR',NULL,'PRC_GEN_TAS_INT',
              'Error al truncar GE_REP_TAS_INT_SEM: '||SQLERRM);
            RETURN;
        END;

        V_INIT_CORRIDA_DONE := TRUE;
      END IF;

      V_CANT_CUENTAS := 0;
      V_CANT_ERRORES := 0;
      V_BATCH_COUNT  := 0;
      V_MENSAJE      := NULL;

      V_CODIGO_SEMANA   := R.CODIGO_SEMANA;
      V_FEC_DESDE       := R.FEC_DESDE;
      V_FEC_HASTA       := R.FEC_HASTA;
      V_MES             := R.MES;
      V_NRO_SEMANA      := R.NRO_SEMANA;
      V_ULTIMA_SEMANA   := R.ULTIMA_SEMANA;
      V_FECHA_EJECUCION := R.FECHA_EJECUCION;

      SELECT IT.S_GE_TAS_INT_EJECUCION.NEXTVAL
        INTO V_ID_EJECUCION
        FROM DUAL;

      UPDATE IT.GE_FEC_TAS_INT
         SET ID_EJECUCION = V_ID_EJECUCION,
             COMENTARIO   = 'Proceso en ejecucion'
       WHERE CODIGO_SEMANA       = V_CODIGO_SEMANA
         AND FECHA_EJECUCION     = V_FECHA_EJECUCION
         AND NVL(ID_EJECUCION,0) = 0;
      COMMIT;

      -- Log de inicio
      INS_LOG_TAS_INT_SEM(V_ID_LOG, V_ID_EJECUCION, 'SEM');

      FOR CUENTA IN C_CUENTAS(V_FEC_DESDE, V_FEC_HASTA, V_CODIGO_SEMANA, V_ID_EJECUCION) LOOP
        BEGIN
          V_CODCTA        := FN_CALC_CODCTA(
                               V_ID_EJECUCION,
                               CUENTA.COD_MODULO,
                               CUENTA.COD_MODALIDAD,
                               CUENTA.NRO_CUENTA
                             );
          V_PLAZO         := FN_CALC_PLAZO(
                               V_ID_EJECUCION,
                               CUENTA.COD_MODULO,
                               CUENTA.COD_MODALIDAD,
                               CUENTA.FEC_APERTURA,
                               CUENTA.FEC_VENCIMIENTO,
                               CUENTA.NRO_CUENTA
                             );
          V_COD_PLAZO     := FUG_OBT_PLZ_CONTABLE(V_PLAZO);
          V_ACOD          := FN_CALC_ACOD(
                               V_ID_EJECUCION,
                               V_CODCTA,
                               V_PLAZO,
                               CUENTA.COD_MODULO,
                               CUENTA.COD_MODALIDAD,
                               CUENTA.NRO_CUENTA,
                               NULL,
                               NULL
                             );
          V_MONTO         := FN_CALC_MONTO(
                               V_ID_EJECUCION,
                               CUENTA.COD_MODULO,
                               CUENTA.COD_MODALIDAD,
                               CUENTA.NRO_CUENTA,
                               CUENTA.SAL_CONTABLE,
                               CUENTA.COD_MONEDA,
                               CUENTA.FEC_APERTURA
                             );
          V_PERIODO       := FN_CALC_PERIODO(
                               V_ID_EJECUCION,
                               CUENTA.COD_MODULO,
                               CUENTA.COD_MODALIDAD,
                               CUENTA.NRO_CUENTA
                             );
          V_TASREG        := FN_CALC_TASREG(
                               V_ID_EJECUCION,
                               CUENTA.COD_MODULO,
                               CUENTA.COD_MODALIDAD,
                               CUENTA.NRO_CUENTA
                             );
          V_TASA_NOMINAL  := FN_CALC_TASA_NOMINAL(
                               V_ID_EJECUCION,
                               CUENTA.COD_MODULO,
                               CUENTA.COD_MODALIDAD,
                               CUENTA.COD_OFICINA,
                               CUENTA.NRO_CUENTA,
                               CUENTA.COD_MONEDA,
                               V_MONTO,
                               CUENTA.TAS_PERSONALIZADA,
                               CUENTA.COD_TASA,
                               CUENTA.VAL_TASA,
                               CUENTA.FEC_APERTURA
                             );
          V_TASA_EFECTIVA := FN_CALC_TASA_EFECTIVA(
                               V_ID_EJECUCION,
                               V_TASA_NOMINAL,
                               V_PLAZO,
                               CUENTA.COD_MODULO,
                               CUENTA.COD_MODALIDAD,
                               CUENTA.NRO_CUENTA,
                               CUENTA.SAL_CONTABLE
                             );

          IF V_CODCTA IS NULL
             OR V_ACOD IS NULL
             OR V_MONTO IS NULL
             OR V_TASA_NOMINAL IS NULL
             OR V_TASA_EFECTIVA IS NULL
          THEN
            V_CANT_ERRORES := V_CANT_ERRORES + 1;
            PRC_LOG_TAS_INT_SEM_DET(
              V_ID_EJECUCION,
              'ERROR',
              CUENTA.NRO_CUENTA,
              'PRC_GEN_TAS_INT',
              'Campos NULL: CODCTA=' || NVL(V_CODCTA,'NULL')
              || ', ACOD='    || NVL(V_ACOD,'NULL')
              || ', MONTO='   || NVL(TO_CHAR(V_MONTO),'NULL')
              || ', TAS_NOM=' || NVL(TO_CHAR(V_TASA_NOMINAL),'NULL')
              || ', TAS_EFE=' || NVL(TO_CHAR(V_TASA_EFECTIVA),'NULL')
            );
          END IF;

          INSERT INTO IT.GE_INF_TAS_INT_SEM (
            CORCOD, NRO_CUENTA, COD_MODULO, COD_MODALIDAD, COD_MONEDA,
            FEC_APERTURA, MONTO, VAL_TAS_LINEAL, VAL_TAS_NOMINAL,
            VAL_TAS_EFECTIVA, COD_PLAZO, ENTCOD, CODCTA, ACOD,
            PERIODO, TASREG, USU_INSERCION, FEC_INSERCION,
            USU_MODIFICACION, FEC_MODIFICACION, ID_EJECUCION,
            ESTADO_VALIDACION, DETALLE_VALIDACION, PLAZO
          ) VALUES (
            V_CODIGO_SEMANA, CUENTA.NRO_CUENTA, CUENTA.COD_MODULO,
            CUENTA.COD_MODALIDAD, CUENTA.COD_MONEDA,
            CUENTA.FEC_APERTURA, V_MONTO, CUENTA.VAL_TASA,
            V_TASA_NOMINAL, V_TASA_EFECTIVA, V_COD_PLAZO,
            PAG_GEN.FU_OBT_COD_ENTIDAD, V_CODCTA, V_ACOD,
            V_PERIODO, V_TASREG, USER, SYSDATE,
            USER, SYSDATE, V_ID_EJECUCION, NULL, NULL, V_PLAZO
          );

          V_CANT_CUENTAS := V_CANT_CUENTAS + 1;
          V_BATCH_COUNT  := V_BATCH_COUNT + 1;

          IF V_BATCH_COUNT >= 5000 THEN
            COMMIT;
            V_BATCH_COUNT := 0;
          END IF;

        EXCEPTION
          WHEN OTHERS THEN
            V_CANT_ERRORES := V_CANT_ERRORES + 1;
            PRC_LOG_TAS_INT_SEM_DET(
              V_ID_EJECUCION,
              'ERROR',
              CUENTA.NRO_CUENTA,
              'PRC_GEN_TAS_INT',
              'Excepcion: ' || SQLERRM
            );
        END;
      END LOOP;

      V_MENSAJE := 'Proceso Finalizado';
      V_ESTADO  := CASE WHEN V_CANT_ERRORES = 0 THEN 'OK' ELSE 'ADVERTENCIA' END;

      UPD_LOG_TAS_INT_SEM(
        V_ID_LOG, V_CANT_CUENTAS, V_CANT_ERRORES, V_ESTADO, V_MENSAJE
      );

      PAG_TAS.PRC_GEN_REP_TAS_INT(V_ID_EJECUCION);

      UPDATE IT.GE_FEC_TAS_INT
         SET COMENTARIO = 'Informe Generado'
       WHERE CODIGO_SEMANA   = V_CODIGO_SEMANA
         AND FECHA_EJECUCION = V_FECHA_EJECUCION
         AND ID_EJECUCION    = V_ID_EJECUCION;
      COMMIT;

    END LOOP;

  END PRC_GEN_TAS_INT;

  ------------------------------------------------------------------------------
  -- PRC_GEN_REP_TAS_INT: Genera el reporte plano
  ------------------------------------------------------------------------------
  PROCEDURE PRC_GEN_REP_TAS_INT (
    I_ID_EJECUCION IN NUMBER
  ) IS
    v_error_msg VARCHAR2(4000);
  BEGIN
    -- Paso 2: insertar formateado
    BEGIN
      INSERT INTO IT.GE_REP_TAS_INT_SEM (
        CORCOD, NRO_CUENTA, ENTCOD, CODCTA, COD_MONEDA, ACOD,
        FEC_APERTURA, TAS_LINEAL, VAL_TAS_NOMINAL, MONTO,
        PERIODO, TIP_INTERES, VAL_TAS_EFECTIVA
      )
      SELECT
        /* CORCOD */       LPAD(TO_CHAR(t.CORCOD), 8, '0'),
        /* NRO_CUENTA */   LPAD(t.NRO_CUENTA, 15, '0'),
        /* ENTCOD */       LPAD(TO_CHAR(t.ENTCOD), 4, '0'),
        /* CODCTA */       LPAD(t.CODCTA, 6, '0'),

        /* COD_MONEDA (mapea GS/USD a 6900/6200) */
        LPAD(
          CASE
            WHEN t.COD_MONEDA = 'GS'  THEN '6900'
            WHEN t.COD_MONEDA = 'USD' THEN '6200'
            ELSE NVL(t.COD_MONEDA,'0000')
          END, 4, '0'
        ),

        /* ACOD */         LPAD(t.ACOD, 4, '0'),

        /* FEC_APERTURA: si es domingo => +1 día; formato DDMMYYYY */
        TO_CHAR(
          CASE WHEN PAG_CAL.FU_OBT_NOM_DIA(t.FEC_APERTURA) = 'DOMINGO'
               THEN t.FEC_APERTURA + 1
               ELSE t.FEC_APERTURA
          END,
          'DDMMYYYY'
        ),

        /* TAS_LINEAL: ya viene en t.VAL_TAS_LINEAL (NUMBER); salida "00,00" */
        LPAD(REPLACE(TO_CHAR(NVL(t.VAL_TAS_LINEAL, 0), 'FM00.00'),'.',','), 5, '0'),

        /* VAL_TAS_NOMINAL: "00,00" */
        LPAD(REPLACE(TO_CHAR(NVL(t.VAL_TAS_NOMINAL, 0), 'FM00.00'),'.',','), 5, '0'),

        /* MONTO: entero 10 dígitos */
        LPAD(TRIM(TO_CHAR(ROUND(NVL(t.MONTO,0),0),'9999999999')), 10, '0'),

        /* PERIODO */      LPAD(TO_CHAR(NVL(t.PERIODO,0)), 4, '0'),

        /* TIP_INTERES */  t.TASREG,

        /* VAL_TAS_EFECTIVA: "00,00" */
        LPAD(REPLACE(TO_CHAR(NVL(t.VAL_TAS_EFECTIVA, 0), 'FM00.00'),'.',','), 5, '0')

      FROM IT.GE_INF_TAS_INT_SEM t
      WHERE t.ID_EJECUCION = I_ID_EJECUCION;

      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        v_error_msg := 'Error al insertar en GE_REP_TAS_INT_SEM: '||SQLERRM;
        PRC_LOG_TAS_INT_SEM_DET(I_ID_EJECUCION,'ERROR',NULL,'PRC_GEN_REP_TAS_INT',v_error_msg);
        ROLLBACK;
    END;
  END PRC_GEN_REP_TAS_INT;


END PAG_TAS;
