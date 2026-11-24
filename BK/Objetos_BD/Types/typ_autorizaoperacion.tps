CREATE OR REPLACE TYPE IT."TYP_AUTORIZAOPERACION"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                   VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta         VARCHAR2(25),
-- Mensaje de la respuesta
  descripcionRespuesta    VARCHAR2(200),
-- Respuesta de limite de operaciones
  respuestaLimite         VARCHAR2(2),
-- Numero de operacion confirmada
  numeroDocumento         NUMBER(15),
-- Fecha de creacion
  fechaInsercion          DATE,
-- Detalle de las autorizaciones
  detalles                typ_detalleAutorizacion,
  CONSTRUCTOR FUNCTION typ_autorizaOperacion RETURN SELF AS RESULT
)
/

