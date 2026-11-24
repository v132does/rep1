CREATE OR REPLACE TYPE IT."TYP_RESGLOBALHUBPRV"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
   numeroArchivo number,
   codigoEnte number,
   codigoMoneda varchar2(3),
   CONSTRUCTOR FUNCTION TYP_RESGLOBALHUBPRV RETURN SELF AS result
)
/

