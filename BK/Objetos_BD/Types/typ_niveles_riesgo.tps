CREATE OR REPLACE TYPE IT."TYP_NIVELES_RIESGO"                                          IS OBJECT
(
  codPersona             varchar(10), -- cod de persona fisica/juridica
  riesgoEntidad          number(2), -- nivel de riesgo en BBVA
  riesgoSistema          number(2), -- nivel de riesgo en el BCP
  error                VARCHAR2(1), -- Indica si la respuesta es de error o no
  nombreRespuesta      VARCHAR2(15), -- Codigo de respuesta
  descripcionRespuesta VARCHAR2(200), -- Descripcion del codigo de respuesta
  
  CONSTRUCTOR FUNCTION TYP_NIVELES_RIESGO RETURN SELF AS result
)
/

