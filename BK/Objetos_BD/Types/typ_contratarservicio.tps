CREATE OR REPLACE TYPE IT."TYP_CONTRATARSERVICIO"                                          FORCE AS OBJECT
(
      error                  VARCHAR2(1),
      nombreRespuesta        VARCHAR2(100),
      descripcionRespuesta   VARCHAR2(2000),
      CONSTRUCTOR FUNCTION typ_contratarservicio RETURN SELF AS RESULT
)
--https://itti-digital.atlassian.net/browse/NVB-3811
/

