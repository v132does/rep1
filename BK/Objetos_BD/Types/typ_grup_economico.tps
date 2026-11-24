CREATE OR REPLACE TYPE IT."TYP_GRUP_ECONOMICO"                                          force IS OBJECT
(
  codGrupo             varchar(3),
  nombreGrupo          varchar(60),
  participantes        TYP_LIST_GRUP_ECON_PARTICIPANT, -- Lista de Datos de Acreditaciones
  error                VARCHAR2(1), -- Indica si la respuesta es de error o no
  nombreRespuesta      VARCHAR2(15), -- Codigo de respuesta
  descripcionRespuesta VARCHAR2(200), -- Descripcion del codigo de respuesta
  CONSTRUCTOR FUNCTION TYP_GRUP_ECONOMICO RETURN SELF AS result
)
/

