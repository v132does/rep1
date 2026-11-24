CREATE OR REPLACE TYPE IT."TYP_DETALLERECAUDACION"                                          force                                          is OBJECT
(
-- Cuenta a debitar
  numeroCuentaDebito  VARCHAR2(15),
-- Titular de la cuenta
  denominacion        VARCHAR2(100),
-- Descripcion Cuenta
  descripcionCuenta   VARCHAR2(35),
-- Monto del debito
  monto               NUMBER(18,2),
-- Codigo Estado de la transaccion
  estado              VARCHAR2(1),
-- Definicion del estado de la transaccion
  descripcionEstado   VARCHAR2(100),
-- Numero de factura asociada
  numeroFactura       VARCHAR2(60),
-- Tipo de Recaudacion
  tipoCobranza        VARCHAR2(3),
-- Descripcion del tipo de recaudacion
  descripcionCobranza VARCHAR2(100),
-- Numero de comprobante del pago
  numeroDocumento     NUMBER(15),
-- Si hubo error, 0-Exito
  codigoRespuesta     NUMBER,
-- Mensaje de verificacion del debito
  mensajeRespuesta    VARCHAR2(400),
-- Fecha de la operacion
  fechaOperacion      DATE,
-- Cuenta credito
  numeroCuentaCredito VARCHAR2(15),
-- Codigo Moneda
  codigoMoneda        VARCHAR2(3),
  CONSTRUCTOR FUNCTION typ_detallerecaudacion RETURN SELF AS RESULT
)
/

