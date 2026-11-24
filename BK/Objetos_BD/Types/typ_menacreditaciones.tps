CREATE OR REPLACE TYPE IT."TYP_MENACREDITACIONES"                                          is OBJECT
(
  code    VARCHAR2(20),  -- Codigo del mensaje de error.
  message VARCHAR2(200), -- Descripcion del mensaje de error.
  type    VARCHAR2(20),  -- Tipo de Error
  CONSTRUCTOR FUNCTION typ_menacreditaciones RETURN SELF AS RESULT
  )
/

