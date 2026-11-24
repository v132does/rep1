CREATE OR REPLACE TYPE IT."typ_ObtDatResCta"                                          force as OBJECT
(nro_referencia      VARCHAR2(33),
cta_recordID          VARCHAR2(33),
ERROR         VARCHAR2(2000),
tip_accion           VARCHAR2(1),
CONSTRUCTOR FUNCTION "typ_ObtDatResCta"  RETURN SELF AS RESULT)
/

