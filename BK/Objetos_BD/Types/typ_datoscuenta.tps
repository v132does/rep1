CREATE OR REPLACE TYPE IT.TYP_DATOSCUENTA IS OBJECT
(
   error                   VARCHAR2(15),--SIN ERROR
   descripcionRespuesta    VARCHAR2(200),--OK
   saldoAnterior           NUMBER(18, 2),
   saldoActual             NUMBER(18, 2),
   nroCuenta               VARCHAR2(15),
   detallesMovimiento      typ_listaMovimientosCuenta,
   detallesTransferencia   typ_listatransferenciasCuenta,
 CONSTRUCTOR FUNCTION typ_datosCuenta RETURN SELF AS result
)
/
