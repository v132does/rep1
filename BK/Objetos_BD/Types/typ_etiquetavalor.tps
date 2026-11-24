CREATE OR REPLACE TYPE IT."TYP_ETIQUETAVALOR"                                          FORCE is OBJECT
(
-- Nombre Etiqueta
  etiqueta VARCHAR2(120),
-- Valor etiqueta
  valor    VARCHAR2(2000),
  CONSTRUCTOR FUNCTION typ_etiquetavalor RETURN SELF AS RESULT
)
/

