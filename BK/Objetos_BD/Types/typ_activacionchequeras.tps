CREATE OR REPLACE TYPE IT."TYP_ACTIVACIONCHEQUERAS"                                          is OBJECT
(
 -- Indica si es un mensaje de error
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
-- cantidad de firmar para confirmar
  firmasRequeridas     NUMBER(4),
-- moneda de la cuenta
  codigoMoneda         VARCHAR2(3),
  CONSTRUCTOR FUNCTION typ_activacionChequeras RETURN SELF AS RESULT
)
/

