CREATE OR REPLACE TYPE IT."TYP_DIASHABILES"                                          FORCE IS OBJECT
(
  fecha       varchar2(8),
  descripcion varchar2(200),
  CONSTRUCTOR FUNCTION typ_diasHabiles RETURN SELF AS RESULT
)
/

