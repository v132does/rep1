CREATE OR REPLACE TYPE IT."TYP_RETORNODEPOSITOS"                                          is OBJECT
(
-- Número de Boleta o Referencia
  nroReferencia      NUMBER(16),
-- Moneda del Depósito
  monIso             VARCHAR2(3),
-- Número de Cuenta
  numCuenta          VARCHAR2(20),
-- Importe de Depósito
  monto              NUMBER(18,2),  
-- Estado del Depósito
  estado             NUMBER(3),
-- Mensaje Respuesta
  mensaje            VARCHAR2(200),  
  CONSTRUCTOR FUNCTION TYP_RETORNODEPOSITOS RETURN SELF AS RESULT
)
/

