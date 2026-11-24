CREATE OR REPLACE TYPE IT."TYP_FIRMANTEORDTRA"                                          IS OBJECT
( nro_ord_transferencia  varchar2(50),
  nombre varchar2(2000),
  CONSTRUCTOR FUNCTION typ_firmanteordtra RETURN SELF AS result
)
/

