CREATE OR REPLACE TYPE IT."TYP_TIPOSCHEQUERAS"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
-- Lista de tipos de chequeras  
   tiposChequeras typ_listaTiposChequeras,
   CONSTRUCTOR FUNCTION typ_tiposChequeras RETURN SELF AS result
)
/

