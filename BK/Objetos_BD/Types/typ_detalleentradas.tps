CREATE OR REPLACE TYPE IT."TYP_DETALLEENTRADAS"                                          force is OBJECT
(
-- Codigo de entrada de cine usada en el canje de puntos
  cod_entrada           VARCHAR2(100),
  CONSTRUCTOR FUNCTION typ_detalleentradas RETURN SELF AS RESULT
)
/

