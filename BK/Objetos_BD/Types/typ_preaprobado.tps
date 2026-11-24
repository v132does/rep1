CREATE OR REPLACE TYPE IT."TYP_PREAPROBADO"                                          force is OBJECT
(
-- Indica si es un mensaje de error
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
-- Moneda de la Operacion
  codigoMoneda         VARCHAR2(3),
-- Monto minimo de la operacion
  montoMinimo          NUMBER(18,2),
-- Monto preaprobado
  monto                NUMBER(18,2),
-- Modulo del producto
  codigoModulo         NUMBER(3),
-- Detalle de valores
  listaDetalles        typ_listaEtiquetaValor,
--Clave a solicitar al usuario ('00':L, '10': T, '01': K, '11': T + K
  resLimite            VARCHAR2(2),
-- Numero de comprobante
  numeroDocumento      NUMBER(15),
  CONSTRUCTOR FUNCTION typ_preaprobado RETURN SELF AS RESULT
)
/

