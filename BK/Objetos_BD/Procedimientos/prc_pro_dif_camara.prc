CREATE OR REPLACE PROCEDURE IT.PRC_PRO_DIF_CAMARA
 IS
 /* Procesa las diferencias de camara */
V_TPASIEN GE_TIP_ASIENTOS.COD_TIP_ASIENTO%TYPE;
V_NRSECUE GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE;
RV_GCALE GE_CALENDARIOS%ROWTYPE;
V_CDMODAL GE_CUENTAS.COD_MODALIDAD%TYPE;
V_CDMODUL GE_CUENTAS.COD_MODULO%TYPE;
V_CDTRANS GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
V_CDUSUAR GE_MOVIMIENTOS.COD_USUARIO%TYPE;
V_FCANTER DATE;
V_FCDEHOY DATE;
V_FCPROXI GE_CALENDARIOS.FEC_PROXIMA%TYPE;
V_HORA GE_MOVIMIENTOS.HORA%TYPE;
V_COD_MON_LOCAL VARCHAR2(4) := PAG_GEN.FU_OBT_MON_LOCAL;
V_PRO_ALT_VALOR VARCHAR2(1);
-- Actualizacion de saldos totales de cheques
PROCEDURE LP_ACT_SAL_SISTEMAS IS
CURSOR che_recibidos IS
 SELECT CCR.COD_OFI_CAMARA COD_OFI_CAMARA, 'N' TIP_PROCESO, SUM(CCR.MONTO) MONTO, CCR.TIP_IMPORTE
   FROM CC_CHE_RECIBIDOS CCR
  WHERE CCR.FEC_PROCESO = V_FCDEHOY
    AND CCR.COM_DIRECTA = 'N'
    AND CCR.TIP_IMPORTE = 1
    AND V_PRO_ALT_VALOR = 'S'
  GROUP BY CCR.COD_OFI_CAMARA, CCR.TIP_IMPORTE
 UNION
 SELECT CCR.COD_OFI_CAMARA COD_OFI_CAMARA, 'N' TIP_PROCESO, SUM(CCR.MONTO) MONTO, CCR.TIP_IMPORTE
   FROM CC_CHE_RECIBIDOS CCR
  WHERE CCR.FEC_PROCESO = V_FCANTER
    AND COM_DIRECTA = 'N'
    AND CCR.TIP_IMPORTE = 0
  GROUP BY CCR.COD_OFI_CAMARA, CCR.TIP_IMPORTE  
 UNION
 SELECT CCR.COD_OFI_CAMARA COD_OFI_CAMARA, 'R' TIP_PROCESO, SUM(CCR.MONTO) MONTO, CCR.TIP_IMPORTE
   FROM CC_CHE_RECIBIDOS CCR
  WHERE CCR.FEC_PROCESO      = V_FCDEHOY
    AND NVL(CCR.EST_CHEQUE,'R') = 'R'
    AND COM_DIRECTA = 'N'
    AND V_PRO_ALT_VALOR = 'S'
    AND CCR.TIP_IMPORTE = 1
    AND NOT EXISTS (SELECT 1
                      FROM CC_CHE_DEVUELTOS D
                     WHERE D.NRO_CUENTA = CCR.NRO_CUENTA
                       AND D.NRO_CHEQUE = CCR.NRO_CHEQUE
                       AND D.FECHA = CCR.FEC_PROCESO
                       AND D.DEV_COM_DIRECTA = 'S')
  GROUP BY CCR.COD_OFI_CAMARA, CCR.TIP_IMPORTE
UNION   
 SELECT CCR.COD_OFI_CAMARA COD_OFI_CAMARA, 'R' TIP_PROCESO, SUM(CCR.MONTO) MONTO, CCR.TIP_IMPORTE
   FROM CC_CHE_RECIBIDOS CCR
  WHERE CCR.FEC_PROCESO      = V_FCANTER
    AND NVL(CCR.EST_CHEQUE,'R') = 'R'
    AND COM_DIRECTA = 'N'
    AND CCR.TIP_IMPORTE = 0
    AND NOT EXISTS (SELECT 1
                      FROM CC_CHE_DEVUELTOS D
                     WHERE D.NRO_CUENTA = CCR.NRO_CUENTA
                       AND D.NRO_CHEQUE = CCR.NRO_CHEQUE
                       AND D.FECHA = CCR.FEC_PROCESO
                       AND D.DEV_COM_DIRECTA = 'S')
  GROUP BY CCR.COD_OFI_CAMARA, CCR.TIP_IMPORTE;
CURSOR che_remitidos IS
 SELECT CCR.COD_OFICINA COD_OFI_CAMARA, 'N' TIP_PROCESO, SUM(CCR.MONTO) MONTO, 1 TIP_IMPORTE
   FROM CC_CHE_REMITIDOS CCR
  WHERE CCR.FECHA     = V_FCDEHOY
    AND NVL(CCR.TIP_DATO, 1) = 1
    AND CCR.RETENCION = '00'
    AND V_PRO_ALT_VALOR = 'S'
  GROUP BY CCR.COD_OFICINA
 UNION 
 SELECT CCR.COD_OFICINA COD_OFI_CAMARA, 'N' TIP_PROCESO, SUM(CCR.MONTO) MONTO, 0 TIP_IMPORTE
   FROM CC_CHE_REMITIDOS CCR
  WHERE CCR.FECHA     = V_FCANTER
    AND NVL(CCR.TIP_DATO, 1) = 1
    AND CCR.RETENCION = '24'
  GROUP BY CCR.COD_OFICINA 
 UNION
 SELECT CCR.COD_OFICINA COD_OFI_CAMARA, 'R' TIP_PROCESO, SUM(CCR.MONTO) MONTO, 1 TIP_IMPORTE
   FROM CC_CHE_REMITIDOS CCR
  WHERE CCR.FECHA     = V_FCDEHOY
    AND COD_CAU_DEVOLUCION IS NOT NULL
    AND NVL(CCR.TIP_DATO, 1) = 1
    AND NVL(DEV_COM_DIRECTA,'N') = 'N'
    AND CCR.RETENCION = '00'
    AND V_PRO_ALT_VALOR = 'S'
  GROUP BY CCR.COD_OFICINA
 UNION
 SELECT CCR.COD_OFICINA COD_OFI_CAMARA, 'R' TIP_PROCESO, SUM(CCR.MONTO) MONTO, 0 TIP_IMPORTE
   FROM CC_CHE_REMITIDOS CCR
  WHERE CCR.FECHA     = V_FCANTER
    AND COD_CAU_DEVOLUCION IS NOT NULL
    AND NVL(CCR.TIP_DATO, 1) = 1
    AND NVL(DEV_COM_DIRECTA,'N') = 'N'
    AND CCR.RETENCION = '24'
  GROUP BY CCR.COD_OFICINA ;
BEGIN
  --
  UPDATE CC_SAL_CAMARA
     SET SIS_CHE_RECIBIDOS = 0,
         SIS_CHE_DEV_A_CAMARA = 0,
         SIS_CHE_ENVIADOS = 0,
         SIS_CHE_DEV_CAMARA = 0
  WHERE COD_MONEDA = V_COD_MON_LOCAL
    AND FECHA = V_FCDEHOY;
  -- CHEQUES RECIBIDOS
  FOR CR IN  CHE_RECIBIDOS LOOP
      IF CR.TIP_PROCESO <> 'R' THEN
         -- cheques recibidos
         UPDATE CC_SAL_CAMARA
            SET SIS_CHE_RECIBIDOS = CR.MONTO
          WHERE COD_OFI_CAMARA = CR.COD_OFI_CAMARA
            AND TIP_IMPORTE = CR.TIP_IMPORTE
            AND COD_MONEDA = V_COD_MON_LOCAL
            AND FECHA = V_FCDEHOY;
         IF SQL%NOTFOUND THEN
            INSERT INTO CC_SAL_CAMARA
                (COD_OFI_CAMARA, TIP_IMPORTE, COD_MONEDA, FECHA, SIS_CHE_RECIBIDOS)
            VALUES(CR.COD_OFI_CAMARA, CR.TIP_IMPORTE, V_COD_MON_LOCAL, V_FCDEHOY, CR.MONTO);
         END IF;
      ELSE
         -- cheques recibidOS Rechazados
         UPDATE CC_SAL_CAMARA
            SET SIS_CHE_DEV_A_CAMARA = CR.MONTO
          WHERE COD_OFI_CAMARA = CR.COD_OFI_CAMARA
            AND TIP_IMPORTE = CR.TIP_IMPORTE
            AND COD_MONEDA = V_COD_MON_LOCAL
            AND FECHA = V_FCDEHOY;
         IF SQL%NOTFOUND THEN
            INSERT INTO CC_SAL_CAMARA
                (COD_OFI_CAMARA, TIP_IMPORTE, COD_MONEDA, FECHA, SIS_CHE_DEV_A_CAMARA)
            VALUES(CR.COD_OFI_CAMARA, CR.TIP_IMPORTE, V_COD_MON_LOCAL, V_FCDEHOY, CR.MONTO);
         END IF;
      END IF;
  END LOOP;
  -- CHEQUES REMITIDOS
  FOR CR IN CHE_REMITIDOS LOOP
      IF CR.TIP_PROCESO <> 'R' THEN
         -- cheques recibidos
         UPDATE CC_SAL_CAMARA
            SET SIS_CHE_ENVIADOS = CR.MONTO
          WHERE COD_OFI_CAMARA = CR.COD_OFI_CAMARA
            AND TIP_IMPORTE = CR.TIP_IMPORTE
            AND COD_MONEDA = V_COD_MON_LOCAL
            AND FECHA = V_FCDEHOY;
         IF SQL%NOTFOUND THEN
            INSERT INTO CC_SAL_CAMARA
                (COD_OFI_CAMARA, TIP_IMPORTE, COD_MONEDA, FECHA, SIS_CHE_ENVIADOS)
            VALUES(CR.COD_OFI_CAMARA, CR.TIP_IMPORTE, V_COD_MON_LOCAL, V_FCDEHOY, CR.MONTO);
         END IF;
      ELSE
         -- cheques recibidOS Rechazados
         UPDATE CC_SAL_CAMARA
            SET SIS_CHE_DEV_CAMARA = CR.MONTO
          WHERE COD_OFI_CAMARA = CR.COD_OFI_CAMARA
            AND TIP_IMPORTE = CR.TIP_IMPORTE
            AND COD_MONEDA = V_COD_MON_LOCAL
            AND FECHA = V_FCDEHOY;
         IF SQL%NOTFOUND THEN
            INSERT INTO CC_SAL_CAMARA
                (COD_OFI_CAMARA, TIP_IMPORTE, COD_MONEDA, FECHA, SIS_CHE_DEV_CAMARA)
            VALUES(CR.COD_OFI_CAMARA, CR.TIP_IMPORTE, V_COD_MON_LOCAL, V_FCDEHOY, CR.MONTO);
         END IF;
      END IF;
  END LOOP;

END;
-- Genera los movimentos contables respectivos
PROCEDURE LP_GEN_MOV_CON
        (P_CDMODUL IN NUMBER,
         P_CDMODAL IN NUMBER,
         P_CDOFICI IN NUMBER,
         P_CDOFIOR IN NUMBER,
         P_CDMONED IN VARCHAR2,
         P_CDMODUP IN NUMBER,
         P_CDMODAP IN NUMBER,
         P_CDTRANS IN NUMBER,
         P_CONCEPT IN VARCHAR2,
         P_IMTRANS IN NUMBER) IS
CURSOR OP_AS IS
  SELECT TIP_MOVIMIENTO, COD_RUBRO
    FROM GE_TIP_ASIENTOS
   WHERE COD_TIP_ASIENTO = V_TPASIEN
     AND COD_MONEDA = P_CDMONED
     AND (COD_SEC_CONTABLE IS NULL OR COD_SEC_CONTABLE IN ('I','F','N'))
     AND IND_DEUDOR = 'N';
BEGIN
    SELECT COD_TIP_ASIENTO
      INTO V_TPASIEN
      FROM GE_TRANSACCIONES
     WHERE COD_MODULO      = V_CDMODUL
       AND COD_MODALIDAD   = V_CDMODAL
       AND COD_TRANSACCION = P_CDTRANS;
    IF V_TPASIEN IS NULL THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR. Tipo de Asiento nulo: Trans. '||v_cdmodul||'-'||v_cdmodal||TO_CHAR(P_CDTRANS));
    END IF;
    FOR MM IN OP_AS LOOP
        V_NRSECUE := NVL(V_NRSECUE,0) +1;
        
        -- DYDMR-1827 - ITGF - Error Cierre 2 PRC_PRO_DIF_CAMARA - SC 15857 - PN 05/05/2015
        IF V_NRSECUE > 990 THEN
           V_HORA    := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
           V_NRSECUE := 1;
        END IF;

        
        INSERT INTO GE_MOVIMIENTOS
           (COD_USUARIO, HORA, NRO_SECUENCIA, COD_MODULO,
            COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA, COD_TRA_PADRE,
            COD_TRANSACCION, FECHA, FEC_VALOR, MONTO, ESTADO,
            EMI_AVISO, CONCEPTO, COD_OFI_ORIGEN, COD_MOD_PADRE, COD_MAD_PADRE,
            REVERSADO, PROTEGIDO, TIP_MOV_RUBRO, COD_RUBRO,COTIZACION, MTO_EQU_LOCAL)
        VALUES
           (V_CDUSUAR, V_HORA, V_NRSECUE,
            P_CDMODUL, P_CDMODAL, P_CDOFICI, NULL,
            P_CDMONED, V_CDTRANS, P_CDTRANS, V_FCDEHOY,
            V_FCDEHOY, P_IMTRANS, 'N', 'N', SUBSTR(P_CONCEPT,1,35),
            P_CDOFIOR, P_CDMODUP,P_CDMODAP,'N','N',
            MM.TIP_MOVIMIENTO,MM.COD_RUBRO,NULL, NULL);
    END LOOP;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. No existe Transaccion p/ '||v_cdmodul||'-'||v_cdmodal||TO_CHAR(V_CDTRANS));
  WHEN TOO_MANY_ROWS THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. Existen varias transacc. '||v_cdmodul||'-'||V_cdmodal||TO_CHAR(V_CDTRANS));
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000,SQLERRM);
END;

-- cheques rechazados en el proceso mismo
PROCEDURE LP_GEN_CHEQ_NO_PROC_DEL_DIA IS
  CURSOR MOVIMIEN IS
 SELECT CCR.COD_OFI_CAMARA, NVL(GEB.TIPO,'N'), com_directa, SUM(CCR.MONTO),
        G.COD_MONEDA
   FROM CC_CHE_RECIBIDOS CCR , GE_BANCOS GEB,
        GE_CUENTAS G
  WHERE CCR.FEC_PROCESO      = V_FCDEHOY
    AND CCR.COD_BCO_RECEPTOR = GEB.COD_BANCO
    AND NVL(CCR.EST_CHEQUE,'R') = 'R'
    AND CCR.NRO_CUENTA          = G.NRO_CUENTA  -- AP 993 - SDC
    AND NOT EXISTS (SELECT 0 FROM GE_MOVIMIENTOS X
                      WHERE X.NRO_DOCUMENTO = CCR.NRO_CHEQUE
                        AND X.COD_TRA_PADRE = 322
                        AND X.COD_TRANSACCION NOT IN (628,629)
                        AND X.REVERSADO = 'N'
                        AND X.ESTADO = 'N')
  GROUP BY CCR.COD_OFI_CAMARA, NVL(GEB.TIPO,'N'), com_directa, G.COD_MONEDA;
  V_CDOFCMB        cc_che_recibidos.cod_ofi_camara%type;
  V_CDMONED        ba_monedas.cod_moneda%type;
  V_TPBANCO        VARCHAR2(01);
  V_IMTRANS        cc_che_recibidos.monto%type;
  V_COM_DIRECTA    VARCHAR2(1);
  V_COD_MODALIDAD  NUMBER(5);
BEGIN
    --V_CDMONED := pag_gen.fu_obt_mon_local; -- AP 993 - SDC
    IF MOVIMIEN%ISOPEN THEN
     CLOSE MOVIMIEN;
    END IF;
    ------------------------- LEER MOVIMIEN ------------------------------
    OPEN MOVIMIEN;
    --- Transaccion padre: Cheques devueltos ---
    V_CDTRANS := 322;
    LOOP
       FETCH MOVIMIEN INTO V_CDOFCMB, V_TPBANCO, V_COM_DIRECTA, V_IMTRANS, V_CDMONED;
       EXIT WHEN MOVIMIEN%NOTFOUND;
       ---------------------------------------------------------
       ---       GENERA CHEQUES DEVUELTOS DIA ANTERIOR        --
       ---------------------------------------------------------
       -- TOTAL DE CHEQUES DE BANCOS OFICIALES TIPO DE BANCO = O
       ---------------------------------------------------------
       IF V_COM_DIRECTA = 'S' THEN
          v_cod_modalidad := 42;
       ELSE
          v_cod_modalidad := 41;
       END IF;
       IF V_TPBANCO = 'O' THEN
          LP_GEN_MOV_CON  (4, V_COD_MODALIDAD, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, V_COD_MODALIDAD, 628,
                           '628-Ch.Dev.Bcos Ofic.(No Proc.)',
                           V_IMTRANS);
       END IF;
       ----------------------------------------------------------
       -- TOTAL DE CHEQUES DE BANCOS PRIVADOS TIPO DE BANCO = 'N'
       ----------------------------------------------------------
       IF V_TPBANCO = 'N' THEN
          LP_GEN_MOV_CON  (4, V_COD_MODALIDAD, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, V_COD_MODALIDAD, 629,
                           '629-Ch.Dev. Bcos Priv.(No proc.)',
                           V_IMTRANS);
       END IF;
       END LOOP;
    CLOSE MOVIMIEN;
    --- restauro la transaccion padre ---
    V_CDTRANS := 193;
END;

-- Procesa las diferencias del dia
PROCEDURE LP_GEN_MOV_DIF_DEL_DIA IS
  V_CDOFCMB        CC_SAL_CAMARA.COD_OFI_CAMARA%type;
  V_CDMONED        CC_SAL_CAMARA.COD_MONEDA%type;
  V_FCSALDO        DATE;
  V_CACSBCP        CC_SAL_CAMARA.BCP_CHE_ENVIADOS%type;
  V_CRCSBCP        CC_SAL_CAMARA.BCP_CHE_ENVIADOS%type;
  V_RACSBCP        CC_SAL_CAMARA.BCP_CHE_ENVIADOS%type;
  V_RRCSBCP        CC_SAL_CAMARA.BCP_CHE_ENVIADOS%type;
  V_TIPOIMP        CC_SAL_CAMARA.TIP_IMPORTE%type;
  V_CONCEPT        GE_MOVIMIENTOS.CONCEPTO%type;
  --V_CACSINT        CC_SAL_CAMARA.BCP_CHE_ENVIADOS%type;
  CURSOR MOVIMIEN IS
   SELECT COD_OFI_CAMARA, COD_MONEDA, FECHA,
          NVL(BCP_CHE_ENVIADOS,0) - NVL(SIS_CHE_ENVIADOS,0),
          NVL(BCP_CHE_RECIBIDOS,0) - NVL(SIS_CHE_RECIBIDOS,0),
          NVL(BCP_CHE_DEV_CAMARA,0) - NVL(SIS_CHE_DEV_CAMARA,0),
          NVL(BCP_CHE_DEV_A_CAMARA,0) - NVL(SIS_CHE_DEV_A_CAMARA,0),
          TIP_IMPORTE
     FROM CC_SAL_CAMARA
    WHERE FECHA = V_FCDEHOY;
------------------------------------------------------------------------
BEGIN
    IF MOVIMIEN%ISOPEN THEN
     CLOSE MOVIMIEN;
    END IF;
    ------------------------- LEER MOVIMIEN ------------------------------
    OPEN MOVIMIEN;
    LOOP
       FETCH MOVIMIEN INTO V_CDOFCMB, V_CDMONED, V_FCSALDO,
                           V_CACSBCP, V_CRCSBCP, V_RACSBCP, V_RRCSBCP, V_TIPOIMP;
       EXIT WHEN MOVIMIEN%NOTFOUND;
       ------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES A COMPENSAR --
       ------------------------------------------------
       IF NVL(V_CACSBCP,0) < 0 THEN
          IF V_TIPOIMP = 0 THEN
             V_CONCEPT := '618-Dif.Cheques a Comp.- Bajo Valor';
          ELSE
             V_CONCEPT := '618-Dif.Cheques a Comp.- Alto Valor';
          END IF;      
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 618,
                           V_CONCEPT,
                           ABS(V_CACSBCP));
       END IF;
       IF NVL(V_CACSBCP,0) > 0 THEN
          IF V_TIPOIMP = 0 THEN
             V_CONCEPT := '619-Dif.Cheques a Comp.- Bajo Valor';
          ELSE
             V_CONCEPT := '619-Dif.Cheques a Comp.- Alto Valor';
          END IF;
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 619,
                           V_CONCEPT,
                           V_CACSBCP);
       END IF;
       --------------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES RECIBIDOS DE CAMARA --
       --------------------------------------------------------
       IF NVL(V_CRCSBCP,0) < 0 THEN
          IF V_TIPOIMP = 0 THEN
             V_CONCEPT := '620-Dif.Cheque Recib. - Bajo Valor';
          ELSE
             V_CONCEPT := '620-Dif.Cheque Recib. - Alto Valor';
          END IF;
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 620,
                           V_CONCEPT,
                           ABS(V_CRCSBCP));
       END IF;
       IF NVL(V_CRCSBCP,0) > 0 THEN
          IF V_TIPOIMP = 0 THEN
             V_CONCEPT := '621-Dif.Cheque Recib. - Bajo Valor';
          ELSE
             V_CONCEPT := '621-Dif.Cheque Recib. - Alto Valor';
          END IF;
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 621,
                           V_CONCEPT,
                           V_CRCSBCP);
       END IF;
       -----------------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES A COMPENSAR RECHAZADOS --
       -----------------------------------------------------------
       IF NVL(V_RACSBCP,0) < 0 THEN
          IF V_TIPOIMP = 0 THEN
             V_CONCEPT := '622-Dif.Che.a Comp. Rech.-Baj Valor';
          ELSE
             V_CONCEPT := '622-Dif.Che.a Comp. Rech.-Alt Valor';
          END IF;
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 622,
                           V_CONCEPT,
                           ABS(V_RACSBCP));
       END IF;
       IF NVL(V_RACSBCP,0) > 0 THEN
          IF V_TIPOIMP = 0 THEN
             V_CONCEPT := '623-Dif.Che.a Comp. Rech.-Baj Valor';
          ELSE
             V_CONCEPT := '623-Dif.Che.a Comp. Rech.-Alt Valor';
          END IF;         
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 623,
                           V_CONCEPT,
                           V_RACSBCP);
       END IF;
       --------------------------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES A RECIBIDO DE CAMARA RECHAZADOS --
       --------------------------------------------------------------------
       IF NVL(V_RRCSBCP,0) < 0 THEN
          IF V_TIPOIMP = 0 THEN
             V_CONCEPT := '624-Dif.Che. Recib. Rech.-Baj Valor';
          ELSE
             V_CONCEPT := '624-Dif.Che. Recib. Rech.-Alt Valor';
          END IF; 
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 624,
                           V_CONCEPT,
                           ABS(V_RRCSBCP));
       END IF;
       IF NVL(V_RRCSBCP,0) > 0 THEN
          IF V_TIPOIMP = 0 THEN
             V_CONCEPT := '625-Dif.Che. Recib. Rech.-Baj Valor';
          ELSE
             V_CONCEPT := '625-Dif.Che. Recib. Rech.-Alt Valor';
          END IF; 
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 625,
                           V_CONCEPT,
                           V_RRCSBCP);
       END IF;
    END LOOP;
    CLOSE MOVIMIEN;
END;
-- cheques devueltos del dia anterior
PROCEDURE LP_GEN_CHEQ_DEV_DIA_ANT IS
  V_CDOFCMB        CC_CHE_RECIBIDOS.COD_OFI_CAMARA%TYPE;
  V_CDMONED        BA_MONEDAS.COD_MONEDA%TYPE;
  V_TPBANCO        GE_BANCOS.TIPO%TYPE;
  V_IMTRANS        CC_CHE_RECIBIDOS.MONTO%TYPE;
  V_FCANTER        DATE;
CURSOR MOVIMIEN IS
 SELECT CCR.COD_OFI_CAMARA, NVL(GEB.TIPO,'N'), SUM(CCR.MONTO)
   FROM GE_BANCOS GEB ,
        CC_CHE_RECIBIDOS CCR
  WHERE CCR.FEC_PROCESO = V_FCANTER
    AND CCR.COD_BCO_RECEPTOR = GEB.COD_BANCO
    AND NVL(CCR.EST_CHEQUE,' ') <> 'P'
    AND NVL(COM_DIRECTA,'N') = 'N'
    AND NOT EXISTS (SELECT 0 FROM GE_MOVIMIENTOS
                     WHERE NRO_CUENTA = CCR.NRO_CUENTA
                       AND COD_TRA_PADRE = 322
                       AND COD_TRANSACCION = 631
                       AND NRO_DOCUMENTO = CCR.NRO_CHEQUE
                       AND COD_MONEDA = V_CDMONED
                       AND MONTO = CCR.MONTO)
  GROUP BY CCR.COD_OFI_CAMARA, NVL(GEB.TIPO,'N');
BEGIN
    IF MOVIMIEN%ISOPEN THEN
     CLOSE MOVIMIEN;
    END IF;
    V_CDMONED := pag_gen.fu_obt_mon_local;
    ---------- CICLO de movimientos rechazados del dia anterior ----------
    OPEN MOVIMIEN;
    /* incluye los cheques no procesado el dia anterior */
    LOOP
       FETCH MOVIMIEN INTO V_CDOFCMB, V_TPBANCO, V_IMTRANS;
       EXIT WHEN MOVIMIEN%NOTFOUND;
       --------------------------------------------
       --- GENERA CHEQUES DEVUELTOS DIA ANTERIOR --
       --------------------------------------------
       -- CHEQUES DEV.BANCOS OFICIALES TPBANCO='O'-
       --------------------------------------------
       IF V_TPBANCO = 'O' AND V_IMTRANS > 0 THEN
          V_CDTRANS := 626;
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 626,
                           '626-Cheq.Dev. Bcos Ofic.(Dian ant)',
                           V_IMTRANS);
       END IF;
       -------------------------------------------
       -- CHEQUES DEV.BANCOS PRIVADOS TPBANCO='N'-
       -------------------------------------------
       IF V_TPBANCO = 'N' AND V_IMTRANS > 0 THEN
          V_CDTRANS := 627;
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 627,
                           '627-Cheq.Dev. Bcos Priv.(Dia ant)',
                           V_IMTRANS);
       END IF;
       END LOOP;
    CLOSE MOVIMIEN;
END;
begin
  V_CDMODUL := 4;
  V_CDMODAL := 41;
  V_CDTRANS := 193;
  V_NRSECUE := 0;
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  V_CDUSUAR := substr(user,1,10);

  -- DYDMR-1827 - ITGF - Error Cierre 2 PRC_PRO_DIF_CAMARA - SC 15857 - PN 05/05/2015
  --V_HORA    := nvl(pae_cnf.G_HORA,fug_ini_hora(SYSDATE,'HH24:MI:SS'));
  v_hora := to_char(sysdate,'hh24:mi:ss');
  v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
  rv_gcale  := pag_cal.fu_obt_reg_cal(4);
  v_FCPROXI := rv_gcale.fec_proxima;
  v_FCANTER := rv_gcale.fec_anterior;
  V_PRO_ALT_VALOR := 'S';
  LP_ACT_SAL_SISTEMAS;          -- actualiza los datos totales de sistema
  LP_GEN_CHEQ_NO_PROC_DEL_DIA; -- cheques no procesados(onp/cc) de cheques recibidos
  LP_GEN_MOV_DIF_DEL_DIA;      -- Genera las diferencias entre boletas bcp y saldos del sistema
  --LP_GEN_CHEQ_DEV_DIA_ANT;     -- cheques devueltos del dia anterior, ya no se usa

  -- Ahora cambio las fechas de hoy y mañana y corro la actualizacion de cc_sal_camara para mañana. Esto es solo para  --
  -- adelantar los controles, porque al dia sgte recien se cierra todo el proceso de Camara.-----------------------------
  V_FCANTER := V_FCDEHOY;
  V_FCDEHOY := V_FCPROXI;
  V_PRO_ALT_VALOR := 'N';
  LP_ACT_SAL_SISTEMAS;
  -----------------------------------------------------------------------------------------------------------------------

end ;
/

