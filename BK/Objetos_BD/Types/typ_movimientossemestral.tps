CREATE OR REPLACE TYPE IT."TYP_MOVIMIENTOSSEMESTRAL"                                          FORCE AS OBJECT
(
   error                  VARCHAR2(1),          -- Indica si es un mensaje de error
   nombreRespuesta        VARCHAR2(15),         -- Nombre de la respuesta
   descripcionRespuesta   VARCHAR2(200),        -- Mensaje de la respuesta
   oficina                VARCHAR2(100),        -- Oficina
   cantidadMovimientos    NUMBER(8),            -- Cantidad de movimientos
   listaMovSemestrales    typ_listaMovSemestrales, -- Listado de movimientos semestrales
   CONSTRUCTOR FUNCTION typ_movimientosSemestral RETURN SELF AS RESULT
)
/

