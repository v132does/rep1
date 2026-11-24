CREATE OR REPLACE TYPE IT."TYP_SEGUROS"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
-- size de polizas
  contPolizas        NUMBER(2),
-- detalles polizas
  listaPolizas       TYP_LISTASEGUROSPOLIZAS,

  CONSTRUCTOR FUNCTION TYP_SEGUROS RETURN SELF AS RESULT
)
/

