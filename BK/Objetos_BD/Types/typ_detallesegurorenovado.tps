CREATE OR REPLACE TYPE IT."TYP_DETALLESEGURORENOVADO"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
-- Moneda de la Operacion
  codigoMoneda         VARCHAR2(3),
-- Cuenta
  nroCuenta            VARCHAR2(17),         
-- Monto capital
  monto                NUMBER(18,2),
-- Monto cuota
  montoCuota           NUMBER(18,2),
-- Tipo de seguro vida, ap, hogar
  tipoSeguro           NUMBER,
-- Detalle de valores
  listaDetalles        typ_listaEtiquetaValor,
-- Numero de comprobante
  numeroDocumento      NUMBER,
  CONSTRUCTOR FUNCTION typ_detallesegurorenovado RETURN SELF AS RESULT
)
/

