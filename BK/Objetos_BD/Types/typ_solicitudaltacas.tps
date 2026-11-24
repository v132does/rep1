CREATE OR REPLACE TYPE IT."TYP_SOLICITUDALTACAS"                                          FORCE AS OBJECT
(
      error                  VARCHAR2(1),
      nombreRespuesta        VARCHAR2(100),
      descripcionRespuesta   VARCHAR2(2000),
      CONSTRUCTOR FUNCTION typ_solicitudaltacas RETURN SELF AS RESULT
)
/

