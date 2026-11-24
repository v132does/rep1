CREATE OR REPLACE TYPE IT."TYP_DETALLERECHAZOOPERACION"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                   VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta         VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta    VARCHAR2(200),
-- Numero de operacion confirmada
  numeroDocumento         NUMBER(15),
-- Fecha de creacion
  codOperacion          VARCHAR2(3),
  CONSTRUCTOR FUNCTION typ_detalleRechazoOperacion RETURN SELF AS RESULT
)
/

