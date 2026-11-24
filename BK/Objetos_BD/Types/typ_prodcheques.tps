CREATE OR REPLACE TYPE IT."TYP_PRODCHEQUES"                                          is OBJECT
(
-- Número de cheque
  nroCheque          VARCHAR2(20),
-- Número de Cuenta
  nroCuenta          VARCHAR2(20),
-- Moneda ISO
  codMonIso          VARCHAR2(3),
-- Importe del Cheque
  monto              VARCHAR2(20),
-- Código del Error
  motivo             VARCHAR2(3),
-- Nombre de operador
  usuario            VARCHAR2(20),
-- Banda CMC7
  banda              VARCHAR2(30),
-- Identif. cheque en PRODEP
  chequeId           VARCHAR2(10),
-- Identif. retención cheque
  ciclo              VARCHAR2(1),
  CONSTRUCTOR FUNCTION TYP_PRODCHEQUES RETURN SELF AS RESULT
)
/

