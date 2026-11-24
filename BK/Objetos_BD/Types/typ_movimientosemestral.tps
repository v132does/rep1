CREATE OR REPLACE TYPE IT."TYP_MOVIMIENTOSEMESTRAL"                                          force AS OBJECT
(
  monto                          VARCHAR2(16), -- Monto total del movimiento
  montoGs                        VARCHAR2(16), -- Monto total GS del movimiento
  nombres                        VARCHAR2(150), -- Nombres
  oficial                        VARCHAR2(60), -- Oficial
  numeroCuenta                   VARCHAR2(15), -- Numero de cuenta
  transaccion                    VARCHAR2(60), -- Concepto
  fecha                          VARCHAR2(8),  -- Fecha del movimiento
  numeroCuota                    VARCHAR2(3),  -- Numero de cuota
  codigoModulo                   VARCHAR2(3),  -- Código de módulo
  desModulo                      VARCHAR2(100),  -- Descripción del módulo
  codigoMoneda                   VARCHAR2(100),  -- Código de moneda
  codigoOficina                  VARCHAR2(100),  -- Código de oficina
  desOficina                     VARCHAR2(100),  -- Descripción de oficina
  CONSTRUCTOR FUNCTION TYP_MOVIMIENTOSEMESTRAL RETURN SELF AS RESULT
)
/

