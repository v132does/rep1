CREATE OR REPLACE TYPE IT."TYP_MENSAJESOFTOKEN"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
-- Respuesta de la insercion
   respuesta VARCHAR(15),

   CONSTRUCTOR FUNCTION TYP_MENSAJESOFTOKEN RETURN SELF AS result
)
/

