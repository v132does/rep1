CREATE OR REPLACE TYPE IT."TYP_BANCOS"                                          force  IS OBJECT
(
   -- Indica si es un mensaje de error
   error                VARCHAR2(1),
   -- Nombre de la respuesta
   nombreRespuesta      VARCHAR2(15),
   -- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
   -- Cantidad de datos de retorno
   cantidad             NUMBER(3),
   -- Lista de datos
   listaDetalleBancos   typ_listaDetalleBancos, 
   CONSTRUCTOR FUNCTION typ_bancos RETURN SELF AS result
)
/

