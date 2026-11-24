CREATE OR REPLACE TYPE IT."TYP_EXTRACTOBLOQUEOS"                                          IS OBJECT
(
   nroCuenta    VARCHAR2(20),
   causaBloqueo VARCHAR2(35),
   fechaInicio  DATE,
   fechaFin     DATE,
   monto        NUMBER(18, 2),
   codigoMoneda VARCHAR2(3),
   CONSTRUCTOR FUNCTION typ_extractoBloqueos RETURN SELF AS result
)
/

