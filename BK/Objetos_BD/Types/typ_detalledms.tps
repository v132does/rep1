CREATE OR REPLACE TYPE IT."TYP_DETALLEDMS"                                          IS OBJECT
(
   identificador NUMBER,
   fechaCierre   VARCHAR2(10),
   CONSTRUCTOR FUNCTION typ_detalleDms RETURN SELF AS result
)
/

