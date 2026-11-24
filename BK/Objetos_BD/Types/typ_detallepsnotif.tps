CREATE OR REPLACE TYPE IT."TYP_DETALLEPSNOTIF"                                          FORCE is object
(
   codigoPersona VARCHAR2(10),
   tipoPersona VARCHAR2(2),
   correoCuerpo VARCHAR2(32000),

      CONSTRUCTOR FUNCTION TYP_DETALLEPSNOTIF RETURN SELF AS RESULT
);
/

