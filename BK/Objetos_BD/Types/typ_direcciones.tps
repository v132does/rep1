CREATE OR REPLACE TYPE IT."TYP_DIRECCIONES"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
--Tamaño de lista de direcciones
  cantidad             NUMBER,
--Lista de direcciones
  listaDirecciones     typ_listaDirecciones,
  CONSTRUCTOR FUNCTION typ_direcciones RETURN SELF AS RESULT
)
/

