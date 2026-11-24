CREATE OR REPLACE TYPE IT."TYP_REGCLAVE"                                          IS OBJECT
   (
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(15),
      descripcionRespuesta  VARCHAR2(200),
      clave                 VARCHAR2(100),
      idDispositivo         VARCHAR2(150),
      CONSTRUCTOR FUNCTION TYP_REGCLAVE RETURN SELF AS RESULT
   )
/

