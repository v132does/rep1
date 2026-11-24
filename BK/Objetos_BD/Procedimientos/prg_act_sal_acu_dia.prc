CREATE OR REPLACE PROCEDURE IT.PRG_ACT_SAL_ACU_DIA IS

    V_FEC_ACTUAL            GE_CALENDARIOS.FEC_ACTUAL%TYPE;
    V_SAL_FIN_MES           AH_SAL_MENSUALES.SAL_FIN_MES%TYPE;
    V_SAL_INI_MES           AH_SAL_MENSUALES.SAL_INI_MES%TYPE;
    V_EXI_CUENTA            VARCHAR2(1);
    V_CAN_DEBITOS           NUMBER;
    V_CAN_CREDITOS          NUMBER; 
    V_TOT_DEBITOS           AH_SAL_MENSUALES.TOT_DEBITOS%TYPE;    
    V_TOT_CREDITOS          AH_SAL_MENSUALES.TOT_CREDITOS%TYPE;
    V_FEC_ULT_EXTRACTO      GE_EXT_CLI_CUENTAS.FEC_EXTRACTO%TYPE;

    CURSOR CUA_AHORROS IS
            SELECT A.NRO_CUENTA,
                   Ah.COD_MODULO,
                   Ah.COD_MODALIDAD,
                   Ah.COD_OFICINA,
                   SUM(DECODE(A.REVERSADO, 'S', 0, DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'D',1,0)))                         CAN_DEBITO ,
                   SUM(DECODE(A.REVERSADO, 'S', 0, DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'C',1,0)))                         CAN_CREDITO,
                   SUM(DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'D',NVL(A.MONTO, 0),0))           TOT_DEBITO ,
                   SUM(DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'C',NVL(A.MONTO, 0),0))          TOT_CREDITO,
                   SUM(CASE  when A.REVERSADO = 'S' AND FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA) = 'C' AND TO_CHAR(a.FEC_VALOR, 'MM') = TO_CHAR(V_FEC_ACTUAL, 'MM') AND a.fec_valor < a.fecha THEN 
                               -1
                             when A.REVERSADO = 'S' AND FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA) = 'D' AND TO_CHAR(a.FEC_VALOR, 'MM') <> TO_CHAR(V_FEC_ACTUAL, 'MM') AND a.fec_valor < a.fecha THEN 
                                1
                             when FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA) = 'C' AND a.cod_tra_padre = 303 and a.cod_mad_padre = 455  THEN 
                                1
                             ELSE 
                                0
                       END) as CAN_REV_CREDITO,
                    
                  SUM(CASE  when A.REVERSADO = 'S' AND FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA) = 'D' AND TO_CHAR(a.FEC_VALOR, 'MM') = TO_CHAR(V_FEC_ACTUAL, 'MM') AND a.fec_valor < a.fecha THEN 
                               -1
                            when A.REVERSADO = 'S' AND FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA) = 'C' AND TO_CHAR(a.FEC_VALOR, 'MM') <> TO_CHAR(V_FEC_ACTUAL, 'MM') AND a.fec_valor < a.fecha THEN 
                                1
                            when FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA) = 'D' AND a.cod_tra_padre = 303 and a.cod_mad_padre = 455  THEN 
                                1
                            ELSE 
                                0
                      END) as CAN_REV_DEBITO,
                  NVL(F_OBT_SAL_ANTERIOR(A.NRO_CUENTA, fug_obt_fec_ext_ant(V_FEC_ACTUAL,a.nro_cuenta)),0) sal_ini_mes
              FROM AH_CTA_VISTAS AH, GE_TRANSACCIONES B, GE_MOVIMIENTOS A
             WHERE  A.FECHA  = V_FEC_ACTUAL
               AND AH.NRO_CUENTA = A.NRO_CUENTA
               AND A.ESTADO           = 'N'
               AND A.COD_MODULO       = B.COD_MODULO
               AND A.COD_MODALIDAD    = B.COD_MODALIDAD
               AND A.COD_TRANSACCION  = B.COD_TRANSACCION
               AND B.VE_CLIENTE       = 'S'
               AND B.TIPO             IN ('C', 'D')
               AND NVL(B.AFECTA,'XX') != 'B'
            GROUP BY A.NRO_CUENTA ,
                     Ah.COD_MODULO,
                     Ah.COD_MODALIDAD,
                     Ah.COD_OFICINA;

    CURSOR CUC_CORRIENTES IS
            SELECT A.NRO_CUENTA,
                   c.COD_MODULO,
                   c.COD_MODALIDAD,
                   c.COD_OFICINA,
                   SUM(DECODE(A.REVERSADO, 'S', 0, DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'D',1,0)))                         CAN_DEBITO ,
                   SUM(DECODE(A.REVERSADO, 'S', 0, DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'C',1,0)))                         CAN_CREDITO,
                   SUM(DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'D',NVL(A.MONTO, 0),0))           TOT_DEBITO ,
                   SUM(DECODE(FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA),'C',NVL(A.MONTO, 0),0))           TOT_CREDITO,
                   SUM(CASE  when A.REVERSADO = 'S' AND FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA) = 'C' AND TO_CHAR(a.FEC_VALOR, 'MM') = TO_CHAR(V_FEC_ACTUAL, 'MM') AND a.fec_valor < a.fecha THEN 
                               -1
                             when A.REVERSADO = 'S' AND FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA) = 'D' AND TO_CHAR(a.FEC_VALOR, 'MM') <> TO_CHAR(V_FEC_ACTUAL, 'MM') AND a.fec_valor < a.fecha THEN 
                                1
                             when FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA) = 'C' AND a.cod_tra_padre = 303 and a.cod_mad_padre = 455  THEN 
                                1
                             ELSE 
                                0
                        END) as CAN_REV_CREDITO,
                    
                   SUM(CASE  when A.REVERSADO = 'S' AND FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA) = 'D' AND TO_CHAR(a.FEC_VALOR, 'MM') = TO_CHAR(V_FEC_ACTUAL, 'MM') AND a.fec_valor < a.fecha THEN 
                               -1
                             when A.REVERSADO = 'S' AND FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA) = 'C' AND TO_CHAR(a.FEC_VALOR, 'MM') <> TO_CHAR(V_FEC_ACTUAL, 'MM') AND a.fec_valor < a.fecha THEN 
                                1
                             when FUG_OBT_TRA_TIPO(B.COD_TRANSACCION,B.TIPO,B.AFECTA) = 'D' AND a.cod_tra_padre = 303 and a.cod_mad_padre = 455  THEN 
                                1
                             ELSE 
                                0
                      END) as CAN_REV_DEBITO,
                   NVL(F_OBT_SAL_ANTERIOR(A.NRO_CUENTA, fug_obt_fec_ext_ant(V_FEC_ACTUAL,a.nro_cuenta)),0) sal_ini_mes  
              FROM CC_CTA_CORRIENTES C, GE_TRANSACCIONES B, GE_MOVIMIENTOS A
             WHERE  A.FECHA      = V_FEC_ACTUAL
               AND C.NRO_CUENTA = A.NRO_CUENTA
               AND A.ESTADO           = 'N'
               AND A.COD_MODULO       = B.COD_MODULO
               AND A.COD_MODALIDAD    = B.COD_MODALIDAD
               AND A.COD_TRANSACCION  = B.COD_TRANSACCION
               AND B.VE_CLIENTE       = 'S'
               AND B.TIPO             IN ('C', 'D')
               AND NVL(B.AFECTA,'XX') != 'B'
            GROUP BY A.NRO_CUENTA ,
                     c.COD_MODULO,
                     c.COD_MODALIDAD,
                     c.COD_OFICINA;
    
BEGIN
    PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1;
    PAG_CAL.PR_OBT_DAT_CALENDAR(3);
    V_FEC_ACTUAL := PAG_CAL.G_FEC_ACTUAL;

    IF V_FEC_ACTUAL = PAG_CAL.G_ULT_DIA_MES_HABIL THEN
       --> Si es Fin de mes entra aqui <--

       -- AH_SAL_MENSUALES
       FOR A IN CUA_AHORROS LOOP

           IF nvl(a.sal_ini_mes, 0) = 0 then
              BEGIN
                SELECT SAL_ULT_EXTRACTO
                  INTO v_sal_ini_mes
                  FROM AH_SAL_MENSUALES 
                 WHERE NRO_CUENTA = A.NRO_CUENTA
                   AND ANO = TO_CHAR(ADD_MONTHS(V_FEC_ACTUAL,-1),'YYYY')
                   AND MES = TO_CHAR(ADD_MONTHS(V_FEC_ACTUAL,-1),'MM');
                   
                   
              EXCEPTION
                WHEN OTHERS THEN
                  V_SAL_INI_MES := 0;
              END;
           ELSE
             V_SAL_INI_MES := a.SAL_INI_MES;
           END IF;

          /*Verifica si existe en la tabla de càlculo de Saldos Mensuales (GE_SAL_MENSUALES) si no existe inserta, 
            si existe actualiza y en base a la misma actualiza los saldos Mensuales en la tabla CC_SAL_MENSUALES y AH_SAL_MENSUALES */
         
          BEGIN
             SELECT DISTINCT 'S'
               INTO V_EXI_CUENTA
               FROM GE_SAL_MENSUALES
              WHERE NRO_CUENTA = A.NRO_CUENTA
                AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
                AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY');
           EXCEPTION
             WHEN OTHERS THEN
               V_EXI_CUENTA := 'N';
           END;
           
           IF NVL(V_EXI_CUENTA, 'N') = 'N' THEN
              INSERT INTO GE_SAL_MENSUALES 
              (COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, ANO, MES, CAN_DEBITOS, CAN_CREDITOS, TOT_DEBITOS, TOT_CREDITOS, SAL_INI_MES, SAL_FIN_MES)
              VALUES
              (A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA, A.NRO_CUENTA, 
               TO_CHAR(V_FEC_ACTUAL,'YYYY'), TO_CHAR(V_FEC_ACTUAL,'MM'), 
               A.CAN_DEBITO, A.CAN_CREDITO, A.TOT_DEBITO, A.TOT_CREDITO, NVL(V_SAL_INI_MES,0), 
               NVL(V_SAL_INI_MES,0) - NVL(A.TOT_DEBITO,0) + NVL(A.TOT_CREDITO,0));
           ELSE
             UPDATE GE_SAL_MENSUALES
                SET CAN_DEBITOS  = NVL(CAN_DEBITOS,0) + NVL(A.CAN_DEBITO,0) + NVL(A.CAN_REV_DEBITO,0),
                    CAN_CREDITOS = NVL(CAN_CREDITOS,0) + NVL(A.CAN_CREDITO,0) + NVL(A.CAN_REV_CREDITO,0),
                    TOT_DEBITOS  = NVL(TOT_DEBITOS,0) + NVL(A.TOT_DEBITO,0)  ,
                    TOT_CREDITOS = NVL(TOT_CREDITOS,0) + NVL(A.TOT_CREDITO,0) ,
                    SAL_INI_MES  = NVL(V_SAL_INI_MES, 0),
                    SAL_FIN_MES  = NVL(V_SAL_INI_MES, 0) + NVL(TOT_CREDITOS,0) - NVL(TOT_DEBITOS,0) + NVL(A.TOT_CREDITO, 0) - NVL(A.TOT_DEBITO, 0) 
              WHERE NRO_CUENTA = A.NRO_CUENTA
                AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
                AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY');                
           END IF;       
           
           BEGIN
             SELECT CAN_DEBITOS, CAN_CREDITOS, TOT_DEBITOS, TOT_CREDITOS, SAL_FIN_MES
               INTO V_CAN_DEBITOS, V_CAN_CREDITOS, V_TOT_DEBITOS, V_TOT_CREDITOS, V_SAL_FIN_MES
               FROM GE_SAL_MENSUALES
              WHERE NRO_CUENTA = A.NRO_CUENTA
                AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
                AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY');   
           EXCEPTION
             WHEN OTHERS THEN 
                V_CAN_DEBITOS := 0;
                V_CAN_CREDITOS := 0; 
                V_TOT_DEBITOS := 0;
                V_TOT_CREDITOS := 0;
           END;

           UPDATE AH_SAL_MENSUALES AH
              SET AH.CAN_DEBITOS  = NVL(V_CAN_DEBITOS,0),
                  AH.CAN_CREDITOS = NVL(V_CAN_CREDITOS,0),
                  AH.TOT_DEBITOS  = NVL(V_TOT_DEBITOS,0),
                  AH.TOT_CREDITOS = NVL(V_TOT_CREDITOS,0),
                  AH.SAL_INI_MES  = NVL(V_SAL_INI_MES, 0),
                  AH.SAL_FIN_MES  = NVL(V_SAL_FIN_MES, 0)  --> Solo se actualiza este campo si es fin de mes.-
            WHERE AH.NRO_CUENTA   = A.NRO_CUENTA
              AND AH.ANO          = TO_CHAR(V_FEC_ACTUAL,'YYYY')
              AND AH.MES          = TO_CHAR(V_FEC_ACTUAL,'MM'  );
              
           UPDATE AH_SAL_MENSUALES AH
              SET AH.SAL_INI_MES  = NVL(V_SAL_FIN_MES, 0)
            WHERE AH.NRO_CUENTA   = A.NRO_CUENTA
              AND AH.ANO          = TO_CHAR(ADD_MONTHS(V_FEC_ACTUAL,1),'YYYY')
              AND AH.MES          = TO_CHAR(ADD_MONTHS(V_FEC_ACTUAL,1),'MM');        
       END LOOP;


       -- CC_SAL_MENSUALES
       FOR C IN CUC_CORRIENTES LOOP
       
          IF nvl(c.sal_ini_mes, 0) = 0 then
             BEGIN
               SELECT NVL(SAL_ULT_EXTRACTO,0)
                 INTO v_sal_ini_mes
                 FROM CC_SAL_MENSUALES 
                WHERE NRO_CUENTA = c.NRO_CUENTA
                  AND ANO = TO_CHAR(ADD_MONTHS(V_FEC_ACTUAL,-1),'YYYY')
                  AND MES = TO_CHAR(ADD_MONTHS(V_FEC_ACTUAL,-1),'MM');
             EXCEPTION
               WHEN OTHERS THEN
                 V_SAL_INI_MES := 0;
             END;
        ELSE
           V_SAL_INI_MES := c.SAL_INI_MES;
        END IF;
         
        BEGIN
           SELECT DISTINCT 'S'
             INTO V_EXI_CUENTA
             FROM GE_SAL_MENSUALES
            WHERE NRO_CUENTA = C.NRO_CUENTA
              AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
              AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY');
        EXCEPTION
           WHEN OTHERS THEN
             V_EXI_CUENTA := 'N';
        END;
           --END IF;
           
        IF NVL(V_EXI_CUENTA, 'N') = 'N' THEN
           INSERT INTO GE_SAL_MENSUALES 
           (COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, ANO, MES, CAN_DEBITOS, CAN_CREDITOS, TOT_DEBITOS, TOT_CREDITOS, SAL_INI_MES, SAL_FIN_MES)
           VALUES
           (C.COD_MODULO, C.COD_MODALIDAD, C.COD_OFICINA, C.NRO_CUENTA, TO_CHAR(V_FEC_ACTUAL,'YYYY'), TO_CHAR(V_FEC_ACTUAL,'MM'), 
            C.CAN_DEBITO, C.CAN_CREDITO, C.TOT_DEBITO, C.TOT_CREDITO, NVL(V_SAL_INI_MES,0), 
            NVL(V_SAL_INI_MES,0) - NVL(C.TOT_DEBITO,0) + NVL(C.TOT_CREDITO,0));
        ELSE
           UPDATE GE_SAL_MENSUALES
              SET CAN_DEBITOS  = NVL(CAN_DEBITOS,0) + NVL(C.CAN_DEBITO,0) + NVL(C.CAN_REV_DEBITO,0),
                  CAN_CREDITOS = NVL(CAN_CREDITOS,0) + NVL(C.CAN_CREDITO,0) + NVL(C.CAN_REV_CREDITO,0),
                  TOT_DEBITOS  = NVL(TOT_DEBITOS,0) + NVL(C.TOT_DEBITO,0)  ,
                  TOT_CREDITOS = NVL(TOT_CREDITOS,0) + NVL(C.TOT_CREDITO,0) ,
                  SAL_INI_MES  = NVL(V_SAL_INI_MES, 0),
                  SAL_FIN_MES  = NVL(V_SAL_INI_MES, 0) + NVL(TOT_CREDITOS,0) - NVL(TOT_DEBITOS,0) + NVL(C.TOT_CREDITO, 0) - NVL(C.TOT_DEBITO, 0) 
            WHERE NRO_CUENTA = C.NRO_CUENTA
              AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
              AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY');                
        END IF;       
           
        BEGIN
          SELECT CAN_DEBITOS, CAN_CREDITOS, TOT_DEBITOS, TOT_CREDITOS, SAL_FIN_MES
            INTO V_CAN_DEBITOS, V_CAN_CREDITOS, V_TOT_DEBITOS, V_TOT_CREDITOS, V_SAL_FIN_MES
            FROM GE_SAL_MENSUALES
           WHERE NRO_CUENTA = C.NRO_CUENTA
             AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
             AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY');   
        EXCEPTION
          WHEN OTHERS THEN 
             V_CAN_DEBITOS := 0;
             V_CAN_CREDITOS := 0; 
             V_TOT_DEBITOS := 0;
             V_TOT_CREDITOS := 0;
        END;

        UPDATE CC_SAL_MENSUALES 
           SET CAN_DEBITOS  = NVL(V_CAN_DEBITOS,0),
               CAN_CREDITOS = NVL(V_CAN_CREDITOS,0),
               TOT_DEBITOS  = NVL(V_TOT_DEBITOS,0),
               TOT_CREDITOS = NVL(V_TOT_CREDITOS,0),
               SAL_INI_MES  = NVL(V_SAL_INI_MES, 0),
               SAL_FIN_MES  = NVL(V_SAL_FIN_MES, 0)  --> Solo se actualiza este campo si es fin de mes.-
         WHERE NRO_CUENTA   = C.NRO_CUENTA
           AND ANO          = TO_CHAR(V_FEC_ACTUAL,'YYYY')
           AND MES          = TO_CHAR(V_FEC_ACTUAL,'MM'  );
            
            
         UPDATE CC_SAL_MENSUALES
            SET SAL_INI_MES  = V_SAL_FIN_MES  --> Solo se actualiza este campo si es fin de mes.-
          WHERE NRO_CUENTA   = C.NRO_CUENTA
            AND ANO          = TO_CHAR(ADD_MONTHS(V_FEC_ACTUAL,1),'YYYY')
            AND MES          = TO_CHAR(ADD_MONTHS(V_FEC_ACTUAL,1),'MM'  );           
            
       END LOOP;
       -- Actualización de Saldos finales de las cuentas con movimientos en el mes
       UPDATE CC_SAL_MENSUALES C
          SET SAL_FIN_MES = (SELECT SAL_FIN_MES
                                 FROM GE_SAL_MENSUALES
                                WHERE NRO_CUENTA = C.NRO_CUENTA
                                  AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
                                  AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY'))
       WHERE MES = TO_CHAR(V_FEC_ACTUAL,'MM')
         AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY')
         AND EXISTS (SELECT 1 FROM GE_SAL_MENSUALES
                      WHERE NRO_CUENTA = C.NRO_CUENTA
                        AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
                        AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY'));
       
       UPDATE AH_SAL_MENSUALES C
          SET SAL_FIN_MES = (SELECT SAL_FIN_MES
                               FROM GE_SAL_MENSUALES
                              WHERE NRO_CUENTA = C.NRO_CUENTA
                                AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
                                AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY'))
        WHERE MES = TO_CHAR(V_FEC_ACTUAL,'MM')
          AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY')
          AND EXISTS (SELECT 1 FROM GE_SAL_MENSUALES
                       WHERE NRO_CUENTA = C.NRO_CUENTA
                         AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
                         AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY'));

    ELSE
       --> Si NO es Fin de mes entra aqui <--

       -- AH_SAL_MENSUALES
       FOR A IN CUA_AHORROS LOOP
         
           IF nvl(a.sal_ini_mes, 0) = 0 then
              BEGIN
                SELECT SAL_ULT_EXTRACTO
                  INTO v_sal_ini_mes
                  FROM AH_SAL_MENSUALES 
                 WHERE NRO_CUENTA = A.NRO_CUENTA
                   AND ANO = TO_CHAR(ADD_MONTHS(V_FEC_ACTUAL,-1),'YYYY')
                   AND MES = TO_CHAR(ADD_MONTHS(V_FEC_ACTUAL,-1),'MM');
              EXCEPTION
                WHEN OTHERS THEN
                  V_SAL_INI_MES := 0;
              END;
           ELSE
             V_SAL_INI_MES := a.SAL_INI_MES;
           END IF;
          /*Verifica si existe en la tabla de càlculo de Saldos Mensuales (GE_SAL_MENSUALES) si no existe inserta, 
            si existe actualiza y en base a la misma actualiza los saldos Mensuales en la tabla CC_SAL_MENSUALES y AH_SAL_MENSUALES */
           
          BEGIN
             SELECT DISTINCT 'S'
               INTO V_EXI_CUENTA
               FROM GE_SAL_MENSUALES
              WHERE NRO_CUENTA = A.NRO_CUENTA
                AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
                AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY');
           EXCEPTION
             WHEN OTHERS THEN
               V_EXI_CUENTA := 'N';
           END;
           
           IF NVL(V_EXI_CUENTA, 'N') = 'N' THEN
              INSERT INTO GE_SAL_MENSUALES 
              (COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, ANO, MES, CAN_DEBITOS, CAN_CREDITOS, TOT_DEBITOS, TOT_CREDITOS, SAL_INI_MES, SAL_FIN_MES)
              VALUES
              (A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA, A.NRO_CUENTA, TO_CHAR(V_FEC_ACTUAL,'YYYY'), TO_CHAR(V_FEC_ACTUAL,'MM'), 
               A.CAN_DEBITO, A.CAN_CREDITO, A.TOT_DEBITO, A.TOT_CREDITO, NVL(V_SAL_INI_MES,0), 
               NVL(V_SAL_INI_MES,0) - NVL(A.TOT_DEBITO,0) + NVL(A.TOT_CREDITO,0));
           ELSE
              UPDATE GE_SAL_MENSUALES
                SET CAN_DEBITOS  = NVL(CAN_DEBITOS,0) + NVL(A.CAN_DEBITO,0) + NVL(A.CAN_REV_DEBITO,0),
                    CAN_CREDITOS = NVL(CAN_CREDITOS,0) + NVL(A.CAN_CREDITO,0) + NVL(A.CAN_REV_CREDITO,0),
                    TOT_DEBITOS  = NVL(TOT_DEBITOS,0) + NVL(A.TOT_DEBITO,0)  ,
                    TOT_CREDITOS = NVL(TOT_CREDITOS,0) + NVL(A.TOT_CREDITO,0) ,
                    SAL_INI_MES  = NVL(V_SAL_INI_MES, 0),
                    SAL_FIN_MES  = NVL(V_SAL_INI_MES, 0) + NVL(TOT_CREDITOS,0) - NVL(TOT_DEBITOS,0) + NVL(A.TOT_CREDITO, 0) - NVL(A.TOT_DEBITO, 0)
              WHERE NRO_CUENTA = A.NRO_CUENTA
                AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
                AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY');                
           END IF;       
           
           BEGIN
             SELECT CAN_DEBITOS, CAN_CREDITOS, TOT_DEBITOS, TOT_CREDITOS
               INTO V_CAN_DEBITOS, V_CAN_CREDITOS, V_TOT_DEBITOS, V_TOT_CREDITOS
               FROM GE_SAL_MENSUALES
              WHERE NRO_CUENTA = A.NRO_CUENTA
                AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
                AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY');   
           EXCEPTION
             WHEN OTHERS THEN 
                V_CAN_DEBITOS := 0;
                V_CAN_CREDITOS := 0; 
                V_TOT_DEBITOS := 0;
                V_TOT_CREDITOS := 0;
           END;
           
           UPDATE AH_SAL_MENSUALES AH
              SET CAN_DEBITOS  = NVL(V_CAN_DEBITOS,0),
                  CAN_CREDITOS = NVL(V_CAN_CREDITOS,0),
                  TOT_DEBITOS  = NVL(V_TOT_DEBITOS,0),
                  TOT_CREDITOS = NVL(V_TOT_CREDITOS,0),
                  SAL_INI_MES  = NVL(V_SAL_INI_MES, 0)
            WHERE AH.NRO_CUENTA   = A.NRO_CUENTA
              AND AH.ANO          = TO_CHAR(V_FEC_ACTUAL,'YYYY')
              AND AH.MES          = TO_CHAR(V_FEC_ACTUAL,'MM'  );
       END LOOP;

       -- CC_SAL_MENSUALES
       FOR C IN CUC_CORRIENTES LOOP
         
          IF nvl(c.sal_ini_mes, 0) = 0 then
             BEGIN
               SELECT NVL(SAL_ULT_EXTRACTO,0)
                 INTO v_sal_ini_mes
                 FROM CC_SAL_MENSUALES 
                WHERE NRO_CUENTA = c.NRO_CUENTA
                  AND ANO = TO_CHAR(ADD_MONTHS(V_FEC_ACTUAL,-1),'YYYY')
                  AND MES = TO_CHAR(ADD_MONTHS(V_FEC_ACTUAL,-1),'MM');
             EXCEPTION
               WHEN OTHERS THEN
                 V_SAL_INI_MES := 0;
             END;
          ELSE
             V_SAL_INI_MES := c.SAL_INI_MES;
          END IF;
          
 
          /*Verifica si existe en la tabla de càlculo de Saldos Mensuales (GE_SAL_MENSUALES) si no existe inserta, 
            si existe actualiza y en base a la misma actualiza los saldos Mensuales en la tabla CC_SAL_MENSUALES y AH_SAL_MENSUALES */

         BEGIN
             SELECT DISTINCT 'S'
               INTO V_EXI_CUENTA
               FROM GE_SAL_MENSUALES
              WHERE NRO_CUENTA = C.NRO_CUENTA
                AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
                AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY');
          EXCEPTION
             WHEN OTHERS THEN
               V_EXI_CUENTA := 'N';
          END;

             
          IF NVL(V_EXI_CUENTA, 'N') = 'N' THEN
             INSERT INTO GE_SAL_MENSUALES 
             (COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, ANO, MES, CAN_DEBITOS, CAN_CREDITOS, TOT_DEBITOS, TOT_CREDITOS, SAL_INI_MES, SAL_FIN_MES)
             VALUES
             (C.COD_MODULO, C.COD_MODALIDAD, C.COD_OFICINA, C.NRO_CUENTA, TO_CHAR(V_FEC_ACTUAL,'YYYY'), TO_CHAR(V_FEC_ACTUAL,'MM'), 
              C.CAN_DEBITO, C.CAN_CREDITO, C.TOT_DEBITO, C.TOT_CREDITO, NVL(V_SAL_INI_MES,0), 
              NVL(V_SAL_INI_MES,0) - NVL(C.TOT_DEBITO,0) + NVL(C.TOT_CREDITO,0));
          ELSE
             UPDATE GE_SAL_MENSUALES
                SET CAN_DEBITOS  = NVL(CAN_DEBITOS,0) + NVL(C.CAN_DEBITO,0) + NVL(C.CAN_REV_DEBITO,0),
                    CAN_CREDITOS = NVL(CAN_CREDITOS,0) + NVL(C.CAN_CREDITO,0) + NVL(C.CAN_REV_CREDITO,0),
                    TOT_DEBITOS  = NVL(TOT_DEBITOS,0) + NVL(C.TOT_DEBITO,0)  ,
                    TOT_CREDITOS = NVL(TOT_CREDITOS,0) + NVL(C.TOT_CREDITO,0) ,
                    SAL_INI_MES  = NVL(V_SAL_INI_MES, 0),
                    SAL_FIN_MES  = NVL(V_SAL_INI_MES, 0) + NVL(TOT_CREDITOS,0) - NVL(TOT_DEBITOS,0) + NVL(C.TOT_CREDITO, 0) - NVL(C.TOT_DEBITO, 0) 
              WHERE NRO_CUENTA = C.NRO_CUENTA
                AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
                AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY');                
          END IF;       
             
          BEGIN
            SELECT CAN_DEBITOS, CAN_CREDITOS, TOT_DEBITOS, TOT_CREDITOS, SAL_FIN_MES
              INTO V_CAN_DEBITOS, V_CAN_CREDITOS, V_TOT_DEBITOS, V_TOT_CREDITOS, V_SAL_FIN_MES
              FROM GE_SAL_MENSUALES
             WHERE NRO_CUENTA = C.NRO_CUENTA
               AND MES = TO_CHAR(V_FEC_ACTUAL,'MM')
               AND ANO = TO_CHAR(V_FEC_ACTUAL,'YYYY');   
          EXCEPTION
            WHEN OTHERS THEN 
               V_CAN_DEBITOS := 0;
               V_CAN_CREDITOS := 0; 
               V_TOT_DEBITOS := 0;
               V_TOT_CREDITOS := 0;
          END;
                   
         
          UPDATE CC_SAL_MENSUALES AH
             SET CAN_DEBITOS  = NVL(V_CAN_DEBITOS,0),
                 CAN_CREDITOS = NVL(V_CAN_CREDITOS,0),
                 TOT_DEBITOS  = NVL(V_TOT_DEBITOS,0),
                 TOT_CREDITOS = NVL(V_TOT_CREDITOS,0),
                 SAL_INI_MES  = NVL(V_SAL_INI_MES, 0)
           WHERE AH.NRO_CUENTA   = C.NRO_CUENTA
             AND AH.ANO          = TO_CHAR(V_FEC_ACTUAL,'YYYY')
             AND AH.MES          = TO_CHAR(V_FEC_ACTUAL,'MM'  );
       END LOOP;
    END IF;

END;
/

