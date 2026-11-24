CREATE OR REPLACE TYPE IT."TYP_CONTACTOCLIENTE"                                          FORCE IS OBJECT
(
  -- codigo de persona
  cod_persona VARCHAR2(10),
  -- codigo de persona vinculada
  cod_per_vinculada VARCHAR2(10),
  -- tipo de contacto
  tipo VARCHAR2(25),
  -- valor del contacto
  contacto VARCHAR2(100),
  -- es contacto principal
  principal VARCHAR2(1),

  CONSTRUCTOR FUNCTION typ_contactocliente RETURN SELF AS RESULT
)
/

