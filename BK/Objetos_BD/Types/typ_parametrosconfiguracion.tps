CREATE OR REPLACE TYPE IT."TYP_PARAMETROSCONFIGURACION"                                          IS OBJECT
(
-- Indica si es un mensaje de error
  error varchar2(1),
-- Nombre de la respuesta
  nombreRespuesta varchar2(15),
-- Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
  valor varchar2(2000),
  CONSTRUCTOR FUNCTION typ_parametrosConfiguracion RETURN SELF AS RESULT
)
/

