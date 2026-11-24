CREATE OR REPLACE TYPE IT."TYP_PERMISOTIGO" IS OBJECT
(
  error                    VARCHAR(1),
  nombreRespuesta          VARCHAR2(15),
  descripcionRespuesta     VARCHAR2(200),
  autoriza                 VARCHAR(5),
  registra                 VARCHAR(5),
  consulta                 VARCHAR(5),
  autorizacionesRequeridas NUMBER,
  CONSTRUCTOR FUNCTION TYP_PERMISOTIGO RETURN SELF AS RESULT
)
/
