CREATE OR REPLACE TYPE IT."TYP_RECHAZOOPERACION"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
--cantidad 
  cantidad     NUMBER,
--Lista de cuentas
  listaDetalles        typ_listaRechazoOperacion,
  CONSTRUCTOR FUNCTION typ_rechazoOperacion RETURN SELF AS RESULT
)
/

