CREATE OR REPLACE TYPE IT."TYP_CUOTAPRESTAMO"                                          FORCE IS OBJECT
   (
      nroCuota          NUMBER(5),
      montoCuota        NUMBER(18,2),
      fechaVencimiento  DATE,
      mtoCapital        NUMBER(18,2),
      mtoInteres        NUMBER(18,2),
      estado            VARCHAR2(50),
      salCapital        NUMBER(18,2),
      salInteres        NUMBER(18,2),
      fecUltPago        DATE,
      valRecargo        NUMBER(18,2),
      salCuota          NUMBER(18,2),
      monCuoPagado      NUMBER(18,2),
      diasMora          NUMBER(5),
      mtoAPagar         NUMBER(18,2),
      mtoSeguro         NUMBER(18,2),
      nroCheque         VARCHAR2(20),
      bancoCheque       VARCHAR2(100),
      librador          VARCHAR2(150),
      estCheque         VARCHAR2(100),
      causaRechazo      VARCHAR2(1000),
      mtoCheque         NUMBER(18,2),
      fecVencCheque     DATE,

      CONSTRUCTOR FUNCTION typ_cuotaprestamo RETURN SELF AS RESULT
   )
/

