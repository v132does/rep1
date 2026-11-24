CREATE OR REPLACE TYPE IT."TYP_AUTORIZACIONESDELDIA"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
--Tamaño de lista de cuentas
  cantidadDetalles     NUMBER,
--Lista de cuentas
  listaDetalles        typ_listaDetallePendiente,
  CONSTRUCTOR FUNCTION typ_autorizacionesdeldia RETURN SELF AS RESULT
)
/

