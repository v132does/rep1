CREATE OR REPLACE TYPE IT."TYP_TRANSFERENCIA_HB"                                          IS OBJECT
   (
      error                  VARCHAR2(1),
      nombreRespuesta        VARCHAR2(15),
      descripcionRespuesta   VARCHAR2(200),
      tipTransferencia       VARCHAR2(1),
      tipPedido              VARCHAR2(1),
      cotizacion             NUMBER(18,2),
      ctaForDebito           VARCHAR2(17),
      nombreCtaDebito        VARCHAR2(100),
      codMonDebito           VARCHAR2(3),
      monto                  NUMBER(18,2),
      ctaForCredito          VARCHAR2(17),
      nombreCtaCredito       VARCHAR2(100),
      codMonCredito          VARCHAR2(3),
      montoCredito           NUMBER(18,2),
      resLimite              VARCHAR2(2),
      nroContrato            NUMBER(10),
      tipOperacion           VARCHAR2(1),
      cantAutorizadores      NUMBER(3),
      nroDocumento           NUMBER(15),
      denominacionCtaDebito  VARCHAR2(50),
      denominacionCtaCredito VARCHAR2(50),
      montoCargo             NUMBER(18,2),
      cotizacionContra       NUMBER(18,2),
      fechaOperacion         DATE,
      fechaValor             DATE,
      cotizacionCredito      NUMBER(18,2),
      CONSTRUCTOR FUNCTION TYP_TRANSFERENCIA_HB RETURN SELF AS RESULT
   )
/

