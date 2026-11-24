CREATE OR REPLACE TYPE IT."TYP_MENSAJERESPUESTA"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
   CONSTRUCTOR FUNCTION typ_mensajerespuesta RETURN SELF AS result
)
/

