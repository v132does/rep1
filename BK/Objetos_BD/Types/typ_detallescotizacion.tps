CREATE OR REPLACE TYPE IT."TYP_DETALLESCOTIZACION"                                          as OBJECT
(
-- Indica si es un mensaje de error
  error varchar2(1),
-- Nombre de la respuesta
  nombreRespuesta varchar2(15),
-- Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
--Cantidad de detalles resueltos
  cantDetalles number(3),
-- Detalles de la cotizaciones
  listaDetalleCotizacion typ_listaDetallesCotizacion,
  CONSTRUCTOR FUNCTION typ_detallescotizacion RETURN SELF AS RESULT
)
/

