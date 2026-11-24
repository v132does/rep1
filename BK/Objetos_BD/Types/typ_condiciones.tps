CREATE OR REPLACE TYPE IT."TYP_CONDICIONES"                                          FORCE                                        IS OBJECT
(
   etiqueta VARCHAR2(30),
   valor    VARCHAR2(2000),
   CONSTRUCTOR FUNCTION typ_condiciones RETURN SELF AS result
)
/

