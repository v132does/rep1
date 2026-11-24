CREATE OR REPLACE TYPE IT."TYP_DETALLECONSULTAENTES"                                          FORCE                                        IS OBJECT
(
   codigoSwiftEntidadFinanciera VARCHAR2(20),
   nombreEntidad                VARCHAR2(60),
   codigoEntidad                NUMBER(5),
   CONSTRUCTOR FUNCTION typ_detalleconsultaentes RETURN SELF AS result
)
/

