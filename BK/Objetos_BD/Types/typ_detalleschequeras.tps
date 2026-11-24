CREATE OR REPLACE TYPE IT."TYP_DETALLESCHEQUERAS"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
-- Cantidad de chequeras
   cantChequeras NUMBER(3),
-- Lista detalles de chequeras
   listaDetalleChequera typ_listaDetalleChequeras,
   CONSTRUCTOR FUNCTION typ_detallesChequeras RETURN SELF AS result
)
/

