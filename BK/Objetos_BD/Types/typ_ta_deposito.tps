CREATE OR REPLACE TYPE IT."TYP_TA_DEPOSITO"                                          FORCE AS OBJECT
(
   error                VARCHAR2(1), -- Indica si es un mensaje de error
   nombreRespuesta      VARCHAR2(15), -- Nombre de la respuesta
   descripcionRespuesta VARCHAR2(200), -- Mensaje de la respuesta
   codigoMoneda         VARCHAR2(3), --Código de Moneda
   denominacion         VARCHAR2(100),
   numeroCuenta         VARCHAR2(18), --Nro de cuenta
   montoefectivo        NUMBER(18, 2), --Monto efectivo
   montoOperacion       NUMBER(18, 2), --Monto Operación
   chequeBanco          NUMBER(18, 2), --Monto cheque Banco
   chequeOtroBanco      NUMBER(18, 2), --Monto cheque otro Banco
   numeroDocumento      NUMBER(15), --Número de Documento
   fechaMovimiento      VARCHAR2(15), --Fecha de Movimiento
   CONSTRUCTOR FUNCTION typ_ta_deposito RETURN SELF AS result
)
/

