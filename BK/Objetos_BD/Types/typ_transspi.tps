CREATE OR REPLACE TYPE IT."TYP_TRANSSPI"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
  cantRegistros          number,
-- Detalle de valores
  listaDetalles        typ_listatransSpi,
  CONSTRUCTOR FUNCTION typ_transSpi RETURN SELF AS RESULT
)
/

