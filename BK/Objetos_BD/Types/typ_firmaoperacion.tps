CREATE OR REPLACE TYPE IT."TYP_FIRMAOPERACION"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                   VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta         VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta    VARCHAR2(200),
-- Detalle de la autorizacion  
  detalle                 typ_detallePendiente,
  CONSTRUCTOR FUNCTION typ_firmaOperacion RETURN SELF AS RESULT
)
/

