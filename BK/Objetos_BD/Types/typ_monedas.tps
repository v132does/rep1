CREATE OR REPLACE TYPE IT."TYP_MONEDAS"                                          IS OBJECT
(
   -- Indica si es un mensaje de error
   error                VARCHAR2(1),
   -- Nombre de la respuesta
   nombreRespuesta      VARCHAR2(15),
   -- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
   -- Cantidad de datos de retorno
   cantidad             NUMBER(3),
   -- Lista de monedas
   listaMonedas   typ_listaMonedas,
   CONSTRUCTOR FUNCTION typ_monedas RETURN SELF AS result
)
/

