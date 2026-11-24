CREATE OR REPLACE TYPE IT."TYP_INHABILITACION"                                          IS OBJECT
(
   codigoresultado      VARCHAR2(3),
   descripcionresultado VARCHAR2(100),
   tipo                 VARCHAR2(10),
   nrocircular          VARCHAR2(4),
   fechacircular        VARCHAR2(8),
   codentidad           VARCHAR2(4),
   desentidad           VARCHAR2(60),
   causal               VARCHAR2(15),
   observacion          VARCHAR2(40),
   codtipodocumento     VARCHAR2(3),
   numerodocumento      VARCHAR2(15),
   fechainhabilitacion  VARCHAR2(8),
   fechafin             VARCHAR2(8),
   inhabcircularnro     VARCHAR2(4),
   nombres              VARCHAR2(255),
   apellidos            VARCHAR2(60),

   CONSTRUCTOR FUNCTION typ_inhabilitacion RETURN SELF AS result
)
/

