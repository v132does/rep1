CREATE OR REPLACE TYPE IT."TYP_DEVOLUCIONSPI"                                          FORCE AS OBJECT
(
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(100),
      descripcionRespuesta  VARCHAR2(2000),
      numeroReferencia      NUMBER(30),
      CONSTRUCTOR FUNCTION typ_devolucionSpi RETURN SELF AS RESULT
)
/

