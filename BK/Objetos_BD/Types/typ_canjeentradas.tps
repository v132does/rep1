CREATE OR REPLACE TYPE IT."TYP_CANJEENTRADAS"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
-- Cantidad de entradas
   canEntradas     NUMBER(3),
-- Lista de entradas de cine
   listaEntradas typ_listaEntradas,

   CONSTRUCTOR FUNCTION typ_canjeentradas RETURN SELF AS RESULT
)
/

