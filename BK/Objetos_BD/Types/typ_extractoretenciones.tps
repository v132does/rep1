CREATE OR REPLACE TYPE IT."TYP_EXTRACTORETENCIONES"                                          IS OBJECT
(
   nroDocumento    NUMBER(15),
   descripcion     VARCHAR2(35),
   fechaMovimiento DATE,
   fechaLiberacion DATE,
   monto           NUMBER(18, 2),
   CONSTRUCTOR FUNCTION typ_extractoRetenciones RETURN SELF AS result
)
/

