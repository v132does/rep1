CREATE OR REPLACE TYPE IT."TYP_LISSOLPAGOSSPI"                                          is OBJECT
(
  error                VARCHAR2(1),  -- Indica si es un mensaje de error
  nombreRespuesta      VARCHAR2(15), -- Nombre de la respuesta
  descripcionRespuesta VARCHAR2(200),-- Mensaje de la respuesta
  cantRegistros          number,     --Cantidad de registros
  listaDetalles        typ_ListaSolPagosSpi,-- Detalle de valores
  CONSTRUCTOR FUNCTION typ_lissolpagosspi RETURN SELF AS RESULT
)
/

