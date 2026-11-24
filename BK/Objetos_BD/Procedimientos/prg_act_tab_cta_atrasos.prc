CREATE OR REPLACE PROCEDURE IT.PRG_ACT_TAB_CTA_ATRASOS(P_NRO_CUENTA in GE_CUENTAS.NRO_CUENTA%TYPE,
P_REVERSADO IN VARCHAR2 DEFAULT 'N',
P_FEC_MOV_ORIGEN in GE_MOVIMIENTOS.FECHA%TYPE DEFAULT NULL,
P_HOR_MOV_ORIGEN in GE_MOVIMIENTOS.HORA%TYPE DEFAULT NULL,
P_COD_USU_MOV_ORIGEN in GE_MOVIMIENTOS.COD_USUARIO%TYPE DEFAULT NULL,
P_COD_TRA_PAD_MOV_ORIGEN in GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE DEFAULT NULL) IS
--Proceso que actualiza la Tabla de control de Clientes con Atrasos.
PRAGMA AUTONOMOUS_TRANSACTION;
V_OPE_FECHA         GE_MOVIMIENTOS.FECHA%TYPE := NULL;
V_OPE_HORA          GE_MOVIMIENTOS.HORA%TYPE:= NULL;
V_OPE_COD_USUARIO   GE_MOVIMIENTOS.COD_USUARIO%TYPE := NULL;
V_COD_MODULO        GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE := NULL;
V_COD_MODALIDAD     GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE := NULL;
V_COD_TRA_PADRE     GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE := NULL;
V_COD_USUARIO       GE_MOVIMIENTOS.COD_USUARIO%TYPE   := UPPER(USER);
V_HOR_ACTUAL        GE_MOVIMIENTOS.HOR_REVERSION%TYPE := TO_CHAR(SYSDATE,'HH24:MI:SS');  
V_MOTIVO            VARCHAR2(100) := '10-REV POR OPERACIÓN CANCELADA/ANULADA';
V_TIP_PERSONA       VARCHAR2(1);
V_TIP_MOVIMIENTO    VARCHAR2(1);
V_COD_TRANSACCION   GE_MOVIMIENTOS.COD_TRANSACCION%TYPE := NULL;
V_ACT_PER_FISICA    VARCHAR2(1) := FUE_OBT_VAL_MAX_REFCODES('TIP_PER_COB_24X7','PER_FIS');
V_ACT_PER_JURIDICA  VARCHAR2(1) := FUE_OBT_VAL_MAX_REFCODES('TIP_PER_COB_24X7','PER_JUR');
BEGIN
   -- BUSCAR EL TIPO DE PERSONA DE LA CTA CREDITO
   BEGIN
     SELECT P.TIPO
       INTO V_TIP_PERSONA
       FROM GE_CTA_CLIENTES C, BA_PERSONAS P
      WHERE C.NRO_CUENTA = P_NRO_CUENTA
        AND C.RELACION = 'P'
        AND C.COD_PERSONA = P.COD_PERSONA;
      EXCEPTION 
         WHEN OTHERS THEN 
                  V_TIP_PERSONA := 'N';
   END;   
   --IF V_TIP_PERSONA = 'F' THEN -- COBRAR SOLO PERSONAS FISICAS
       -- BUSCAR EL TIPO DE MOVIMIENTO DE LA CTA CREDITO
       BEGIN
         SELECT M.COD_TRANSACCION,M.COD_MODULO,T.TIPO
           INTO V_COD_TRANSACCION,V_COD_MODULO,V_TIP_MOVIMIENTO
           FROM GE_MOVIMIENTOS M, GE_TRANSACCIONES T
          WHERE M.FECHA = P_FEC_MOV_ORIGEN
            AND M.HORA  = P_HOR_MOV_ORIGEN
            AND M.COD_USUARIO = P_COD_USU_MOV_ORIGEN
            AND M.NRO_CUENTA = P_NRO_CUENTA
            AND M.COD_TRA_PADRE = P_COD_TRA_PAD_MOV_ORIGEN
            AND M.COD_TRANSACCION = T.COD_TRANSACCION
            AND M.COD_MODULO = T.COD_MODULO
            AND M.COD_MODALIDAD = T.COD_MODALIDAD;
          EXCEPTION 
             WHEN OTHERS THEN 
                     /*Para que no caiga el proceso*/
                      V_TIP_MOVIMIENTO := 'C';
                      V_COD_MODULO     := 4;
       END;
        IF P_REVERSADO = 'N' THEN
           IF (V_COD_MODULO IN (3,4) AND V_TIP_MOVIMIENTO = 'C') OR (V_COD_MODULO IN (3,4) AND P_COD_TRA_PAD_MOV_ORIGEN IN (515,560))  THEN
                  IF V_TIP_PERSONA = 'F' AND V_ACT_PER_FISICA = 'S' THEN
                      BEGIN
                         UPDATE GE_CLI_CTA_ATRASOS A
                            SET A.TIE_DEPOSITO = 'S',
                                A.NRO_CTA_CREDITO = P_NRO_CUENTA,
                                A.FEC_MOV_ORIGEN = P_FEC_MOV_ORIGEN,
                                A.HOR_MOV_ORIGEN = P_HOR_MOV_ORIGEN,
                                A.COD_USU_ORIGEN = P_COD_USU_MOV_ORIGEN,
                                A.COD_TRA_PAD_ORIGEN = P_COD_TRA_PAD_MOV_ORIGEN,
                                A.PROCESADO          = 'N'
                            WHERE A.MTO_MORA > NVL(A.TOT_COBRADO,0)
                              AND (EXISTS (SELECT 0 FROM GE_CTA_CLIENTES C
                                            WHERE C.COD_PERSONA = A.COD_PERSONA
                                              AND C.NRO_CUENTA  = P_NRO_CUENTA
                                              AND C.RELACION IN ('P','O'))
                                              AND A.COD_MONEDA = fug_obt_mon_cta(P_NRO_CUENTA));  
                          EXCEPTION 
                            WHEN OTHERS THEN 
                              NULL;
                      END;
                  ELSIF V_TIP_PERSONA = 'J' AND V_ACT_PER_JURIDICA = 'S' THEN
                     /*SI ES UNA PERSONA JURIDICA*/
                      BEGIN
                         UPDATE GE_CLI_CTA_ATRASOS A
                            SET A.TIE_DEPOSITO = 'S',
                                A.NRO_CTA_CREDITO = P_NRO_CUENTA,
                                A.FEC_MOV_ORIGEN = P_FEC_MOV_ORIGEN,
                                A.HOR_MOV_ORIGEN = P_HOR_MOV_ORIGEN,
                                A.COD_USU_ORIGEN = P_COD_USU_MOV_ORIGEN,
                                A.COD_TRA_PAD_ORIGEN = P_COD_TRA_PAD_MOV_ORIGEN,
                                A.PROCESADO          = 'N'
                            WHERE A.MTO_MORA > NVL(A.TOT_COBRADO,0)
                              AND (EXISTS (SELECT 0 FROM GE_CTA_CLIENTES C, BA_PERSONAS P
                                            WHERE C.COD_PERSONA = A.COD_PERSONA
                                              AND C.NRO_CUENTA  = P_NRO_CUENTA
                                              AND C.RELACION IN ('P')
                                              AND C.COD_PERSONA = P.COD_PERSONA
                                              AND P.TIPO = V_TIP_PERSONA)
                                              AND A.COD_MONEDA = fug_obt_mon_cta(P_NRO_CUENTA));  
                          EXCEPTION 
                            WHEN OTHERS THEN 
                              NULL;
                      END;     
                  END IF;     
            END IF;             
        ELSE
          -- Actualiza la Tabla de control de Clientes con Atrasos.
           BEGIN
              UPDATE GE_CLI_CTA_ATRASOS A
                SET A.TIE_DEPOSITO        = 'N',
                    A.NRO_CTA_CREDITO     = NULL,
                    A.PROCESADO           = 'N',
                    A.TOT_COBRADO         = 0,
                    A.FEC_MOV_ORIGEN      = NULL,
                    A.HOR_MOV_ORIGEN      = NULL,
                    A.COD_USU_ORIGEN      = NULL,
                    A.COD_TRA_PAD_ORIGEN  = NULL,
                    A.FEC_MOV_DEB24X7     = NULL,
                    A.HOR_MOV_DEB24X7     = NULL,
                    A.COD_USU_DEB24X7     = NULL,
                    A.COD_TRA_PAD_DEB24X7 = NULL
              WHERE A.NRO_CTA_CREDITO     = P_NRO_CUENTA
                AND A.FEC_MOV_DEB24X7     = P_FEC_MOV_ORIGEN
                AND A.HOR_MOV_DEB24X7     = P_HOR_MOV_ORIGEN
                AND A.COD_USU_DEB24X7     = P_COD_USU_MOV_ORIGEN
                AND A.COD_TRA_PAD_DEB24X7 = P_COD_TRA_PAD_MOV_ORIGEN;
           EXCEPTION 
              WHEN OTHERS THEN
                NULL;   
           END;                       
        END IF;
   --END IF;         
Commit;
EXCEPTION
  WHEN OTHERS THEN
     ROLLBACK;
END;
/

