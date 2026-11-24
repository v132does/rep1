CREATE OR REPLACE TYPE IT."TYP_POSTRESPUESTACLOB"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error       VARCHAR2(1),
   codigoError NUMBER(3),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
   status_code          NUMBER(3),
   respuesta            CLOB,
   CONSTRUCTOR FUNCTION TYP_POSTRESPUESTACLOB RETURN SELF AS RESULT
)
/

