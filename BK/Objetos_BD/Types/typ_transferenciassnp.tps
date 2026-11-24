CREATE OR REPLACE TYPE IT."TYP_TRANSFERENCIASSNP"                                          FORCE IS OBJECT
(
-- Indica si es un mensaje de error
  error VARCHAR2(1),
-- Código de la respuesta
  nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
-- fecha de la Operación
  fechaOperacion VARCHAR2(8),
-- Núemro de Cuenta de Débito
  cuentaDebito VARCHAR2(17),
-- nombreCtaDebito
  nombreCtaDebito VARCHAR2(100),
-- Código de Moneda de Débito
  monedaDebito VARCHAR2(3),
-- Monto del Debito
  montoDebito NUMBER(18, 2),
-- Número de Cuenta de Crédito
  cuentaCredito VARCHAR2(20),
-- Nombre del Beneficiario
  beneficiario VARCHAR2(100),
-- Codigo Swift
  codigoSwift VARCHAR2(20),
-- Denominación del Participante
  participante VARCHAR2(60),
-- Moneda de Crédito
  monedaCredito VARCHAR2(3),
-- Monto del Crédito
  montoCredito NUMBER(18, 2),
-- Cotización de la operación
  cotizacion number(16, 2),
-- Fecha sugerida
  fechaSugerida VARCHAR2(8),
  nro_referencia VARCHAR(15),

  CONSTRUCTOR FUNCTION typ_transferenciasSnp RETURN SELF AS result
)
/

