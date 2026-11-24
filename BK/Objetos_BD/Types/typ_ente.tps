CREATE OR REPLACE TYPE IT."TYP_ENTE"                                          FORCE AS OBJECT
(
   error                        VARCHAR2(1),             -- Indica si es un mensaje de error
   nombreRespuesta              VARCHAR2(15),            -- Nombre de la respuesta
   descripcionRespuesta         VARCHAR2(200),           -- Mensaje de la respuesta
   cantidadDetalles             NUMBER(3),               -- Cantidad de detalles resueltos
   listaEnteProveedor           typ_listaEnteProveedor,  -- Detalles del ente para Pago a Proveedores
   listaEnteSueldo              typ_listaEnteSueldo,     -- Detalles del ente para Pago de Salarios
   CONSTRUCTOR FUNCTION TYP_ENTE RETURN SELF AS RESULT
)
/

