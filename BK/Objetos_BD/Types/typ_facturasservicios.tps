CREATE OR REPLACE TYPE IT."TYP_FACTURASSERVICIOS"                                          IS OBJECT
(
   --
   -- Type usado para retornar el listado de facturas de pagos de servicios (CANREQVAR-229)
   --
   error                VARCHAR2(1), -- Indica si es un mensaje de error
   nombreRespuesta      VARCHAR2(15), -- Nombre de la respuesta
   descripcionRespuesta VARCHAR2(200), -- Mensaje de la respuesta
   cantFacturas         NUMBER, --Tamano de lista de facturas
   listaFacturas        typ_listaFacturasServicios, --Lista de facturas

   CONSTRUCTOR FUNCTION typ_facturasServicios RETURN SELF AS RESULT
)
/

