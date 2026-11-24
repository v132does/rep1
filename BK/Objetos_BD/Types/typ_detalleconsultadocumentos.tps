CREATE OR REPLACE TYPE IT."TYP_DETALLECONSULTADOCUMENTOS"                                          force                                        IS OBJECT
(
   codigoTipoDocumento      NUMBER(3),
   abreviaturaTipoDocumento VARCHAR2(200),
   CONSTRUCTOR FUNCTION typ_detalleconsultadocumentos RETURN SELF AS result
)
/

