CREATE OR REPLACE TYPE IT."TYP_MODALSOLICITUD"                                          FORCE IS OBJECT
(
-- Indica si es un mensaje de error
  error VARCHAR2(1),
-- Código de la respuesta
  nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
--Código de Modalidad
  codigoModalidad VARCHAR2(4),
--Descripción Modalidad
  descripcion VARCHAR2(60),
  CONSTRUCTOR FUNCTION typ_modalSolicitud RETURN SELF AS result
)
/

