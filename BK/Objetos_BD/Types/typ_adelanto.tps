CREATE OR REPLACE TYPE IT."TYP_ADELANTO"                                          IS OBJECT
   (
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(15),
      descripcionRespuesta  VARCHAR2(200),
      tarfecvencimiento     DATE,           
      resLimite             VARCHAR2(2),
      mtoComAplicada        NUMBER(18,2),
      nroOperacion          NUMBER(10),
      CONSTRUCTOR FUNCTION typ_adelanto RETURN SELF AS RESULT
   )
/

