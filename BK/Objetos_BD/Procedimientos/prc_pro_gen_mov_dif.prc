CREATE OR REPLACE PROCEDURE IT.PRC_PRO_GEN_MOV_DIF
 IS
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
PROCEDURE LP_GEN_CHEQ_NO_PROC_DEL_DIA IS
  CURSOR MOVIMIEN IS
 SELECT CCR.COD_OFI_CAMARA, NVL(GEB.TIPO,'N'), SUM(CCR.MONTO)
   FROM CC_CHE_RECIBIDOS CCR , GE_BANCOS GEB
  WHERE CCR.FEC_PROCESO      = V_FCDEHOY
    AND CCR.COD_BCO_RECEPTOR = GEB.COD_BANCO
    AND CCR.EST_CHEQUE IS NULL
  GROUP BY CCR.COD_OFI_CAMARA, NVL(GEB.TIPO,'N');
  V_CDOFCMB        cc_che_recibidos.cod_ofi_camara%type;
  V_CDMONED        ba_monedas.cod_moneda%type;
  V_TPBANCO        VARCHAR2(01);
  V_IMTRANS        cc_che_recibidos.monto%type;
BEGIN
    V_CDMONED := pag_gen.fu_obt_mon_local;
    IF MOVIMIEN%ISOPEN THEN
     CLOSE MOVIMIEN;
    END IF;
    ------------------------- LEER MOVIMIEN ------------------------------
    OPEN MOVIMIEN;
    --- Transaccion padre: Cheques devueltos ---
    V_CDTRANS := 322;
    LOOP
       FETCH MOVIMIEN INTO V_CDOFCMB, V_TPBANCO, V_IMTRANS;
       EXIT WHEN MOVIMIEN%NOTFOUND;
       -----------------------------------------------------------
       --- ACTUALIZO LA TABLA CC_SAL_CAMARA COMO INGRESADO EN EL DIA  --
       -----------------------------------------------------------
       UPDATE CC_SAL_CAMARA
          SET SIS_CHE_RECIBIDOS = NVL(SIS_CHE_RECIBIDOS,0) + NVL(V_IMTRANS,0)
        WHERE COD_OFI_CAMARA = V_CDOFCMB
          AND COD_MONEDA = V_CDMONED
          AND FECHA = V_FCDEHOY;
       IF SQL%NOTFOUND THEN
          INSERT INTO CC_SAL_CAMARA(COD_OFI_CAMARA,COD_MONEDA,FECHA,SIS_CHE_RECIBIDOS)
                             VALUES(V_CDOFCMB, V_CDMONED, V_FCDEHOY,V_IMTRANS);
       END IF;
       -----------------------------------------------------------
       --- ACTUALIZO LA TABLA CC_SAL_CAMARA COMO RECHAZADO DEL DIA SGTE.
       -----------------------------------------------------------
       UPDATE CC_SAL_CAMARA
          SET SIS_CHE_DEV_A_CAMARA = NVL(SIS_CHE_DEV_A_CAMARA,0) + NVL(V_IMTRANS,0)
        WHERE COD_OFI_CAMARA = V_CDOFCMB
          AND COD_MONEDA = V_CDMONED
          AND FECHA = V_FCPROXI;
       IF SQL%NOTFOUND THEN
          INSERT INTO CC_SAL_CAMARA(COD_OFI_CAMARA,COD_MONEDA,FECHA,SIS_CHE_DEV_A_CAMARA)
                            VALUES (V_CDOFCMB, V_CDMONED, V_FCPROXI,V_IMTRANS);
       END IF;
       ---------------------------------------------------------
       ---       GENERA CHEQUES DEVUELTOS DIA ANTERIOR        --
       ---------------------------------------------------------
       -- TOTAL DE CHEQUES DE BANCOS OFICIALES TIPO DE BANCO = O
       ---------------------------------------------------------
       IF V_TPBANCO = 'O' THEN
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 628,
                           'Cheq. Dev.Bcos Ofic.(No Proc.)',
                           V_IMTRANS);
       END IF;
       ----------------------------------------------------------
       -- TOTAL DE CHEQUES DE BANCOS PRIVADOS TIPO DE BANCO = 'N'
       ----------------------------------------------------------
       IF V_TPBANCO = 'N' THEN
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 629,
                           'Cheq.Dev. Bcos Priv.(No proc.)',
                           V_IMTRANS);
       END IF;
       END LOOP;
    CLOSE MOVIMIEN;
    --- restauro la transaccion padre ---
    V_CDTRANS := 618;
END;
PROCEDURE LP_GEN_MOV_DIF_DEL_DIA IS
  V_CDOFCMB        CC_SAL_CAMARA.COD_OFI_CAMARA%type;
  V_CDMONED        CC_SAL_CAMARA.COD_MONEDA%type;
  V_FCSALDO        DATE;
  V_CACSBCP        CC_SAL_CAMARA.BCP_CHE_ENVIADOS%type;
  V_CRCSBCP        CC_SAL_CAMARA.BCP_CHE_ENVIADOS%type;
  V_RACSBCP        CC_SAL_CAMARA.BCP_CHE_ENVIADOS%type;
  V_RRCSBCP        CC_SAL_CAMARA.BCP_CHE_ENVIADOS%type;
  V_CACSINT        CC_SAL_CAMARA.BCP_CHE_ENVIADOS%type;
  CURSOR MOVIMIEN IS
   SELECT COD_OFI_CAMARA, COD_MONEDA, FECHA,
          NVL(BCP_CHE_ENVIADOS,0) - (NVL(SIS_CHE_ENVIADOS,0)+NVL(SIS_CHE_SUC_ENVIADOS,0)),
          NVL(BCP_CHE_RECIBIDOS,0) - NVL(SIS_CHE_RECIBIDOS,0),
          NVL(BCP_CHE_DEV_CAMARA,0) - NVL(SIS_CHE_DEV_CAMARA,0),
          NVL(BCP_CHE_DEV_A_CAMARA,0) - NVL(SIS_CHE_DEV_A_CAMARA,0)
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
                           V_CACSBCP, V_CRCSBCP, V_RACSBCP, V_RRCSBCP;
       EXIT WHEN MOVIMIEN%NOTFOUND;
       ------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES A COMPENSAR --
       ------------------------------------------------
       IF NVL(V_CACSBCP,0) < 0 THEN
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 618,
                           'Dif.Cheques a Compensar',
                           ABS(V_CACSBCP));
       END IF;
       IF NVL(V_CACSBCP,0) > 0 THEN
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 619,
                           'Dif.Cheques a Compensar',
                           V_CACSBCP);
       END IF;
       --------------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES RECIBIDOS DE CAMARA --
       --------------------------------------------------------
       IF NVL(V_CRCSBCP,0) < 0 THEN
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 620,
                           'Dif.Cheque Recib.de Camara',
                           ABS(V_CRCSBCP));
       END IF;
       IF NVL(V_CRCSBCP,0) > 0 THEN
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 621,
                           'Dif.Cheque Recib.de Camara',
                           V_CRCSBCP);
       END IF;
       -----------------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES A COMPENSAR RECHAZADOS --
       -----------------------------------------------------------
       IF NVL(V_RACSBCP,0) < 0 THEN
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 622,
                           'Dif.Cheque a Compensar Rechaz.',
                           ABS(V_RACSBCP));
       END IF;
       IF NVL(V_RACSBCP,0) > 0 THEN
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 623,
                           'Dif.Cheque a Compensar Rechaz.',
                           V_RACSBCP);
       END IF;
       --------------------------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES A RECIBIDO DE CAMARA RECHAZADOS --
       --------------------------------------------------------------------
       IF NVL(V_RRCSBCP,0) < 0 THEN
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 624,
                           'Dif.Ch. Recibido Camara Rechaz.',
                           ABS(V_RRCSBCP));
       END IF;
       IF NVL(V_RRCSBCP,0) > 0 THEN
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_CDOFCMB, V_CDMONED,
                           4, 41, 625,
                           'Dif.Ch. Recibido Camara Rechaz.',
                           V_RRCSBCP);
       END IF;
    END LOOP;
    CLOSE MOVIMIEN;
END;
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
                           'Cheq.Dev. Bcos Ofic.(Dian ant)',
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
                           'Cheq.Dev. Bcos Priv.(Dia ant)',
                           V_IMTRANS);
       END IF;
       END LOOP;
    CLOSE MOVIMIEN;
END;
begin
  V_CDMODUL := 4;
  V_CDMODAL := 41;
  V_CDTRANS := 618;
  V_NRSECUE := 0;
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  V_CDUSUAR := substr(user,1,10);
  V_HORA    := TO_CHAR(SYSDATE,'HH24:MI:SS');
  rv_gcale  := pag_cal.fu_obt_reg_cal(4);
  v_FCPROXI := rv_gcale.fec_proxima;
  v_FCANTER := rv_gcale.fec_anterior;
  LP_GEN_CHEQ_NO_PROC_DEL_DIA;
  LP_GEN_MOV_DIF_DEL_DIA;
  LP_GEN_CHEQ_DEV_DIA_ANT;
end ;
/

