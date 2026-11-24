CREATE OR REPLACE TYPE IT."TYP_EXTRACTOMOVIMIENTOS"                                          FORCE IS OBJECT
(
   nroComprobante     VARCHAR2(15),
   descripcionOficina VARCHAR2(35),
   concepto           VARCHAR2(100),
   fechaTransaccion   DATE,
   fechaConfirmacion  DATE,
   montoDebito        NUMBER(18, 2),
   montoCredito       NUMBER(18, 2),
   saldo              NUMBER(18, 2),
   transaccionPadre   NUMBER(4),
   moduloPadre        NUMBER(3),
   modalidadPadre     NUMBER(3),
   CONSTRUCTOR FUNCTION typ_extractoMovimientos RETURN SELF AS result
)
/

