CREATE OR REPLACE TYPE IT."TYP_REGCELTOKEN"                                          IS OBJECT
(
   error                 VARCHAR2(1),
   nombreRespuesta       VARCHAR2(15),
   descripcionRespuesta  VARCHAR2(200),
   numero                VARCHAR2(20),
   resLimite             VARCHAR2(2),
   cantAutorizadores     NUMBER(3),
   nroDocumento          NUMBER(15),
   CONSTRUCTOR FUNCTION TYP_REGCELTOKEN RETURN SELF AS RESULT
)
/

