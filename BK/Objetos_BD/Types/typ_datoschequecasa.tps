CREATE OR REPLACE TYPE IT."TYP_DATOSCHEQUECASA"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
--Tamaño de lista de direcciones
  cantidad             NUMBER,
--Lista de datos
  listaDatos     typ_listaDatoChequeCasa,
  CONSTRUCTOR FUNCTION typ_datosChequeCasa RETURN SELF AS RESULT
)
/

