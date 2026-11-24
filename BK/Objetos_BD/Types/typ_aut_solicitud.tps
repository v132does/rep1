CREATE OR REPLACE TYPE IT."TYP_AUT_SOLICITUD"                                          FORCE AS OBJECT
(
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(100),
      descripcionRespuesta  VARCHAR2(2000),
      numeroReferencia      NUMBER(30),
      CONSTRUCTOR FUNCTION typ_aut_solicitud RETURN SELF AS RESULT
)
/

