CREATE OR REPLACE TYPE IT."TYP_INFORMACIONOFICINAS"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
-- Cantidad de Oficinas  
   cantOficinas NUMBER(3),
-- Lista de Oficinas
   informacionOficinas typ_listaOficinas,
   CONSTRUCTOR FUNCTION typ_informacionOficinas RETURN SELF AS result
)
/

