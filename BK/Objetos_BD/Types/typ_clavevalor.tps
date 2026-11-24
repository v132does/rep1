CREATE OR REPLACE TYPE IT."TYP_CLAVEVALOR"                                          FORCE as object
(
      clave                VARCHAR2(50),
      valor                VARCHAR2(300),
      tipo                 VARCHAR2(100),
  CONSTRUCTOR FUNCTION typ_clavevalor RETURN SELF AS RESULT
)
/

