CREATE OR REPLACE TYPE IT."TYP_SNPPERIODOS"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
   cantidadPeriodos     NUMBER(3),
   lista                typ_ListaSnpPeriodos,
   CONSTRUCTOR FUNCTION typ_SnpPeriodos RETURN SELF AS RESULT
)
/

