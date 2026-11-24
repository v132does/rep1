CREATE OR REPLACE TYPE IT."TYP_IMPUESTO"                                          IS OBJECT
(
   codigo           VARCHAR2(5),
   descripcion      VARCHAR2(100),
   numeroResolucion VARCHAR2(20),
   monto            NUMBER(18,2),
   periodo          VARCHAR2(10),
   CONSTRUCTOR FUNCTION typ_impuesto RETURN SELF AS result
)
/

