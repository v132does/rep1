CREATE OR REPLACE TYPE IT."TYP_MENSAJERIA"                                          FORCE AS OBJECT
(
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(15),
      descripcionRespuesta  VARCHAR2(200),
      respuesta             VARCHAR2(10),
      CONSTRUCTOR FUNCTION typ_mensajeria RETURN SELF AS RESULT
)
/

