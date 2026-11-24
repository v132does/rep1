CREATE OR REPLACE TYPE IT."TYP_TRANSFERENCIA"                                          FORCE AS OBJECT
(
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(15),
      descripcionRespuesta  VARCHAR2(200),
      tipoTransferencia     VARCHAR2(1),
      tipoPedido            VARCHAR2(1),
      cotizacion            NUMBER(18,2),
      cuentaDebito          VARCHAR2(17),
      nombreCtaDebito       VARCHAR2(100),
      monedaDebito          VARCHAR2(3),
      monto                 NUMBER(18,2),
      cuentaCredito         VARCHAR2(17),
      nombreCtaCredito      VARCHAR2(100),
      monedaCredito         VARCHAR2(3),
      montoCredito          NUMBER(18,2),
      numeroContrato        NUMBER(10),
      cantidadAutorizadores NUMBER(3),
      numeroDocumento       NUMBER(15),
      CONSTRUCTOR FUNCTION typ_transferencia RETURN SELF AS RESULT
)
/

