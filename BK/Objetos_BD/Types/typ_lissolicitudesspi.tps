CREATE OR REPLACE TYPE IT."TYP_LISSOLICITUDESSPI"                                          is OBJECT
(
  error                VARCHAR2(1),  -- Indica si es un mensaje de error
  nombreRespuesta      VARCHAR2(15), -- Nombre de la respuesta
  descripcionRespuesta VARCHAR2(200),-- Mensaje de la respuesta
  cantRegistros          number,     --Cantidad de registros
  listaDetalles        typ_ListaSolicitudesSpi,-- Detalle de valores
  CONSTRUCTOR FUNCTION typ_lissolicitudesspi RETURN SELF AS RESULT
)
/

