CREATE OR REPLACE TYPE IT."TYP_CHEQUESDEVUELTOS"                                          IS OBJECT
(
--Indica si es un mensaje de error
   error VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
-- Cantidad de cheques devueltos retornados
   cantChequesDevueltos NUMBER(3),
-- Lista de cheques devueltos
   listaChequesDevueltos typ_listaChequesDevueltos,
   CONSTRUCTOR FUNCTION typ_chequesDevueltos RETURN SELF AS result
)
/

