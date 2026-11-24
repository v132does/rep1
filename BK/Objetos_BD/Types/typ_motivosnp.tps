CREATE OR REPLACE TYPE IT."TYP_MOTIVOSNP"                                          FORCE IS OBJECT
(
-- Código del Motivo
  codigoMotivo varchar2(5),
-- Descripción del Motivo
  motivo varchar2(100),

  CONSTRUCTOR FUNCTION typ_motivoSnp RETURN SELF AS RESULT
)
/

