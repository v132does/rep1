CREATE OR REPLACE TYPE IT."TYP_TERMINOSYCONDICIONES"                                          FORCE IS OBJECT
(
   error VARCHAR2(1),
   nombreRespuesta      VARCHAR2(15),
   descripcionRespuesta VARCHAR2(200),
   codPersona           VARCHAR2(10),
   codEmpresa           VARCHAR2(10),
   aplicacion           VARCHAR2(30),
   version              VARCHAR2(10),
   aceptado             VARCHAR2(1),
   terminos             CLOB,

   CONSTRUCTOR FUNCTION TYP_TERMINOSYCONDICIONES RETURN SELF AS RESULT
)
/

