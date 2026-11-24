CREATE OR REPLACE TYPE IT."TYP_DATOSGEOGRAFICOS"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
-- Cantidad de datos de retorno
   cantDatos NUMBER(3),
-- Lista de datos
   listaDatosGeograficos typ_listaDatosGeograficos,
   CONSTRUCTOR FUNCTION typ_datosGeograficos RETURN SELF AS result
)
/

