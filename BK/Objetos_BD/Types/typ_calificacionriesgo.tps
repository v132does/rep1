CREATE OR REPLACE TYPE IT."TYP_CALIFICACIONRIESGO"                                          is OBJECT
( --Indica si es un mensaje de error
  error varchar2(1),
--Nombre de la respuesta
  nombreRespuesta varchar2(15),
--Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
--Calificacion de riesgo
  calificacionRiesgo varchar2(3),
-- Descripcion de la calificacion de risgo
  descripcionCalificacion varchar2(40),
-- Fecha de Calificacion
  fecha date,

  CONSTRUCTOR FUNCTION typ_calificacionriesgo RETURN SELF AS RESULT
)
/

