CREATE OR REPLACE PROCEDURE IT.PRG_ACT_SAL_MENSUAL IS

    V_FEC_DESDE   GE_CALENDARIOS.FEC_ACTUAL%TYPE;
    V_FEC_HASTA   GE_CALENDARIOS.FEC_ACTUAL%TYPE;
    V_SAL_FIN_MES AH_SAL_MENSUALES.SAL_FIN_MES%TYPE;
    V_SAL_INI_MES AH_SAL_MENSUALES.SAL_INI_MES%TYPE;
    V_EXI_CUENTA  VARCHAR2(1);

    CURSOR AHORROS IS
            SELECT A.NRO_CUENTA,
                   AH.COD_MODULO,
                   AH.COD_MODALIDAD,
                   AH.COD_OFICINA,
                   SUM(DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'D',1,0))                         CAN_DEBITO ,
                   SUM(DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'C',1,0))                         CAN_CREDITO,
                   SUM(DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'D',NVL(A.MONTO, 0),0))           TOT_DEBITO ,
                   SUM(DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'C',NVL(A.MONTO, 0),0))           TOT_CREDITO,
                   NVL(F_OBT_SAL_ANTERIOR(A.NRO_CUENTA, fug_obt_fec_ext_ant(V_FEC_HASTA,a.nro_cuenta)),0) sal_ini_mes
              FROM AH_CTA_VISTAS AH, GE_TRANSACCIONES B, AH_MOVIMIENTOS_HIS A
             WHERE A.FECHA     >= V_FEC_DESDE
               AND A.FECHA      <= V_FEC_HASTA
               AND AH.NRO_CUENTA = A.NRO_CUENTA
               AND (A.REVERSADO = 'N' OR (A.REVERSADO  = 'S'
                                         AND FEC_VALOR < V_FEC_DESDE
                                         AND EXISTS (SELECT 1
                                                      FROM AH_MOVIMIENTOS_HIS REV
                                                     WHERE A.FEC_VALOR         = REV.FECHA
                                                       AND A.HOR_REVERSION     = REV.HORA
                                                       AND A.COD_USU_REVERSION = REV.COD_USUARIO
                                                       AND A.NRO_SECUENCIA     = REV.NRO_SECUENCIA))
                                     OR (A.REVERSADO         = 'S'
                                         AND A.COD_TRA_PADRE = 303
                                         AND A.Cod_Mad_Padre = 455))
               AND A.ESTADO           = 'N'
               AND A.COD_MODULO       = B.COD_MODULO
               AND A.COD_MODALIDAD    = B.COD_MODALIDAD
               AND A.COD_TRANSACCION  = B.COD_TRANSACCION
               AND B.VE_CLIENTE       = 'S'
               AND B.TIPO             IN ('C', 'D')
               AND NVL(B.AFECTA,'XX') != 'B'
            GROUP BY A.NRO_CUENTA ,
                     AH.COD_MODULO,
                     AH.COD_MODALIDAD,
                     AH.COD_OFICINA;

    CURSOR CORRIENTES IS
            SELECT A.NRO_CUENTA,
                   C.COD_MODULO,
                   C.COD_MODALIDAD,
                   C.COD_OFICINA,
                   SUM(DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'D',1,0))                         CAN_DEBITO ,
                   SUM(DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'C',1,0))                         CAN_CREDITO,
                   SUM(DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'D',NVL(A.MONTO, 0),0))           TOT_DEBITO ,
                   SUM(DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'C',NVL(A.MONTO, 0),0))           TOT_CREDITO,
                   NVL(F_OBT_SAL_ANTERIOR(A.NRO_CUENTA, fug_obt_fec_ext_ant(V_FEC_HASTA,a.nro_cuenta)),0) sal_ini_mes
              FROM CC_CTA_CORRIENTES C, GE_TRANSACCIONES B, CC_MOVIMIENTOS_HIS A
             WHERE A.FECHA      >=  V_FEC_DESDE
               AND A.FECHA      <= V_FEC_HASTA
               AND C.NRO_CUENTA = A.NRO_CUENTA
               AND (A.REVERSADO = 'N' OR (A.REVERSADO = 'S'
                                          AND FEC_VALOR < V_FEC_DESDE
                                          AND EXISTS (SELECT 1
                                                        FROM CC_MOVIMIENTOS_HIS REV
                                                       WHERE A.FEC_VALOR         = REV.FECHA
                                                         AND A.HOR_REVERSION     = REV.HORA
                                                         AND A.COD_USU_REVERSION = REV.COD_USUARIO
                                                         AND A.NRO_SECUENCIA     = REV.NRO_SECUENCIA))
                                      OR (A.REVERSADO         = 'S'
                                          AND A.COD_TRA_PADRE = 303
                                          AND A.COD_MAD_PADRE = 455))
               AND A.ESTADO           = 'N'
               AND A.COD_MODULO       = B.COD_MODULO
               AND A.COD_MODALIDAD    = B.COD_MODALIDAD
               AND A.COD_TRANSACCION  = B.COD_TRANSACCION
               AND B.VE_CLIENTE       = 'S'
               AND B.TIPO             IN ('C', 'D')
               AND NVL(B.AFECTA,'XX') != 'B'
            GROUP BY A.NRO_CUENTA ,
                     C.COD_MODULO,
                     C.COD_MODALIDAD,
                     C.COD_OFICINA;
BEGIN
    PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1;

    V_FEC_DESDE := to_date('01/10/2013', 'DD/MM/YYYY');
    V_FEC_HASTA := to_date('31/10/2013', 'DD/MM/YYYY');

       --> Si es Fin de mes entra aqui <--

       -- AH_SAL_MENSUALES
       FOR A IN AHORROS LOOP
           IF nvl(a.sal_ini_mes, 0) = 0 then
              BEGIN
                SELECT SAL_ULT_EXTRACTO
                  INTO v_sal_ini_mes
                  FROM AH_SAL_MENSUALES
                 WHERE NRO_CUENTA = A.NRO_CUENTA
                   AND ANO = TO_CHAR(ADD_MONTHS(V_FEC_HASTA,-1),'YYYY')
                   AND MES = TO_CHAR(ADD_MONTHS(V_FEC_HASTA,-1),'MM');
              EXCEPTION
                WHEN OTHERS THEN
                  V_SAL_INI_MES := 0;
              END;
           ELSE
             V_SAL_INI_MES := a.SAL_INI_MES;
           END IF;

           V_SAL_FIN_MES := NVL(V_SAL_INI_MES, 0) + NVL(A.TOT_CREDITO, 0) - NVL(A.TOT_DEBITO,0);

           UPDATE AH_SAL_MENSUALES AH
              SET AH.CAN_DEBITOS  = A.CAN_DEBITO  ,
                  AH.CAN_CREDITOS = A.CAN_CREDITO ,
                  AH.TOT_DEBITOS  = A.TOT_DEBITO  ,
                  AH.TOT_CREDITOS = A.TOT_CREDITO ,
                  AH.SAL_INI_MES  = NVL(V_SAL_INI_MES, 0) ,
                  AH.SAL_FIN_MES  = NVL(V_SAL_FIN_MES, 0) --> Solo se actualiza este campo si es fin de mes.-
            WHERE AH.NRO_CUENTA   = A.NRO_CUENTA
              AND AH.ANO          = TO_CHAR(V_FEC_HASTA,'YYYY')
              AND AH.MES          = TO_CHAR(V_FEC_HASTA,'MM'  );

           UPDATE AH_SAL_MENSUALES AH
              SET AH.SAL_INI_MES  = NVL(V_SAL_FIN_MES, 0)
            WHERE AH.NRO_CUENTA   = A.NRO_CUENTA
              AND AH.ANO          = TO_CHAR(ADD_MONTHS(V_FEC_HASTA,1),'YYYY')
              AND AH.MES          = TO_CHAR(ADD_MONTHS(V_FEC_HASTA,1),'MM');

           BEGIN
             SELECT DISTINCT 'S'
               INTO V_EXI_CUENTA
               FROM GE_SAL_MENSUALES
              WHERE NRO_CUENTA = A.NRO_CUENTA
                AND MES = TO_CHAR(V_FEC_HASTA,'MM')
                AND ANO = TO_CHAR(V_FEC_HASTA,'YYYY');
           EXCEPTION
             WHEN OTHERS THEN
               V_EXI_CUENTA := 'N';
           END;

           --Inserta en la tabla de GE_SAL_MENSUALES para que a partir de la misma se realice el ajuste de los saldos en CC_SAL_MENSUALES y AH_SAL_MENSUALES

           IF NVL(V_EXI_CUENTA, 'N') = 'N' THEN
              INSERT INTO GE_SAL_MENSUALES
              (COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, ANO, MES, CAN_DEBITOS, CAN_CREDITOS, TOT_DEBITOS, TOT_CREDITOS, SAL_INI_MES, SAL_FIN_MES)
              VALUES
              (A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA, A.NRO_CUENTA, TO_CHAR(V_FEC_HASTA,'YYYY'), TO_CHAR(V_FEC_HASTA,'MM'),
               A.CAN_DEBITO, A.CAN_CREDITO, A.TOT_DEBITO, A.TOT_CREDITO, NVL(V_SAL_INI_MES,0), NVL(V_SAL_FIN_MES,0));
           ELSE
              UPDATE GE_SAL_MENSUALES
                SET CAN_DEBITOS  = A.CAN_DEBITO  ,
                    CAN_CREDITOS = A.CAN_CREDITO ,
                    TOT_DEBITOS  = A.TOT_DEBITO  ,
                    TOT_CREDITOS = A.TOT_CREDITO ,
                    SAL_INI_MES  = NVL(V_SAL_INI_MES, 0),
                    SAL_FIN_MES  = NVL(V_SAL_FIN_MES, 0)
              WHERE NRO_CUENTA = A.NRO_CUENTA
                AND MES = TO_CHAR(V_FEC_HASTA,'MM')
                AND ANO = TO_CHAR(V_FEC_HASTA,'YYYY');
           END IF;



       END LOOP;

       -- CC_SAL_MENSUALES
       FOR C IN CORRIENTES LOOP

        IF nvl(c.sal_ini_mes, 0) = 0 then
           BEGIN
             SELECT NVL(SAL_ULT_EXTRACTO,0)
               INTO v_sal_ini_mes
               FROM CC_SAL_MENSUALES
              WHERE NRO_CUENTA = c.NRO_CUENTA
                AND ANO = TO_CHAR(ADD_MONTHS(V_FEC_HASTA,-1),'YYYY')
                AND MES = TO_CHAR(ADD_MONTHS(V_FEC_HASTA,-1),'MM');
           EXCEPTION
             WHEN OTHERS THEN
               V_SAL_INI_MES := 0;
           END;
         ELSE
           V_SAL_INI_MES := c.SAL_INI_MES;
         END IF;

         V_SAL_FIN_MES := NVL(V_SAL_INI_MES, 0) + NVL(c.TOT_CREDITO, 0) - NVL(c.TOT_DEBITO,0);

         UPDATE CC_SAL_MENSUALES AH
          SET   AH.CAN_DEBITOS  = C.CAN_DEBITO  ,
                AH.CAN_CREDITOS = C.CAN_CREDITO ,
                AH.TOT_DEBITOS  = C.TOT_DEBITO  ,
                AH.TOT_CREDITOS = C.TOT_CREDITO ,
                AH.SAL_INI_MES  = NVL(V_SAL_INI_MES,0) ,
                AH.SAL_FIN_MES  = NVL(V_SAL_FIN_MES,0)
          WHERE AH.NRO_CUENTA   = C.NRO_CUENTA
            AND AH.ANO          = TO_CHAR(V_FEC_HASTA,'YYYY')
            AND AH.MES          = TO_CHAR(V_FEC_HASTA,'MM'  );

         UPDATE CC_SAL_MENSUALES AH
            SET AH.SAL_INI_MES  = NVL(V_SAL_FIN_MES,0)
          WHERE AH.NRO_CUENTA   = C.NRO_CUENTA
            AND AH.ANO          = TO_CHAR(ADD_MONTHS(V_FEC_HASTA,1),'YYYY')
            AND AH.MES          = TO_CHAR(ADD_MONTHS(V_FEC_HASTA,1),'MM'  );

           BEGIN
             SELECT DISTINCT 'S'
               INTO V_EXI_CUENTA
               FROM GE_SAL_MENSUALES
              WHERE NRO_CUENTA = C.NRO_CUENTA
                AND MES = TO_CHAR(V_FEC_HASTA,'MM')
                AND ANO = TO_CHAR(V_FEC_HASTA,'YYYY');
           EXCEPTION
             WHEN OTHERS THEN
               V_EXI_CUENTA := 'N';
           END;

           --Inserta en la tabla de GE_SAL_MENSUALES para que a partir de la misma se realice el ajuste de los saldos en CC_SAL_MENSUALES y AH_SAL_MENSUALES

           IF NVL(V_EXI_CUENTA, 'N') = 'N' THEN
              INSERT INTO GE_SAL_MENSUALES
              (COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, ANO, MES, CAN_DEBITOS, CAN_CREDITOS, TOT_DEBITOS, TOT_CREDITOS, SAL_INI_MES, SAL_FIN_MES)
              VALUES
              (C.COD_MODULO, C.COD_MODALIDAD, C.COD_OFICINA, C.NRO_CUENTA, TO_CHAR(V_FEC_HASTA,'YYYY'), TO_CHAR(V_FEC_HASTA,'MM'),
               C.CAN_DEBITO, C.CAN_CREDITO, C.TOT_DEBITO, C.TOT_CREDITO, NVL(V_SAL_INI_MES,0), NVL(V_SAL_FIN_MES,0));
           ELSE
              UPDATE GE_SAL_MENSUALES
                  SET CAN_DEBITOS  = C.CAN_DEBITO  ,
                      CAN_CREDITOS = C.CAN_CREDITO ,
                      TOT_DEBITOS  = C.TOT_DEBITO  ,
                      TOT_CREDITOS = C.TOT_CREDITO ,
                      SAL_INI_MES  = NVL(V_SAL_INI_MES, 0),
                      SAL_FIN_MES  = NVL(V_SAL_FIN_MES, 0)
                WHERE NRO_CUENTA = C.NRO_CUENTA
                  AND MES = TO_CHAR(V_FEC_HASTA,'MM')
                  AND ANO = TO_CHAR(V_FEC_HASTA,'YYYY');
           END IF;

       END LOOP;
END;
/

