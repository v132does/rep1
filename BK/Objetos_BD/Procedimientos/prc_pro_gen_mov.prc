CREATE OR REPLACE PROCEDURE IT.PRC_PRO_GEN_MOV
 IS
V_TPASIEN GE_TIP_ASIENTOS.COD_TIP_ASIENTO%TYPE;
V_CDOFCMB CC_SAL_CAMARA.COD_OFI_CAMARA%TYPE;
V_CDMONED CC_SAL_CAMARA.COD_MONEDA%TYPE;
V_FCSALDO DATE;
V_CACSBCP CC_SAL_CAMARA.BCP_CHE_ENVIADOS%TYPE;
V_CRCSBCP CC_SAL_CAMARA.BCP_CHE_RECIBIDOS%TYPE;
V_RACSBCP CC_SAL_CAMARA.BCP_CHE_DEV_CAMARA%TYPE;
V_RRCSBCP CC_SAL_CAMARA.BCP_CHE_DEV_A_CAMARA%TYPE;
V_CDMODUL GE_CUENTAS.COD_MODULO%TYPE;
V_NRSECUE GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE;
V_CDMODAL GE_CUENTAS.COD_MODALIDAD%TYPE;
V_CDTRANS GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
V_FCDEHOY DATE;
V_CACSINT CC_SAL_CAMARA.BCP_CHE_SUC_ENVIADOS%TYPE;
V_CRCSACT CC_SAL_CAMARA.SIS_CHE_ENVIADOS%TYPE;
V_TOTBANC NUMBER(18, 2);
V_HORA GE_MOVIMIENTOS.HORA%TYPE;
V_CDUSUAR GE_MOVIMIENTOS.COD_USUARIO%TYPE;
---Generación de movimientos por boleta bcp
------------------------- DEFINE MOVIMIEN -----------------------------
CURSOR MOVIMIEN IS
 SELECT COD_OFI_CAMARA, COD_MONEDA, FECHA,
        BCP_CHE_ENVIADOS, BCP_CHE_RECIBIDOS, BCP_CHE_DEV_CAMARA,
        BCP_CHE_DEV_A_CAMARA, BCP_CHE_SUC_ENVIADOS, SIS_CHE_RECIBIDOS
   FROM CC_SAL_CAMARA
  WHERE FECHA = V_FCDEHOY;
------------------------------------------------------------------------
PROCEDURE LP_GEN_MOV_CON
        (P_CDMODUL IN NUMBER,
         P_CDMODAL IN NUMBER,
         P_CDOFICI IN NUMBER,
         P_CDOFIOR IN NUMBER,
         P_CDMONED IN CHAR,
         P_CDMODUP IN NUMBER,
         P_CDMODAP IN NUMBER,
         P_CDTRANS IN NUMBER,
         P_CONCEPT IN CHAR,
         P_IMTRANS IN NUMBER) IS
CURSOR OP_AS IS
  SELECT TIP_MOVIMIENTO, COD_RUBRO
    FROM GE_TIP_ASIENTOS
   WHERE COD_TIP_ASIENTO = V_TPASIEN
     AND COD_MONEDA = P_CDMONED
     AND COD_SEC_CONTABLE = 'N'
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
        INSERT INTO GE_MOVIMIENTOS
           (COD_USUARIO, HORA, NRO_SECUENCIA, COD_MODULO,
            COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA, COD_TRA_PADRE,
            COD_TRANSACCION, FECHA, FEC_VALOR, MONTO, ESTADO,
            EMI_AVISO, CONCEPTO, COD_OFI_ORIGEN, COD_MOD_PADRE, COD_MAD_PADRE,
            REVERSADO, PROTEGIDO, TIP_MOV_RUBRO, COD_RUBRO)
        VALUES
           (V_CDUSUAR, V_HORA, V_NRSECUE,
            P_CDMODUL, P_CDMODAL, P_CDOFICI, NULL,
            P_CDMONED, V_CDTRANS, P_CDTRANS, V_FCDEHOY,
            V_FCDEHOY, P_IMTRANS, 'N', 'N', P_CONCEPT,
            P_CDOFIOR, P_CDMODUP,P_CDMODAP,'N','N',
            MM.TIP_MOVIMIENTO,MM.COD_RUBRO);
    END LOOP;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. No existe Transaccion p/ '||v_cdmodul||'-'||v_cdmodal||TO_CHAR(V_CDTRANS));
  WHEN TOO_MANY_ROWS THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. Existen varias transacc. '||v_cdmodul||'-'||V_cdmodal||TO_CHAR(V_CDTRANS));
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000,SQLERRM);
END;
BEGIN
    V_CDMODUL := 4;
    V_CDMODAL := 41;
    V_CDTRANS := 596;
    V_HORA    := TO_CHAR(SYSDATE,'HH24:MI:SS');
    V_CDUSUAR := substr(user,1,10);
    V_FCDEHOY := pag_cal.fu_obt_fec_actual(4);
    IF MOVIMIEN%ISOPEN THEN
     CLOSE MOVIMIEN;
    END IF;
    ------------------------- LEER MOVIMIEN ------------------------------
    OPEN MOVIMIEN;
    LOOP
       FETCH MOVIMIEN INTO V_CDOFCMB, V_CDMONED, V_FCSALDO,
                           V_CACSBCP, V_CRCSBCP, V_RACSBCP,
                           V_RRCSBCP, V_CACSINT, V_CRCSACT;
       EXIT WHEN MOVIMIEN%NOTFOUND;
       ------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES A COMPENSAR --
       ------------------------------------------------
       IF V_CACSBCP > 0 THEN
       LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                        V_CDOFCMB, V_CDMONED,
                        4, 41, 593,
                        'Cheques a Compensar',
                        V_CACSBCP);
       END IF;
       --------------------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES RECIBIDOS DE CAMARA S/ BCP--
       --------------------------------------------------------------
       IF V_CRCSBCP > 0 THEN
       LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                        V_CDOFCMB, V_CDMONED,
                        4, 41, 616,
                        'Cheque Recibidos de Camara s/BCP',
                        V_CRCSBCP);
       END IF;
       -----------------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES A COMPENSAR RECHAZADOS --
       -----------------------------------------------------------
       IF V_RACSBCP > 0 THEN
       LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                        V_CDOFCMB, V_CDMONED,
                        4, 41, 617,
                        'Cheque a Compensar Rechazados',
                        V_RACSBCP);
       END IF;
       --------------------------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES A RECIBIDO DE CAMARA RECHAZADOS --
       --------------------------------------------------------------------
       IF V_RRCSBCP > 0 THEN
       LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                        V_CDOFCMB, V_CDMONED,
                        4, 41, 594,
                        'Ch. Recibido Camara Rechazados',
                        V_RRCSBCP);
       END IF;
       ---------------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES A RECIBIDO DE CAMARA --
       ---------------------------------------------------------
       IF V_CRCSACT > 0 THEN
          --- busco el total de cheques de bancos---------------
          SELECT SUM(MONTO) INTO V_TOTBANC
            FROM GE_MOVIMIENTOS GEM,
                 BA_OFICINAS  BAO
           WHERE GEM.COD_MODULO = 4
             AND GEM.COD_MODALIDAD = 42
             AND GEM.COD_TRANSACCION = 521
             AND GEM.REVERSADO = 'N'
             AND GEM.ESTADO IN ('N','H')
             AND GEM.COD_MONEDA = V_CDMONED
             AND BAO.COD_OFICINA = GEM.COD_OFI_ORIGEN
             AND BAO.COD_OFI_CAMBIO = V_CDOFCMB;
          --- genero por el total de cheques de bancos ---------
          IF NVL(V_TOTBANC,0) > 0 THEN
            LP_GEN_MOV_CON  (4, 42, V_CDOFCMB,
                             V_CDOFCMB, V_CDMONED,
                             4, 42, 630,
                             'Ch. Rec.Camara s/Sist.(Bancos)',
                             V_TOTBANC);
          END IF;
          --- resto al total de cheq.los de bcos. y genero mov.-
          V_CRCSACT := NVL(V_CRCSACT,0) - NVL(V_TOTBANC,0);
          IF NVL(V_CRCSACT,0) > 0 THEN
            LP_GEN_MOV_CON (4, 41, V_CDOFCMB,
                            V_CDOFCMB, V_CDMONED,
                            4, 41, 630,
                            'Ch. Recibido Camara s/sistemas',
                            V_CRCSACT);
          END IF;
          ------------------------------------------------------
       END IF;
       ------------------------------------------------------------
    END LOOP;
    CLOSE MOVIMIEN;
END;
/

