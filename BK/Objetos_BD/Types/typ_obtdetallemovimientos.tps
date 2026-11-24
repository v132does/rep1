CREATE OR REPLACE TYPE IT."TYP_OBTDETALLEMOVIMIENTOS"                                          FORCE AS OBJECT
(
   error                  VARCHAR2(1),          -- Indica si es un mensaje de error
   nombreRespuesta        VARCHAR2(15),         -- Nombre de la respuesta
   descripcionRespuesta   VARCHAR2(200),        -- Mensaje de la respuesta
   cantidadMovimientos    NUMBER(8),            -- Cantidad de movimientos
   listaMovimientos       typ_obtlistamovimientos,
   CONSTRUCTOR FUNCTION typ_obtdetallemovimientos RETURN SELF AS RESULT
)
/

